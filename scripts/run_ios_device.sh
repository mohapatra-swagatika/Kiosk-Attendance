#!/usr/bin/env bash
# Run on a physical iPhone. Prefer USB; wireless needs Local Network permission on device.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_ID="${1:-}"

echo "==> Flutter devices"
flutter devices

if [[ -z "$DEVICE_ID" ]]; then
  # Prefer wired iOS device over wireless.
  DEVICE_ID="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
devices = json.load(sys.stdin)
ios = [d for d in devices if d.get('platform') == 'ios' and d.get('isSupported')]
wired = [d for d in ios if '(wireless)' not in (d.get('name') or '')]
pick = (wired or ios)
print(pick[0]['id'] if pick else '')
" 2>/dev/null || true)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo ""
  echo "No iOS device found. Plug in iPhone via USB, unlock it, trust this Mac, then:"
  echo "  ./scripts/run_ios_device.sh"
  echo "Or pass device id:"
  echo "  flutter devices"
  echo "  ./scripts/run_ios_device.sh <device-id>"
  exit 1
fi

echo ""
echo "==> Running on device: $DEVICE_ID"
echo "    (Use USB cable if wireless install hangs.)"
echo ""

exec flutter run \
  -d "$DEVICE_ID" \
  --device-timeout 180
