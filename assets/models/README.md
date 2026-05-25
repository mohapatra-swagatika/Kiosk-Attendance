# Face recognition model

Place a **MobileFaceNet** TFLite model in this folder named exactly:

```
mobile_face_net.tflite
```

## Automatic download (recommended)

```bash
chmod +x scripts/download_mobilefacenet.sh
./scripts/download_mobilefacenet.sh
```

This pulls a verified model from [MCarlomagno/FaceRecognitionAuth](https://github.com/MCarlomagno/FaceRecognitionAuth) (`assets/mobilefacenet.tflite`).

If the script fails (offline / firewall), download manually from:

https://raw.githubusercontent.com/MCarlomagno/FaceRecognitionAuth/master/assets/mobilefacenet.tflite

Rename to `mobile_face_net.tflite` and place in this folder.

## Required model specs

| Field            | Value                          |
|------------------|--------------------------------|
| Input shape      | `[1, 112, 112, 3]` (float32)   |
| Input range      | `[-1.0, 1.0]` (per channel)    |
| Output shape     | `[1, 192]` (float32)           |
| Output           | L2-normalized embedding vector |

The app loads it at startup via `Interpreter.fromAsset('assets/models/mobile_face_net.tflite')`.

If the file is missing or fails to load, **the app will not start** — ML Kit contours are not used for recognition.

## Verification

After download and a full rebuild:

```bash
flutter clean && flutter pub get
flutter run
```

Watch the debug console for:

```
Bootstrap: MobileFaceNet ready — 192-dim embeddings (v6, on-device)
[FaceEmbedder] MobileFaceNet loaded — input=[1, 112, 112, 3] output=[1, 192]
```

Kiosk match logs must show **(192d)**, not **(216d)**.

Face profiles are stored on the device (Hive). Re-enroll employees after switching to v6.

## License

Verify the license of the weights you ship. The MCarlomagno bundle is widely used for Flutter face-auth demos; confirm compliance before production release.
