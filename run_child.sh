#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/config.json"
CONF_DIR="$HERE/Config"
PTP_CONF="$CONF_DIR/ptp4l-child.conf"

IFACE=$(jq -r '.interface' "$CFG")
L2=$(jq -r '.layer2' "$CFG")
PHC2SYS=$(jq -r '.enable_phc2sys' "$CFG")

[[ -f "$PTP_CONF" ]] || { echo "Missing $PTP_CONF"; exit 1; }

# Detect gPTP (either 'gPTP 1' or 'profile gPTP') and timestamping mode
GPTP_MODE=false
TS_MODE="hardware"
grep -Eqi '^[[:space:]]*gPTP[[:space:]]+1[[:space:]]*$' "$PTP_CONF" && GPTP_MODE=true
grep -Eqi '^[[:space:]]*profile[[:space:]]+gPTP[[:space:]]*$' "$PTP_CONF" && GPTP_MODE=true
grep -Eqi '^[[:space:]]*time_stamping[[:space:]]+software[[:space:]]*$' "$PTP_CONF" && TS_MODE="software"

# Transport (-2 when L2)
L2FLAG=""
[[ "$L2" == "true" ]] && L2FLAG="-2"

# Warn if transport mismatch
if grep -Eqi '^[[:space:]]*network_transport[[:space:]]+L2[[:space:]]*$' "$PTP_CONF"; then
  [[ "$L2" == "true" ]] || echo "WARNING: conf is L2 but layer2=false (no -2)."
else
  [[ "$L2" == "false" ]] || echo "WARNING: conf is UDP but layer2=true (adding -2)."
fi

# Build ptp4l args (NO '-s' here; let the conf specify slaveOnly when desired)
PTP_ARGS=(-f "$PTP_CONF" -i "$IFACE" -m)
[[ -n "$L2FLAG" ]] && PTP_ARGS+=("$L2FLAG")
[[ "$TS_MODE" == "software" ]] && PTP_ARGS+=(-S)

echo "Starting ptp4l (CLIENT) on $IFACE using $PTP_CONF ... (ts_mode=$TS_MODE, gPTP=$GPTP_MODE)"
sudo ptp4l "${PTP_ARGS[@]}" &

# Only run phc2sys if hardware timestamping (PHC present)
if [[ "$PHC2SYS" == "true" && "$TS_MODE" == "hardware" ]]; then
  echo "Starting phc2sys (-a -r) ..."
  sudo phc2sys -a -r -m &
else
  echo "Skipping phc2sys (software timestamping: no PHC)."
fi

echo "Child running. (Foreground jobs) Press Ctrl+C to stop."
wait
