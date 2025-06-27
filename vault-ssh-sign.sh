#!/bin/bash

set -euo pipefail

# === Configuration ===
KEY_NAME="vault-ca-demo"
PRINCIPAL="ubuntu"
ROLE_NAME="ssh-container-role"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
SSH_DIR="${HOME}/.ssh"
TTL="${TTL:-30m}"
FORCE_OVERWRITE=false
CONTAINER_NAME="vault-container" # Default SSH alias

# === Parse Arguments ===
for ((i = 1; i <= $#; i++)); do
  case "${!i}" in
  --force | -f)
    FORCE_OVERWRITE=true
    ;;
  --container | -c)
    j=$((i + 1))
    if [ $j -le $# ]; then
      CONTAINER_NAME="${!j}"
      shift
    else
      echo "❌ Missing value for --container"
      exit 1
    fi
    ;;
  --container=* | -c=*)
    CONTAINER_NAME="${!i#*=}"
    ;;
  *)
    if [[ "${!i}" == -* ]]; then
      echo "❌ Unknown argument: ${!i}"
      echo "Usage: $0 [--force|-f] [--container|-c <name>]"
      exit 1
    fi
    ;;
  esac
done

CONFIG_FILE="${SSH_DIR}/ssh-config-${KEY_NAME}"
KEY_PATH="${SSH_DIR}/${KEY_NAME}"

# === Prerequisites Check ===
for cmd in vault ssh-keygen; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' not found."
    exit 1
  fi
done

# === Generate Key Pair ===
echo "🔐 Generating SSH key pair: ${KEY_NAME}"
mkdir -p "$SSH_DIR"

if [[ -f "$KEY_PATH" && "$FORCE_OVERWRITE" != "true" ]]; then
  echo "❌ Key ${KEY_PATH} already exists. Use --force to overwrite."
  exit 1
fi

ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "vault-${PRINCIPAL}" <<<y >/dev/null

# === Sign Public Key via Vault ===
echo "📡 Requesting signed certificate from Vault at $VAULT_ADDR"
SIGNED_CERT=$(
  VAULT_ADDR="$VAULT_ADDR" \
    vault write -field=signed_key "ssh/sign/${ROLE_NAME}" \
    public_key=@"${KEY_PATH}.pub" \
    valid_principals="$PRINCIPAL" \
    ttl="$TTL"
)

echo "$SIGNED_CERT" >"${KEY_PATH}-cert.pub"
chmod 600 "${KEY_PATH}-cert.pub"

# === Generate SSH Config Snippet ===
echo "📄 Writing SSH config snippet to ${CONFIG_FILE}"
cat >"${CONFIG_FILE}" <<EOF
Host ${CONTAINER_NAME}
    HostName localhost
    Port 2222
    User ${PRINCIPAL}
    IdentityFile ${KEY_PATH}
    CertificateFile ${KEY_PATH}-cert.pub
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

# === Append to ~/.ssh/config if not already present ===
touch "${SSH_DIR}/config"
if ! grep -q "Host ${CONTAINER_NAME}" "${SSH_DIR}/config"; then
  echo "📄 Appending config to ${SSH_DIR}/config"
  cat "${CONFIG_FILE}" >>"${SSH_DIR}/config"
else
  echo "ℹ️ SSH config already contains '${CONTAINER_NAME}', skipping append."
fi

# === Output Success ===
echo "✅ Certificate signed and SSH config ready."
echo "➡️ Connect using: ssh ${CONTAINER_NAME}"
