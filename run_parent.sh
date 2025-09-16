#!/usr/bin/env bash
set -euo pipefail

# Runs the PTP grandmaster and, optionally, phc2sys to discipline PHC<->system

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/config.json"

IFACE=$(jq -r '.interface' "$CFG")
L2=$(jq -r '.layer2' "$CFG")
PHC2SYS=$(jq -r '.enable_phc2sys' "$CFG")

PTP_CONF="/etc/linuxptp/ptp4l-master.conf"
[[ -f "$PTP_CONF" ]] || { echo "Missing $PTP_CONF. Run setup_parent.sh first."; exit 1; }

L2FLAG=""
if [[ "$L2" == "true" ]]; then
  L2FLAG="-2"
fi

echo "Starting ptp4l as MASTER on $IFACE ..."
# -m: print messages; remove if you prefer syslog/systemd units
sudo ptp4l -f "$PTP_CONF" -i "$IFACE" $L2FLAG -m &

# Optional: keep the NIC's PHC disciplined by the system clock when GM
if [[ "$PHC2SYS" == "true" ]]; then
  # -a: auto select ports; -rr: system clock -> PHC when GM (and vice versa if roles change)
  echo "Starting phc2sys (-a -rr) ..."
  sudo phc2sys -a -rr -m &
fi

echo "Parent running. (Foreground jobs) Press Ctrl+C to stop."
wait
