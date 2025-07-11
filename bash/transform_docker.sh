#!/opt/homebrew/bin/bash
set -euo pipefail

# 🧪 Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  source "${SCRIPT_DIR}/.env"
  set +a
else
  echo "❌ .env file missing next to transform_docker.sh"
  exit 1
fi

DOCKERHUB_REPO="${DOCKERHUB_REPO:-}"
if [[ -z "$DOCKERHUB_REPO" ]]; then
  echo "❌ DOCKERHUB_REPO not set in .env"
  exit 1
fi

# 🚀 Defaults
COMPOSE_FILE="docker-compose.yml"
MODULE_DIR="./modules"
NETWORK_MODULE="$MODULE_DIR/network"
STORAGE_MODULE="$MODULE_DIR/storage"
IMAGES_MODULE="$MODULE_DIR/images"
COMPUTE_MODULE="$MODULE_DIR/compute"

PROVIDER="docker"
BUILD_ENABLED=false

# 🧠 Image mapping
declare -A SERVICE_IMAGE_VARS

# 🔐 Global map to avoid unbound errors
declare -A MERGED_ENV_VARS

# 🎮 Parse CLI flags
while [[ $# -gt 0 ]]; do
  case "$1" in
  --provider)
    PROVIDER="$2"
    shift 2
    ;;
  --build)
    BUILD_ENABLED=true
    shift
    ;;
  *)
    echo "❌ Unknown argument: $1"
    exit 1
    ;;
  esac
done

echo ""
echo "🐳  Provider: $PROVIDER"
echo "🔧 Build enabled: $BUILD_ENABLED"
echo "🔄 Parsing $COMPOSE_FILE into Terraform modules..."
echo ""

mkdir -p "$NETWORK_MODULE" "$COMPUTE_MODULE" "$STORAGE_MODULE" "$IMAGES_MODULE"

# 🧱 Provider block
MODULE_PROVIDER_TF=$(
  cat <<EOF
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
EOF
)

for mod in "$NETWORK_MODULE" "$COMPUTE_MODULE" "$STORAGE_MODULE" "$IMAGES_MODULE"; do
  echo "$MODULE_PROVIDER_TF" >"$mod/provider.tf"
done

# 🌐 Network
NETWORK_NAME=$(yq '.networks | keys | .[0] // ""' "$COMPOSE_FILE")
if [[ -n "$NETWORK_NAME" ]]; then
  cat >"$NETWORK_MODULE/${PROVIDER}_network.tf" <<EOF
resource "${PROVIDER}_network" "$NETWORK_NAME" {
  name = "$NETWORK_NAME"
}
EOF
else
  NETWORK_NAME="bridge"
fi

# 💾 Volumes (safe check)
if [[ $(yq e '.volumes' "$COMPOSE_FILE") != "null" ]]; then
  yq e '.volumes | keys | .[]' "$COMPOSE_FILE" | while read -r VOL; do
    cat >"$STORAGE_MODULE/${VOL}_volume.tf" <<EOF
resource "${PROVIDER}_volume" "$VOL" {
  name = "$VOL"
}
EOF
  done
fi

