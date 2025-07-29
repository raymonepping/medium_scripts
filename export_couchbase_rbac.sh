#!/usr/bin/env bash
set -euo pipefail

START_TS=$(date +%s)

VERSION="1.2.0"

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS] [<path_to_env>]

Automate Couchbase RBAC export and HashiCorp Vault role sync.

Options:
  --export                Export Couchbase users/roles to couchbase_rbac.json (default)
  --apply                 Apply Vault 'readonly' and 'readwrite' roles based on the exported JSON
  --readonly-id ID        Use this user ID for the Vault 'readonly' role (auto-detected by default)
  --readwrite-id ID       Use this user ID for the Vault 'readwrite' role (auto-detected by default)
  --dry-run               Print Vault write commands but DO NOT apply them (safe preview)
  --version               Show script version and exit
  -h, --help              Show this help message and exit

Examples:
  $0 --export
  $0 --apply --readonly-id user1 --readwrite-id user2
  $0 --export --apply --dry-run
  $0 ./custom/path/to/.env

Environment:
  Loads Couchbase connection variables from .env. Will not override your current shell's VAULT_ADDR or VAULT_TOKEN.

EOF
  exit 0
}

# Defaults
DO_EXPORT=false
DO_APPLY=false
DO_DRYRUN=false
ENV_FILE=""
READ_ID=""
WRITE_ID=""
DO_QUIET=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export)         DO_EXPORT=true; shift ;;
    --apply)          DO_APPLY=true; shift ;;
    --dry-run)        DO_DRYRUN=true; shift ;;
    --quiet|--silent) DO_QUIET=true; shift ;;
    --readonly-id)    READ_ID="$2"; shift 2 ;;
    --readwrite-id)   WRITE_ID="$2"; shift 2 ;;
    --version)        echo "$0 version $VERSION"; exit 0 ;;
    -h|--help)        show_help ;;
    *)                ENV_FILE="$1"; shift ;;
  esac
done

info()  { $DO_QUIET || echo -e "$*"; }
summary() { echo -e "$*"; }

if ! $DO_EXPORT && ! $DO_APPLY; then
  DO_EXPORT=true
fi

if ! $DO_EXPORT && ! $DO_APPLY; then
  DO_EXPORT=true
fi

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  ENV_PATH="$ENV_FILE"
elif [[ -f ../../backend/.env ]]; then
  ENV_PATH=../../backend/.env
elif [[ -f .env ]]; then
  ENV_PATH=.env
else
  echo "❌ .env file not found! Pass path as argument or place in ../../backend/.env or ."
  exit 1
fi

if $DO_EXPORT; then
  summary "ℹ️  Loading environment from $ENV_PATH"
  export $(grep -v '^#' "$ENV_PATH" | grep -v '^VAULT_' | xargs)
  : "${COUCHBASE_USERNAME:?Must set COUCHBASE_USERNAME in .env}"
  : "${COUCHBASE_PASSWORD:?Must set COUCHBASE_PASSWORD in .env}"
  : "${COUCHBASE_HOST:?Must set COUCHBASE_HOST in .env}"
  : "${COUCHBASE_PORT:=8091}"

  OUTPUT="couchbase_rbac.json"
  curl -s -u "${COUCHBASE_USERNAME}:${COUCHBASE_PASSWORD}" \
    "http://${COUCHBASE_HOST}:${COUCHBASE_PORT}/settings/rbac/users/local" \
    | jq '.' > "$OUTPUT"
  if [[ $? -eq 0 ]]; then
    summary "✅ Exported Couchbase RBAC users to $OUTPUT"
    echo
  else
    echo "❌ Failed to export RBAC users."
    exit 2
  fi
fi

