#!/usr/bin/env bash
# Downloads MobileFaceNet TFLite (112×112 input, 192-dim output) into assets/models/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/assets/models/mobile_face_net.tflite"
mkdir -p "$(dirname "$DEST")"

# Verified working mirrors (primary first). Old README URLs often 404.
URLS=(
  "https://raw.githubusercontent.com/MCarlomagno/FaceRecognitionAuth/master/assets/mobilefacenet.tflite"
  "https://github.com/MCarlomagno/FaceRecognitionAuth/raw/master/assets/mobilefacenet.tflite"
  "https://raw.githubusercontent.com/shubham0204/OnDevice-Face-Recognition-Android/main/app/src/main/assets/mobile_face_net.tflite"
)

MIN_BYTES=1000000

echo "Downloading MobileFaceNet to:"
echo "  $DEST"
echo ""

for url in "${URLS[@]}"; do
  echo "→ $url"
  if curl -fsSL --connect-timeout 30 --max-time 300 -o "$DEST" "$url"; then
    size=$(wc -c <"$DEST" | tr -d ' ')
    if [ "$size" -ge "$MIN_BYTES" ]; then
      echo ""
      echo "✓ Downloaded $(ls -lh "$DEST" | awk '{print $5}') ($size bytes)"
      echo ""
      echo "Next:"
      echo "  flutter clean && flutter pub get"
      echo "  flutter run"
      exit 0
    fi
    echo "  (file too small — skipping)"
  else
    echo "  (failed)"
  fi
  rm -f "$DEST"
done

echo ""
echo "All download URLs failed."
echo "Manual: save a MobileFaceNet .tflite (112×112 in, 192-d out) as:"
echo "  assets/models/mobile_face_net.tflite"
echo "Source repo: https://github.com/MCarlomagno/FaceRecognitionAuth"
exit 1