# ⚙️ Services
for SERVICE in $(yq -r '.services | keys | .[]' "$COMPOSE_FILE"); do
  MERGED_ENV_VARS=() # 🔄 Reset map at start of loop
  SERVICE_FILE="$COMPUTE_MODULE/${SERVICE}.tf"
  IMAGE=$(yq ".services.${SERVICE}.image // \"null\"" "$COMPOSE_FILE")
  BUILD_CONTEXT=$(yq ".services.${SERVICE}.build.context // \"\"" "$COMPOSE_FILE")
  # ENV_FILE=$(yq ".services.${SERVICE}.env_file[0] // \"\"" "$COMPOSE_FILE")
  RAW_ENV_PATH=$(yq -r ".services.${SERVICE}.env_file // \"\"" "$COMPOSE_FILE")

  if [[ -z "$RAW_ENV_PATH" || "$RAW_ENV_PATH" == "null" ]]; then
    ENV_FILE=""
  else
    # Explicitly handle the array form of env_file
    if yq -e ".services.${SERVICE}.env_file | type == \"!!seq\"" "$COMPOSE_FILE" >/dev/null; then
      RAW_ENV_PATH=$(yq -r ".services.${SERVICE}.env_file[0]" "$COMPOSE_FILE")
    fi

    # Remove leading "./" to avoid duplication
    RAW_ENV_PATH="${RAW_ENV_PATH#./}"

    # Absolute path resolution relative to compose file
    ENV_FILE="$(
      cd "$(dirname "$COMPOSE_FILE")"
      pwd
    )/${RAW_ENV_PATH}"
  fi

  VOLUME_MOUNT=$(yq ".services.${SERVICE}.volumes[0] // \"\"" "$COMPOSE_FILE")
  PORTS=$(yq ".services.${SERVICE}.ports // []" "$COMPOSE_FILE" | yq 'join(", ")')
  TTY=$(yq ".services.${SERVICE}.tty // false" "$COMPOSE_FILE")
  STDIN_OPEN=$(yq ".services.${SERVICE}.stdin_open // false" "$COMPOSE_FILE")
  PRIVILEGED=$(yq ".services.${SERVICE}.privileged // false" "$COMPOSE_FILE")
  CAP_ADD=$(yq ".services.${SERVICE}.cap_add // []" "$COMPOSE_FILE")

  if [[ "$IMAGE" == "null" && "$BUILD_CONTEXT" == "" ]]; then
    echo "⚠️  Warning: No image or build context defined for service: $SERVICE"
    continue
  fi

  # 🔨 Build if needed
  if [[ "$BUILD_ENABLED" == "true" && "$BUILD_CONTEXT" != "" ]]; then
    echo "🔧 Building image for $SERVICE from $BUILD_CONTEXT ..."
    VERSION_FILE="${BUILD_CONTEXT}/.image_version"
    if [[ -f "$VERSION_FILE" ]]; then
      VERSION=$(cat "$VERSION_FILE")
      IFS='.' read -r major minor patch <<<"${VERSION:-0.0.0}"
    else
      major=0
      minor=1
      patch=0
    fi
    patch=$((patch + 1))
    NEW_VERSION="${major}.${minor}.${patch}"
    echo "$NEW_VERSION" >"$VERSION_FILE"

    IMAGE="${DOCKERHUB_REPO}/${SERVICE}:${NEW_VERSION}"
    docker build -t "$IMAGE" -t "${DOCKERHUB_REPO}/${SERVICE}:latest" "$BUILD_CONTEXT"
    docker push "$IMAGE"
    docker push "${DOCKERHUB_REPO}/${SERVICE}:latest"
    echo "📦 Built and pushed: $IMAGE"
  fi

  # 🖼 Write docker_image + output
  IMAGE_OUTPUT_KEY=$(echo "$SERVICE" | tr '-' '_')
  SERVICE_IMAGE_VARS["$SERVICE"]="$IMAGE_OUTPUT_KEY"

  cat >"$IMAGES_MODULE/${SERVICE}.tf" <<EOF
