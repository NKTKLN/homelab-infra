#!/usr/bin/env bash

set -e

# ========================================================
#  SSH known_hosts Refresher for Ansible Inventory
# ========================================================
#
# Description:
#   This script automatically:
#     - Removes outdated SSH known_hosts fingerprints for all hosts
#       listed with 'ansible_host=' in the inventory file.
#     - Scans and adds fresh SSH host keys for those hosts.
#
# Why:
#   Useful when hosts are recreated, reinstalled, moved,
#   or when fingerprints change — helps avoid SSH warnings and failures.
#
# Usage:
#   ./refresh_known_hosts.sh
#
# ========================================================

# -------- CONFIG --------
INVENTORY_FILE="../ansible/inventory/home/hosts.ini"
# -------------------------

# -------- COLORS --------
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

info()  { echo -e "${BLUE}[*]${RESET} $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()   { echo -e "${RED}[ERR]${RESET} $*"; }
# -------------------------

# -------- VALIDATION --------
info "Checking the inventory file..."

if [[ ! -f "$INVENTORY_FILE" ]]; then
  err "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi
ok "Inventory file found."

# -------- CLEARING OLD HOST KEYS --------
info "Removing old known_hosts entries..."

while read -r host; do
    [[ -z "$host" ]] && continue
    echo -e "  – removing key for ${YELLOW}$host${RESET}"
    ssh-keygen -R "$host" >/dev/null 2>&1 || true
done < <(awk -F'=' '/ansible_host=/ {print $2}' "$INVENTORY_FILE")

ok "Old SSH host keys removed."

# -------- SCANNING NEW HOST KEYS --------
info "Scanning and adding new host keys..."

while read -r host; do
    [[ -z "$host" ]] && continue
    echo -e "  + adding key for ${BLUE}$host${RESET}"
    ssh-keyscan -H "$host" >> ~/.ssh/known_hosts 2>/dev/null || \
        warn "Could not scan $host (unreachable?)"
done < <(awk -F'=' '/ansible_host=/ {print $2}' "$INVENTORY_FILE")

ok "New SSH host keys added."

# -------- DONE --------
echo
echo -e "${GREEN}SSH known_hosts update completed successfully.${RESET}"
