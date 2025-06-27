#!/bin/bash

# transform_docker.sh
# Converts a Docker Compose service to a Nomad job file (.hcl)
# Usage: ./transform_docker.sh --service <name> --image <image> [--force] [--dry-run] [--register]

set -euo pipefail

# ---- Load .env if present ----
if [[ -f .env ]]; then
  set -a
  grep -E '^[A-Z_][A-Z0-9_]*=' .env | sed 's/\r$//' >.env.cleaned
  source .env.cleaned
  rm .env.cleaned
  set +a
fi

NOMAD_ADDR="${NOMAD_ADDR:-http://localhost:4646}"

# ---- Colors & Formatting ----
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)
red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

# ---- Parse Arguments ----
FORCE=false
DRY_RUN=false
REGISTER=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  --service)
    SERVICE="$2"
    shift 2
    ;;
  --image)
    IMAGE="$2"
    shift 2
    ;;
  --force)
    FORCE=true
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --register)
    REGISTER=true
    shift
    ;;
  *)
    echo "❌ Unknown argument: $1"
    exit 1
    ;;
  esac
done

# ---- Validations ----
if [[ -z "${SERVICE:-}" || -z "${IMAGE:-}" ]]; then
  echo "❌ ${red}Error: Both --service and --image must be provided.${reset}"
  echo "Usage: ./transform_docker.sh --service <name> --image <image>"
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo "❌ ${red}yq is required but not installed. Install: https://github.com/mikefarah/yq${reset}"
  exit 1
fi

COMPOSE_FILE="docker-compose.yml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "❌ ${red}docker-compose.yml not found in current directory.${reset}"
  exit 1
fi

# ---- Paths ----
TARGET_DIR="./$SERVICE"
TARGET_HCL="$TARGET_DIR/$SERVICE.hcl"
mkdir -p "$TARGET_DIR"

# ---- Extract Compose Data ----
PORTS=$(yq ".services.\"$SERVICE\".ports[]" "$COMPOSE_FILE" 2>/dev/null || echo "")
ENVS=$(yq ".services.\"$SERVICE\".environment[]" "$COMPOSE_FILE" 2>/dev/null || echo "")
VOLUMES=$(yq ".services.\"$SERVICE\".volumes[]" "$COMPOSE_FILE" 2>/dev/null || echo "")
PRIVILEGED=$(yq ".services.\"$SERVICE\".privileged" "$COMPOSE_FILE" 2>/dev/null || echo "false")
CAP_ADDS=$(yq ".services.\"$SERVICE\".cap_add[]" "$COMPOSE_FILE" 2>/dev/null || echo "")

# ---- Compose HCL blocks ----

# --- Map container port numbers to friendly names
get_port_name() {
  case "$1" in
  22) echo "ssh" ;;
  80) echo "http" ;;
  443) echo "https" ;;
  3306) echo "mysql" ;;
  5432) echo "postgres" ;;
  6379) echo "redis" ;;
  27017) echo "mongo" ;;
  *) echo "port$1" ;;
  esac
}

PORT_BLOCK=""
PORT_LIST=""

for port in $PORTS; do
  [[ "$port" == *":"* ]] || continue
  HOST_PORT=$(echo "$port" | cut -d':' -f1)
  CONTAINER_PORT=$(echo "$port" | cut -d':' -f2)
  PORT_NAME=$(get_port_name "$CONTAINER_PORT")
  PORT_BLOCK+="
      port \"$PORT_NAME\" {
        static = $HOST_PORT
        to     = $CONTAINER_PORT
      }"
  PORT_LIST+="\"$PORT_NAME\", "
done
PORT_LIST=${PORT_LIST%, }

ENV_BLOCK=""
for env in $ENVS; do
  ENV_BLOCK+="        $env\n"
done

# Format Docker-style volume mounts
VOLUME_ENTRIES=""
for vol in $VOLUMES; do
  CLEANED=$(echo "$vol" | cut -d':' -f1,2)
  VOLUME_ENTRIES+="\"$CLEANED\", "
done
VOLUME_ENTRIES=${VOLUME_ENTRIES%, }

# Privileged/cap_add
PRIV_BLOCK=""
if [[ "$PRIVILEGED" == "true" ]]; then
  PRIV_BLOCK+="        privileged = true\n"
fi
if [[ -n "$CAP_ADDS" ]]; then
  PRIV_BLOCK+="        cap_add = ["
  for cap in $CAP_ADDS; do
    PRIV_BLOCK+="\"$cap\", "
  done
  PRIV_BLOCK="${PRIV_BLOCK%, }]\n"
fi

# ---- Overwrite confirmation ----
if [[ -f "$TARGET_HCL" && "$FORCE" != true ]]; then
  read -p "⚠️  $TARGET_HCL exists. Overwrite? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || {
    echo "❌ Aborted."
    exit 1
  }
fi

# ---- Output path ----
if [[ "$DRY_RUN" == true ]]; then
  echo "🔍 ${yellow}Dry run mode enabled. Generated HCL will be printed:${reset}"
  OUTPUT_TARGET="/dev/stdout"
else
  OUTPUT_TARGET="$TARGET_HCL"
fi

# ---- Generate Nomad HCL ----
cat >"$OUTPUT_TARGET" <<EOF
job "$SERVICE" {
  datacenters = ["dc1"]

  group "$SERVICE-group" {
    network {
      $PORT_BLOCK
    }

    task "$SERVICE-task" {
      driver = "docker"

      config {
        image = "$IMAGE"
        ports = [$PORT_LIST]
        volumes = [$VOLUME_ENTRIES]
$(echo -e "$PRIV_BLOCK")
      }

      env = {
$(echo -e "$ENV_BLOCK")
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
EOF

if [[ "$DRY_RUN" == false ]]; then
  echo -e "✅ ${green}Nomad job created:${reset} $TARGET_HCL"
fi

# ---- Optional README.md ----
if [[ "$DRY_RUN" != true ]]; then
  read -p "📝 Generate README.md alongside the job file? [y/N]: " readme
  if [[ "$readme" =~ ^[Yy]$ ]]; then
    cat >"$TARGET_DIR/README.md" <<EOM
# $SERVICE Nomad Job

This Nomad job runs the containerized service **$SERVICE** using the image:

\`\`\`
image: $IMAGE
\`\`\`

## Generated from Docker Compose

This job was auto-generated using \`transform_docker.sh\`.

You can run it with:
\`\`\`
nomad job run $SERVICE.hcl
\`\`\`
EOM
    echo "📄 README.md created in $TARGET_DIR"
  fi
fi

# ---- Register job with Nomad ----
if [[ "$REGISTER" == true && "$DRY_RUN" != true ]]; then
  echo -e "🚀 Registering job with Nomad at ${yellow}$NOMAD_ADDR${reset}..."
  NOMAD_ADDR="$NOMAD_ADDR" nomad job run "$TARGET_HCL"
fi
