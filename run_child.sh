#!/usr/bin/env bash
set -euo pipefail

# Runs the PTP client (slave-only) and, optionally, phc2sys to sync system clock from PHC

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/config.json"

IFACE=$(jq -r '.interface' "$CFG")
L2=$(jq -r '.layer2' "$CFG")
PHC2SYS=$(jq -r '.enable_phc2sys' "$CFG")

PTP_CONF="/etc/linuxptp/ptp4l-child.conf"
[[ -f "$PTP_CONF" ]] || { echo "Missing $PTP_CONF. Run setup_child.sh first."; exit 1; }

L2FLAG=""
if [[ "$L2" == "true" ]]; then
  L2FLAG="-2"
fi

echo "Starting ptp4l as CLIENT on $IFACE ..."
# -s: clientOnly (never tries to be master), -m: log to console
sudo ptp4l -f "$PTP_CONF" -i "$IFACE" $L2FLAG -s -m &

# Optional: sync the system clock from PHC once ptp4l disciplines it
if [[ "$PHC2SYS" == "true" ]]; then
  # -a: auto select ports; -r: PHC -> system clock
  echo "Starting phc2sys (-a -r) ..."
  sudo phc2sys -a -r -m &
fi

echo "Child running. (Foreground jobs) Press Ctrl+C to stop."
wait
