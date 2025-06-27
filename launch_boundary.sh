#!/bin/bash
set -e

cd /Users/raymon.epping/Documents/VSC/HashiCorp/Boundary/ || exit 1

# --- Colors ---
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[1;31m"
RESET="\033[0m"

LOG_DIR="/Users/raymon.epping/Documents/VSC/Personal/Sportclub_Reeuwijk/logs"
LOG_FILE="$LOG_DIR/boundary_worker.log"

CONFIG_FILE=""
FORCE=false

# --- Parse arguments ---
for arg in "$@"; do
  case $arg in
  --config=*)
    CONFIG_FILE="${arg#*=}"
    ;;
  --force)
    FORCE=true
    ;;
  *)
    echo -e "${RED}❌ Unknown argument: $arg${RESET}"
    exit 1
    ;;
  esac
done

# --- Prompt selection if not passed ---
if [[ -z "$CONFIG_FILE" ]]; then
  echo -e "${CYAN}📂 Available HCL server configs:${RESET}"
  i=0
  hcl_files=()
  for file in *.hcl; do
    echo "$((++i)). $file"
    hcl_files+=("$file")
  done

  read -p $'\n👉 Select config file number: ' choice
  CONFIG_FILE="${hcl_files[$((choice - 1))]}"
fi

echo -e "${CYAN}📄 Using config: $CONFIG_FILE${RESET}"

# --- Validate ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}❌ Config file '$CONFIG_FILE' not found.${RESET}"
  exit 1
fi

# --- Check for running server ---
echo -e "${CYAN}🔍 Checking for running Boundary server..${RESET}"
EXISTING_PID=$(pgrep -f "boundary server -config=$CONFIG_FILE" || true)

if [[ -n "$EXISTING_PID" ]]; then
  echo -e "${YELLOW}⚠️ Already running with PID $EXISTING_PID.${RESET}"
  if $FORCE; then
    echo -e "${RED}⚠️ Force enabled. Killing process $EXISTING_PID...${RESET}"
    kill "$EXISTING_PID"
    sleep 2
  else
    echo -e "${YELLOW}ℹ️ Use --force to restart it.${RESET}"
    exit 0
  fi
else
  echo -e "${GREEN}✅ No existing Boundary server found.${RESET}"
fi

# --- Launch the server ---
echo -e "${CYAN}🚀 Starting Boundary server in background...${RESET}"
./boundary server -config="$CONFIG_FILE" >"$LOG_FILE" 2>&1 &
PID=$!
sleep 2

# --- Debug confirmation ---
echo -e "${CYAN}🔎 Checking if process $PID is alive...${RESET}"
if ps -p "$PID" >/dev/null; then
  echo -e "${GREEN}✅ Boundary server running with PID $PID. Log: $LOG_FILE${RESET}"
else
  echo -e "${RED}❌ Boundary server failed to start. Check $LOG_FILE for details.${RESET}"
  tail -n 15 "$LOG_FILE"
  exit 1
fi
