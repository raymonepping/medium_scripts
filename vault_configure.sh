#!/usr/bin/env bash
set -euo pipefail

# --- Load environment variables from .env if it exists ---
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
fi

# --- Config ---
ROLE_NAME="ssh-container-role"
POLICY_NAME="boundary-ssh-policy"
APPROLE_NAME="boundary-role"
TOKEN_FILE="./credentials/vault-token.json"

# Ensure credentials directory exists
mkdir -p ./credentials

log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
  exit 1
}

# --- Enable SSH secrets engine if not already enabled ---
if ! vault secrets list -format=json | jq -e 'has("ssh/")' >/dev/null; then
  log "Enabling SSH secrets engine at path 'ssh'"
  vault secrets enable -path=ssh ssh
  success "SSH secrets engine enabled"
else
  log "SSH secrets engine already enabled"
fi

# --- Create or update SSH role ---
log "Creating SSH CA signing role: $ROLE_NAME"
vault write ssh/roles/$ROLE_NAME - <<EOF
{
  "key_type": "ca",
  "allow_user_certificates": true,
  "default_user": "ubuntu",
  "allowed_users": "ubuntu",
  "cidr_list": "0.0.0.0/0",
  "ttl": "30m",
  "allow_user_key_ids": true,
  "default_extensions": {
    "permit-pty": ""
  }
}
EOF
success "SSH role created"

# --- Create boundary-ssh-policy ---
log "Writing policy: $POLICY_NAME"
vault policy write $POLICY_NAME - <<EOF
path "ssh/sign/$ROLE_NAME" {
  capabilities = ["create", "update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
path "sys/leases/renew" {
  capabilities = ["update"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
path "sys/capabilities-self" {
  capabilities = ["update"]
}
EOF
success "Policy written"

# --- Create AppRole ---
log "Creating AppRole: $APPROLE_NAME"
vault write auth/approle/role/$APPROLE_NAME \
  policies="$POLICY_NAME" \
  token_policies="$POLICY_NAME" \
  token_ttl="1h" \
  token_max_ttl="4h"
success "AppRole created"

# --- Fetch AppRole credentials ---
log "Fetching AppRole credentials"
ROLE_ID=$(vault read -field=role_id auth/approle/role/$APPROLE_NAME/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/$APPROLE_NAME/secret-id)
jq -n --arg role_id "$ROLE_ID" --arg secret_id "$SECRET_ID" '{role_id: $role_id, secret_id: $secret_id}' >./credentials/ssh-approle.json
success "AppRole credentials saved to ./credentials/ssh-approle.json"

# --- Create a Vault token (for Boundary) ---
log "Generating short-lived Vault token for Boundary"
VAULT_TOKEN=$(vault token create -format=json -policy="$POLICY_NAME" -period=1h -orphan | jq -r .auth.client_token)
jq -n --arg vault_token "$VAULT_TOKEN" '{vault_token: $vault_token}' >"$TOKEN_FILE"
success "Vault token saved to $TOKEN_FILE"

# --- Final success message ---

success "Vault setup completed successfully. Both AppRole and token ready."
