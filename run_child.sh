#!/usr/bin/env bash
set -euo pipefail

# Runs the PTP client (child) and, optionally, phc2sys to sync system clock from PHC

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/config.json"
CONF_DIR="$HERE/Config"
PTP_CONF="$CONF_DIR/ptp4l-child.conf"

IFACE=$(jq -r '.interface' "$CFG")
L2=$(jq -r '.layer2' "$CFG")
PHC2SYS=$(jq -r '.enable_phc2sys' "$CFG")

[[ -f "$PTP_CONF" ]] || { echo "Missing $PTP_CONF"; exit 1; }

# Detect gPTP (802.1AS) profile from the conf
if grep -Eq '^[[:space:]]*gPTP[[:space:]]+1[[:space:]]*$' "$PTP_CONF"; then
  GPTP_MODE=true
else
  GPTP_MODE=false
fi

# Transport flag (-2 for L2)
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

# Only add -s (slaveOnly) when NOT in gPTP mode
SLAVEFLAG=""
if [[ "$GPTP_MODE" == "false" ]]; then
  SLAVEFLAG="-s"
fi

echo "Starting ptp4l (CLIENT) on $IFACE using $PTP_CONF ..."
sudo ptp4l -f "$PTP_CONF" -i "$IFACE" $L2FLAG $SLAVEFLAG -m &

if [[ "$PHC2SYS" == "true" ]]; then
  echo "Starting phc2sys (-a -r) ..."
  sudo phc2sys -a -r -m &
fi

echo "Child running. (Foreground jobs) Press Ctrl+C to stop."
wait
