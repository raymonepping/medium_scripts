#!/bin/bash
set -e

PIDS_FILE="cloudflare_pids.txt"
FORCE=false
WAIT=false

# --- Colors ---
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
BLUE="\033[1;34m"
GREEN="\033[0;32m"
RESET="\033[0m"

# --- Parse arguments ---
for arg in "$@"; do
  case $arg in
  --force)
    FORCE=true
    ;;
  --wait)
    WAIT=true
    ;;
  esac
done

# --- Wait function ---
wait_for_cloudflared_shutdown() {
  echo -e "\n${CYAN}🕒 Waiting for cloudflared to shut down...${RESET}"
  MAX_ATTEMPTS=5
  DELAY=1
  attempt=1

  while [ $attempt -le $MAX_ATTEMPTS ]; do
    remaining=$(pgrep -laf cloudflared)
    if [ -z "$remaining" ]; then
      echo -e "\n${GREEN}✅ All tunnels successfully stopped.${RESET}"
      return
    fi
    echo -e "${YELLOW}⌛ Attempt $attempt/$MAX_ATTEMPTS: Waiting $DELAYs...${RESET}"
    sleep $DELAY
    DELAY=$((DELAY * 2))
    attempt=$((attempt + 1))
  done
}

echo -e "${YELLOW}🔍 Active Cloudflare tunnels before cleanup:${RESET}"
pgrep -laf cloudflared || echo -e "${GREEN}✅ No tunnels currently running.${RESET}"

if [ -f "$PIDS_FILE" ]; then
  echo -e "\n${BLUE}🛑 Stopping tunnels from $PIDS_FILE...${RESET}"
  while IFS= read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      echo -e "✅ Killed process with PID $pid"
    else
      echo -e "⚠️  PID $pid not found or already stopped."
    fi
  done <"$PIDS_FILE"

  rm "$PIDS_FILE"
  echo -e "\n📁 Removed $PIDS_FILE"
else
  echo -e "\n${RED}❌ No PIDs file found.${RESET}"

  cloudflared_pids=$(pgrep -f 'cloudflared tunnel --url')

  if [ -n "$cloudflared_pids" ]; then
    echo -e "\n${CYAN}⚠️  Found running cloudflared tunnels:${RESET}"
    echo "$cloudflared_pids"

    if $FORCE; then
      echo -e "\n${RED}--force used. Terminating all cloudflared tunnel processes...${RESET}"
      echo "$cloudflared_pids" | xargs kill
      echo -e "${GREEN}✅ All cloudflared processes terminated.${RESET}"
    else
      read -p $'\n👉 Do you want to save these PIDs to cloudflare_pids.txt for cleanup? [y/N] ' confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$cloudflared_pids" >"$PIDS_FILE"
        echo -e "\n💾 PIDs saved to $PIDS_FILE. Re-run the script to stop them."
      else
        echo -e "\n🚫 Skipped saving PIDs. Nothing was changed."
      fi
    fi
  else
    echo -e "${GREEN}✅ No running tunnels to save.${RESET}"
  fi
fi

# --- Wait if requested ---
if $WAIT; then
  wait_for_cloudflared_shutdown
fi

# --- Final check ---
echo -e "\n${YELLOW}🔍 Remaining cloudflared processes:${RESET}"
pgrep -laf cloudflared || echo -e "${GREEN}✅ All tunnels successfully stopped.${RESET}"
