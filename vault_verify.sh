#!/usr/bin/env bash
set -euo pipefail

# --- Logging ---
log_info() { [[ "$VERBOSE" == true ]] && echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; }

# --- Config ---
ENV_FILE=".env"
CREDENTIALS_DIR="./credentials"
CREDENTIALS_FILE="$CREDENTIALS_DIR/ssh-approle.json"
VERBOSE=false
JSON_OUTPUT=false
FORCE_OVERWRITE=false
BOUNDARY_TOKEN=false

# --- Load .env *before* flag parsing so env vars are present if needed ---
if [[ -f "$ENV_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[[:space:]]*# || -z "$key" ]] && continue
    export "$key"="$value"
  done <"$ENV_FILE"
else
  log_error "Missing .env file."
  exit 1
fi

# --- Parse Flags (only ONCE) ---
for arg in "$@"; do
  case $arg in
  --verbose) VERBOSE=true ;;
  --json) JSON_OUTPUT=true ;;
  --force) FORCE_OVERWRITE=true ;;
  --boundary-token) BOUNDARY_TOKEN=true ;;
  *) log_error "Unknown flag: $arg" && exit 1 ;;
  esac
done

# --- Determine token for signing ---
if [[ "$BOUNDARY_TOKEN" == true ]]; then
  if [[ -f "./credentials/vault-token.json" ]]; then
    TOKEN=$(jq -r .vault_token ./credentials/vault-token.json)
    log_info "Using boundary token from vault-token.json for signing test"
  else
    log_error "vault-token.json not found; cannot test with boundary token"
    exit 1
  fi
else
  TOKEN="${VAULT_TOKEN:-}"
  if [[ -z "$TOKEN" ]]; then
    log_error "VAULT_TOKEN is not set in environment or .env"
    exit 1
  fi
  log_info "Using VAULT_TOKEN from .env for signing test"
fi

# --- Helpers ---
cleanup() {
  [[ -f "$TEMP_KEY" ]] && rm -f "$TEMP_KEY" "$TEMP_KEY.pub"
}
trap cleanup EXIT

# --- Generate SSH test key ---
TEMP_KEY=$(mktemp /tmp/vault_ssh_test_key_XXXXXX)
log_info "Generating test SSH key..."

if [[ "$FORCE_OVERWRITE" == true ]]; then
  ssh-keygen -q -t ed25519 -f "$TEMP_KEY" -N "" <<<y >/dev/null
else
  ssh-keygen -t ed25519 -f "$TEMP_KEY" -N ""
fi

# --- Validations ---
log_info "Checking if SSH CA engine is enabled at path: $SSH_PATH"
vault secrets list -format=json | jq -e 'has("'"$SSH_PATH"'/")' >/dev/null || {
  log_error "SSH engine is not enabled at path: $SSH_PATH"
  exit 1
}

log_info "Validating SSH role: $ROLE_NAME"
vault read -format=json "$SSH_PATH/roles/$ROLE_NAME" | jq '.' >/dev/null || {
  log_error "Role $ROLE_NAME does not exist"
  exit 1
}

log_info "Validating policy $POLICY_NAME includes role $ROLE_NAME"
vault policy read "$POLICY_NAME" | grep "$ROLE_NAME" >/dev/null || {
  log_warn "Policy $POLICY_NAME may not explicitly mention role $ROLE_NAME"
}

log_info "Checking if AppRole $APPROLE_NAME exists"
vault list -format=json auth/approle/role | jq -e '.[] | select(. == "'"$APPROLE_NAME"'")' >/dev/null || {
  log_error "AppRole $APPROLE_NAME not found"
  exit 1
}

log_info "Validating AppRole policy binding"
vault read -format=json auth/approle/role/$APPROLE_NAME | jq -e '.data.policies | index("'"$POLICY_NAME"'")' >/dev/null || {
  log_warn "AppRole $APPROLE_NAME not bound to policy $POLICY_NAME"
}

log_info "Testing CA signing with correct token..."
CERT=$(VAULT_TOKEN="$TOKEN" vault write -field=signed_key "$SSH_PATH/sign/$ROLE_NAME" public_key=@"$TEMP_KEY.pub" valid_principals="$VALID_PRINCIPALS")
[[ -n "$CERT" ]] && log_success "Certificate signed" || {
  log_error "CA signing failed"
  exit 1
}

# --- AppRole Credentials ---
log_info "Reading AppRole credentials..."
ROLE_ID=$(vault read -field=role_id auth/approle/role/$APPROLE_NAME/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/$APPROLE_NAME/secret-id)
log_success "Retrieved AppRole credentials"

# --- Output handling & credential storage ---
mkdir -p "$CREDENTIALS_DIR"

if [[ "$JSON_OUTPUT" == true ]]; then
  jq -n --arg role_id "$ROLE_ID" --arg secret_id "$SECRET_ID" \
    '{role_id:$role_id, secret_id:$secret_id}' | tee "$CREDENTIALS_FILE"
else
  echo -e "\033[1;36mROLE_ID:\033[0m $ROLE_ID"
  echo -e "\033[1;36mSECRET_ID:\033[0m $SECRET_ID"
  jq -n --arg role_id "$ROLE_ID" --arg secret_id "$SECRET_ID" \
    '{role_id:$role_id, secret_id:$secret_id}' >"$CREDENTIALS_FILE"
fi

chmod 600 "$CREDENTIALS_FILE"
log_success "Credentials saved to: $CREDENTIALS_FILE"

log_success "Vault SSH CA validation completed"
log_info "Total runtime: ${SECONDS}s"
