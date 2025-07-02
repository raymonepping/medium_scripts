#!/bin/bash
set -e
VERSION="0.0.1"

OUTPUT_FILE="cloudflare_tunnels.md"

WORKER_HCL_TEMPLATE="/Users/raymon.epping/Documents/VSC/HashiCorp/Boundary/worker_template.hcl"
GENERATED_WORKER_HCL="/Users/raymon.epping/Documents/VSC/HashiCorp/Boundary/local_worker.hcl"

# WORKER_HCL_TEMPLATE="worker_template.hcl"
# GENERATED_WORKER_HCL="worker.hcl"
LOG_DIR="/Users/raymon.epping/Documents/VSC/Personal/Sportclub_Reeuwijk/logs"
VAULT_LOG="$LOG_DIR/cloudflare_vault.log"
BOUNDARY_LOG="$LOG_DIR/cloudflare_boundary.log"
PIDS_FILE="cloudflare_pids.txt"

GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

>"$OUTPUT_FILE"
>"$PIDS_FILE"
echo -e "${CYAN}Launching Cloudflare tunnels...${RESET}"
echo "# Cloudflare Tunnels" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"

launch_tunnel() {
  local name=$1
  local port=$2
  local logfile=$3
  cloudflared tunnel --url "http://localhost:$port" >"$logfile" 2>&1 &
  local pid=$!
  echo "$pid" >>"$PIDS_FILE"
  sleep 10
  # Extract the pure URL (NO echo, NO color codes)
  grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$logfile" | head -n 1 | tr -d '\n'
}

# Only echo status to terminal, not into the variable!
echo -e "${YELLOW}Launching Cloudflare tunnel for Vault...${RESET}"
VAULT_URL=$(launch_tunnel "Vault" 8200 "$VAULT_LOG")
echo -e "${GREEN}Vault tunnel started.${RESET}"

if [ -n "$VAULT_URL" ]; then
  echo "- **Vault Tunnel**: [$VAULT_URL]($VAULT_URL)" >>"$OUTPUT_FILE"
else
  echo "- **Vault Tunnel**: [N/A](N/A)" >>"$OUTPUT_FILE"
fi

echo -e "${YELLOW}Launching Cloudflare tunnel for Boundary Worker...${RESET}"
BOUNDARY_URL=$(launch_tunnel "Boundary Worker" 9202 "$BOUNDARY_LOG")
echo -e "${GREEN}Boundary Worker tunnel started.${RESET}"

if [ -n "$BOUNDARY_URL" ]; then
  echo "- **Boundary Worker Tunnel**: [$BOUNDARY_URL]($BOUNDARY_URL)" >>"$OUTPUT_FILE"
else
  echo "- **Boundary Worker Tunnel**: [N/A](N/A)" >>"$OUTPUT_FILE"
fi

# --- Generate worker.hcl from template ---
if [ -n "$BOUNDARY_URL" ]; then
  BOUNDARY_PUBLIC_ADDR="$(echo "$BOUNDARY_URL" | sed 's|https://||'):9202"
  echo -e "${CYAN}Generating $GENERATED_WORKER_HCL with public_addr $BOUNDARY_PUBLIC_ADDR...${RESET}"
  sed "s|{{PUBLIC_ADDR}}|$BOUNDARY_PUBLIC_ADDR|g" "$WORKER_HCL_TEMPLATE" >"$GENERATED_WORKER_HCL"
  echo -e "${GREEN}✅ Generated $GENERATED_WORKER_HCL${RESET}"
else
  echo -e "${YELLOW}⚠️ No Boundary Worker tunnel URL found. Skipping worker.hcl generation.${RESET}"
fi

echo -e "\n${GREEN}✅ Tunnels launched. Use \`tail -f cloudflare_vault.log\` or \`cloudflare_boundary.log\` to view them.${RESET}"
echo -e "${CYAN}📄 Tunnel URLs saved to $OUTPUT_FILE${RESET}"

if command -v code &>/dev/null; then
  code "$OUTPUT_FILE"
fi