if $DO_APPLY; then
  OUTPUT="couchbase_rbac.json"
  if [[ ! -f "$OUTPUT" ]]; then
    echo "❌ $OUTPUT not found. Run with --export first or ensure export exists."
    exit 1
  fi

  # Fetch all IDs (once)
  ALL_IDS=($(jq -r '.[].id' "$OUTPUT"))

  # Auto-detect if not set
  if [[ -z "$READ_ID" ]]; then
    READ_ID=$(printf "%s\n" "${ALL_IDS[@]}" | grep -i "read[_-]*only" | head -n1)
  fi
  if [[ -z "$READ_ID" ]]; then
    READ_ID=$(printf "%s\n" "${ALL_IDS[@]}" | grep -i "readonly" | head -n1)
  fi
  if [[ -z "$READ_ID" ]]; then
    READ_ID=$(printf "%s\n" "${ALL_IDS[@]}" | head -n1)
  fi
  if [[ -z "$WRITE_ID" ]]; then
    WRITE_ID=$(printf "%s\n" "${ALL_IDS[@]}" | grep -i "read[_-]*write" | head -n1)
  fi
  if [[ -z "$WRITE_ID" ]]; then
    WRITE_ID=$(printf "%s\n" "${ALL_IDS[@]}" | grep -i "readwrite" | head -n1)
  fi
  if [[ -z "$WRITE_ID" ]]; then
    WRITE_ID=$(printf "%s\n" "${ALL_IDS[@]}" | tail -n1)
  fi

  # Print what will be used
  summary "ℹ️  Using readonly user ID:  $READ_ID"
  summary "ℹ️  Using readwrite user ID: $WRITE_ID"
  echo 

  generate_vault_role() {
  local ROLE_ID="$1"
  local ROLE_NAME="$2"
  local ROLES
  ROLES=$(jq -r --arg id "$ROLE_ID" '
    .[] | select(.id==$id) | .roles[] |
    "\(.role) \(.bucket_name // "*")"
  ' "$OUTPUT" | sort | uniq)

  if [[ -z "$ROLES" ]]; then
    echo "❌ No roles found for user $ROLE_ID"
    exit 3
  fi

  # Build creation_statements JSON
  local JSON="["
  local first=1
  while read -r line; do
    [[ -z "$line" ]] && continue
    ROLE=$(awk '{print $1}' <<< "$line")
    BUCKET=$(awk '{print $2}' <<< "$line")
    [[ $first -eq 0 ]] && JSON+=", "
    JSON+="{ \"role\": \"$ROLE\", \"bucket_name\": \"$BUCKET\" }"
    first=0
  done <<< "$ROLES"
  JSON+="]"

  # Only show full Vault command in non-quiet mode
  if ! $DO_QUIET; then
    echo
    echo "Vault command for '$ROLE_NAME' role (from user $ROLE_ID):"
    echo "vault write database/roles/$ROLE_NAME \\"
    echo "  db_name=\"couchbase\" \\"
    echo "  creation_statements='{\"roles\": $JSON}' \\"
    echo "  default_ttl=\"1h\" \\"
    echo "  max_ttl=\"24h\""
  fi

  if ! $DO_DRYRUN; then
    # --- Backup before updating ---
    SNAPSHOT_FILE="vault_role_backup_${ROLE_NAME}_$(date +%Y%m%d_%H%M%S).json"
    if vault read -format=json database/roles/$ROLE_NAME > "$SNAPSHOT_FILE" 2>/dev/null; then
      summary "📦 Previous Vault role for '$ROLE_NAME' backed up to $SNAPSHOT_FILE"
    else
      summary "ℹ️  No previous Vault role for '$ROLE_NAME' (nothing to back up)."
    fi
    # --- Apply new role ---
    summary "⚠️  Applying role '$ROLE_NAME' to Vault..."
    vault write database/roles/$ROLE_NAME \
      db_name="couchbase" \
      creation_statements="{\"roles\": $JSON}" \
      default_ttl="1h" \
      max_ttl="24h" >/dev/null
    summary "✅ Applied $ROLE_NAME role!"
    echo
  else
    if ! $DO_QUIET; then
      echo "📝 (dry-run) Not applied."
    fi
  fi
}

  generate_vault_role "$READ_ID" "readonly"
  generate_vault_role "$WRITE_ID" "readwrite"
fi

if $DO_EXPORT && $DO_APPLY; then
  summary "🏁 Couchbase RBAC exported and Vault roles updated successfully."
elif $DO_EXPORT; then
  summary "🏁 Couchbase RBAC exported successfully."
elif $DO_APPLY; then
  summary "🏁 Vault roles updated successfully."
fi

human_duration() {
  local S=$1
  (( S < 60 )) && { echo "${S}s"; return; }
  local M=$(( S / 60 ))
  local S2=$(( S % 60 ))
  echo "${M}m ${S2}s"
}
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))
summary "⏱️ Completed in $(human_duration "$DURATION")"
