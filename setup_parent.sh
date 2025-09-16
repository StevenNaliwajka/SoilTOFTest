#!/usr/bin/env bash
set -euo pipefail

# Installs linuxptp + jq and writes /etc/linuxptp/ptp4l-master.conf

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/config.json"

if [[ ! -f "$CFG" ]]; then
  echo "Missing $CFG. Create it first."; exit 1
fi

# --- install linuxptp + jq ---
install_pkgs () {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y linuxptp jq
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y linuxptp jq
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y linuxptp jq
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm linuxptp jq
  else
    echo "Please install 'linuxptp' and 'jq' with your package manager."; exit 1
  fi
}
install_pkgs

IFACE=$(jq -r '.interface' "$CFG")
DOMAIN=$(jq -r '.domainNumber' "$CFG")
TS=$(jq -r '.time_stamping' "$CFG" | tr '[:upper:]' '[:lower:]')
PRIO1=$(jq -r '.priority1' "$CFG")

[[ "$TS" == "hardware" || "$TS" == "software" ]] || { echo "time_stamping must be 'hardware' or 'software'"; exit 1; }

sudo mkdir -p /etc/linuxptp

# Write master config
sudo tee /etc/linuxptp/ptp4l-master.conf >/dev/null <<EOF
[global]
domainNumber $DOMAIN
time_stampi_