resource "docker_image" "$SERVICE" {
  name = "$IMAGE"
}
EOF

  echo "output \"${IMAGE_OUTPUT_KEY}_image\" {
  value = docker_image.${SERVICE}.name
  }" >>"$IMAGES_MODULE/outputs.tf"

  # 🧱 Container definition
  echo "resource \"docker_container\" \"$SERVICE\" {" >"$SERVICE_FILE"
  echo "  name  = \"$SERVICE\"" >>"$SERVICE_FILE"
  echo "  image = var.${IMAGE_OUTPUT_KEY}_image" >>"$SERVICE_FILE"

  if [[ "$PORTS" != "" ]]; then
    for port in $(echo "$PORTS" | sed 's/, /\n/g'); do
      echo "  ports {" >>"$SERVICE_FILE"
      echo "    internal = ${port##*:}" >>"$SERVICE_FILE"
      echo "    external = ${port%%:*}" >>"$SERVICE_FILE"
      echo "  }" >>"$SERVICE_FILE"
    done
  fi

  # 🧊 Merge env_file + environment block into a single env list
  if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    while IFS='=' read -r KEY VALUE; do
      [[ -z "$KEY" || "$KEY" =~ ^# ]] && continue
      MERGED_ENV_VARS["$KEY"]="$VALUE"
    done <"$ENV_FILE"
  fi

  INLINE_ENV=$(yq -r ".services.${SERVICE}.environment // {}" "$COMPOSE_FILE")
  if [[ "$INLINE_ENV" != "{}" ]]; then
    while IFS= read -r LINE; do
      KEY=$(echo "$LINE" | cut -d':' -f1 | xargs)
      VALUE=$(echo "$LINE" | cut -d':' -f2- | xargs)
      MERGED_ENV_VARS["$KEY"]="$VALUE"
    done < <(echo "$INLINE_ENV" | yq -r 'to_entries[] | "\(.key):\(.value)"')
  fi

  if [[ ${#MERGED_ENV_VARS[@]} -gt 0 ]]; then
    echo "  env = [" >>"$SERVICE_FILE"
    for KEY in "${!MERGED_ENV_VARS[@]}"; do
      echo "    \"${KEY}=${MERGED_ENV_VARS[$KEY]}\"," >>"$SERVICE_FILE"
    done
    echo "  ]" >>"$SERVICE_FILE"
  fi

  if [[ "$VOLUME_MOUNT" != "" ]]; then
    VOL_SRC=$(echo "$VOLUME_MOUNT" | cut -d':' -f1)
    VOL_DST=$(echo "$VOLUME_MOUNT" | cut -d':' -f2 | cut -d':' -f1)
    echo "  volumes {" >>"$SERVICE_FILE"
    echo "    volume_name    = \"$VOL_SRC\"" >>"$SERVICE_FILE"
    echo "    container_path = \"$VOL_DST\"" >>"$SERVICE_FILE"
    [[ "$VOLUME_MOUNT" == *":ro" ]] && echo "    read_only = true" >>"$SERVICE_FILE"
    echo "  }" >>"$SERVICE_FILE"
  fi

  if [[ "$CAP_ADD" != "[]" ]]; then
    echo "  capabilities {" >>"$SERVICE_FILE"
    echo "    add = [$(echo "$CAP_ADD" | yq 'map("\"" + . + "\"") | join(", ")')]" >>"$SERVICE_FILE"
    echo "  }" >>"$SERVICE_FILE"
  fi

  [[ "$TTY" == "true" ]] && echo "  tty = true" >>"$SERVICE_FILE"
  [[ "$STDIN_OPEN" == "true" ]] && echo "  stdin_open = true" >>"$SERVICE_FILE"
  [[ "$PRIVILEGED" == "true" ]] && echo "  privileged = true" >>"$SERVICE_FILE"

  echo "  networks_advanced {" >>"$SERVICE_FILE"
  echo "    name = \"$NETWORK_NAME\"" >>"$SERVICE_FILE"
  echo "  }" >>"$SERVICE_FILE"
  echo "}" >>"$SERVICE_FILE"

done

# 📦 Add variables for all container image vars
: >"$COMPUTE_MODULE/variables.tf"
for SERVICE in "${!SERVICE_IMAGE_VARS[@]}"; do
  VAR_NAME="${SERVICE_IMAGE_VARS[$SERVICE]}_image"
  echo "variable \"$VAR_NAME\" {
  description = \"Docker image for $SERVICE\"
  type        = string
}" >>"$COMPUTE_MODULE/variables.tf"
done

# 📤 Add outputs for container name and IP
: >"$COMPUTE_MODULE/outputs.tf"
for SERVICE in "${!SERVICE_IMAGE_VARS[@]}"; do
  echo "output \"${SERVICE}_name\" {
  value = docker_container.${SERVICE}.name
}" >>"$COMPUTE_MODULE/outputs.tf"
done

# 🧾 Root Terraform Files
cat >main.tf <<EOF
module "network" {
  source = "./modules/network"
}

module "storage" {
  source = "./modules/storage"
}

module "images" {
  source = "./modules/images"
}

module "compute" {
  source = "./modules/compute"
EOF

for SERVICE in "${!SERVICE_IMAGE_VARS[@]}"; do
  VAR="${SERVICE_IMAGE_VARS[$SERVICE]}_image"
  echo "  $VAR = module.images.$VAR" >>main.tf
done

echo "}" >>main.tf

cat >provider.tf <<EOF
$MODULE_PROVIDER_TF
EOF

cat >variables.tf <<EOF
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = ""
}
EOF

# 📤 Root outputs for HCP visibility
: >outputs.tf
for SERVICE in "${!SERVICE_IMAGE_VARS[@]}"; do
  echo "output \"${SERVICE}_name\" {
  value = module.compute.${SERVICE}_name
}" >>outputs.tf
done

# 📦 Also expose image names from image module
for SERVICE in "${!SERVICE_IMAGE_VARS[@]}"; do
  VAR="${SERVICE_IMAGE_VARS[$SERVICE]}_image"
  echo "output \"$VAR\" {
  value = module.images.$VAR
}" >>outputs.tf
done

echo ""
echo "✅ All modules created!"
echo "🌟 You're ready. Run: terraform init && terraform apply"
