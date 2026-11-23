#!/usr/bin/env bash
# Full read-only security + storage audit of a USB-connected iOS device.
# Writes a report folder. Does NOT modify the device (crash reports are copied,
# not removed). Uninstalling apps is a separate, explicit manual step.
set -uo pipefail

PULL_CRASH=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --crash) PULL_CRASH=1 ;;
    --out) shift; OUT="$1" ;;
    -h|--help) echo "Usage: audit.sh [--crash] [--out DIR]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# Load Homebrew on macOS if present.
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi

command -v idevice_id >/dev/null 2>&1 || { echo "Tools missing. Run scripts/setup.sh"; exit 1; }

UDID="$(idevice_id -l 2>/dev/null | head -1)"
if [ -z "$UDID" ]; then
  echo "No device found. Connect it, unlock, and accept 'Trust This Computer'."
  exit 1
fi

OUT="${OUT:-./audit-$UDID}"
mkdir -p "$OUT"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== iOS USB Security Audit =="
echo "Device UDID: $UDID"
echo "Report dir : $OUT"
echo

# 1. Device info
{
  echo "# Device info"
  for k in DeviceName ProductType ProductName ProductVersion BuildVersion \
           CPUArchitecture ModelNumber ActivationState; do
    printf "%-16s %s\n" "$k:" "$(ideviceinfo -k "$k" 2>/dev/null)"
  done
} | tee "$OUT/device-info.txt"
echo

# 2. Storage
echo "# Storage" | tee "$OUT/storage.txt"
AVAIL="$(ideviceinfo -q com.apple.disk_usage 2>/dev/null | awk -F': ' '/^AmountDataAvailable:/{print $2}')"
CAP="$(ideviceinfo -q com.apple.disk_usage 2>/dev/null | awk -F': ' '/^TotalDataCapacity:/{print $2}')"
if [ -n "${AVAIL:-}" ] && [ -n "${CAP:-}" ]; then
  python3 - "$AVAIL" "$CAP" <<'PY' | tee -a "$OUT/storage.txt"
import sys
a=int(sys.argv[1]); c=int(sys.argv[2])
print("Free : %.2f GB" % (a/1e9))
print("Used : %.2f GB of %.2f GB (%.1f%% full)" % ((c-a)/1e9, c/1e9, 100*(c-a)/c))
PY
fi
echo

# 3. App inventory + security triage
echo "# App inventory + security triage"
ideviceinstaller list --user --xml 2>/dev/null > "$OUT/apps.plist"
ideviceinstaller list --user 2>/dev/null > "$OUT/apps.csv"
python3 "$HERE/apptriage.py" < "$OUT/apps.plist" | tee "$OUT/app-triage.txt"
python3 "$HERE/apptriage.py" --json < "$OUT/apps.plist" > "$OUT/app-triage.json" 2>/dev/null
echo

# 4. Provisioning / management profiles
{
  echo "# Provisioning profiles (dev/enterprise)"
  ideviceprovision list 2>&1
  echo
  echo "# Wireless lockdown settings"
  ideviceinfo -q com.apple.mobile.wireless_lockdown 2>&1
} | tee "$OUT/profiles-network.txt"
echo

# 5. Crash reports (optional)
if [ "$PULL_CRASH" -eq 1 ]; then
  echo "# Crash reports"
  mkdir -p "$OUT/crashes"
  idevicecrashreport -k "$OUT/crashes" >/dev/null 2>&1
  echo "Crash files by source:" | tee "$OUT/crash-summary.txt"
  find "$OUT/crashes" -type f \( -name '*.ips' -o -name '*.crash' -o -name '*.panic' \) 2>/dev/null \
    | sed -E 's|.*/||; s/-[0-9]{4}-.*//; s/\.(ips|crash)$//' \
    | sort | uniq -c | sort -rn | tee -a "$OUT/crash-summary.txt"
  echo
fi

echo "== Done =="
echo "Report written to: $OUT"
echo
echo "On-device checks USB cannot do (hand these to the user):"
echo "  - Settings > General > VPN & Device Management (rogue profiles/MDM)"
echo "  - Settings > General > About > Certificate Trust Settings (rogue root CAs)"
echo "  - Settings > Wi-Fi > (i) (unexpected Proxy / DNS)"
echo "  - Settings > General > iPhone Storage (per-app sizes, offload)"
