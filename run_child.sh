#!/usr/bin/env bash
set -euo pipefail

# Runs the PTP client (slave-only) and, optionally, phc2sys to sync system clock from PHC

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/config.json"
CONF_DIR="$HERE/Config"
PTP_CONF="$CONF_DIR/ptp4l-child.conf"

IFACE=$(jq -r '.interface' "$CFG")
L2=$(jq -r '.layer2' "$CFG")
PHC2SYS=$(jq -r '.enable_phc2sys' "$CFG")

[[ -f "$PTP_CONF" ]] || { echo "Missing $PTP_CONF"; exit 1; }

# -2 only when using L2 frames
L2FLAG=""
if [[ "$L2" == "true" ]]; then
  L2FLAG="-2"
fi

# Sanity: warn if transport in conf doesn't match layer2 flag
if grep -Eq '^[[:space:]]*network_transport[[:space:]]+L2[[:space:]]*$' "$PTP_CONF"; then
  [[ "$L2" == "true" ]] || echo "WARNING: conf is L2 but config.json.layer2=false (no -2)."
else
  [[ "$L2" == "false" ]] || echo "WARNING: conf is UDP but config.json.layer2=true (adding -2)."
fi

echo "Starting ptp4l (CLIENT) on $IFACE using $PTP_CONF ..."
# -s forces clientOnly so it never tries to become master; -m logs to console
sudo ptp4l -f "$PTP_CONF" -i "$IFACE" $L2FLAG -s -m &

if [[ "$PHC2SYS" == "true" ]]; then
  echo "Starting phc2sys (-a -r) ..."
  # -a auto-binds; -r steers system clock from the PHC
  sudo phc2sys -a -r -m &
fi

echo "Child running. (Foreground jobs) Press Ctrl+C to stop."
wait
