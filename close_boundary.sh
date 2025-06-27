#!/bin/bash
set -e

# --- Colors ---
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[1;31m"
RESET="\033[0m"

# --- Optional Flags ---
FORCE=false

if [[ "$1" == "--force" ]]; then
  FORCE=true
fi

# --- Find Boundary server process ---
echo -e "${CYAN}🔍 Searching for Boundary server process...${RESET}"
boundary_pids=$(pgrep -f 'boundary server -config' || true)

if [[ -n "$boundary_pids" ]]; then
  echo -e "${YELLOW}Found Boundary process(es):${RESET}"
  pgrep -laf 'boundary server -config'

  if $FORCE; then
    echo -e "\n${RED}--force used. Terminating Boundary processes...${RESET}"
    echo "$boundary_pids" | xargs kill
    echo -e "${GREEN}✅ Boundary server processes terminated.${RESET}"
  else
    read -p $'\n👉 Do you want to stop these Boundary processes? [y/N] ' confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      echo "$boundary_pids" | xargs kill
      echo -e "${GREEN}✅ Boundary server processes terminated.${RESET}"
    else
      echo -e "${YELLOW}⚠️  Skipping termination. No processes were stopped.${RESET}"
    fi
  fi
else
  echo -e "${GREEN}✅ Boundary is not currently running on your machine.${RESET}"
fi

# --- Check remaining boundary-related processes ---
echo -e "\n${CYAN}🔍 Remaining Boundary-related processes:${RESET}"
pgrep -laf boundary || echo -e "${GREEN}✅ No remaining Boundary processes.${RESET}"

# --- Optional health check ---
echo -e "\n${CYAN}🔍 Checking Boundary health endpoint (localhost:9200)...${RESET}"
if curl -s http://localhost:9200/health | grep -q 'healthy'; then
  echo -e "${YELLOW}⚠️  Boundary still reports as healthy on port 9200.${RESET}"
else
  echo -e "${GREEN}✅ Boundary is no longer responding on port 9200.${RESET}"
fi
