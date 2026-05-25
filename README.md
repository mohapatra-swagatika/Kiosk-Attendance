# Attendance Kiosk App

Enterprise attendance kiosk for mobile and tablet. Face recognition runs **fully on-device** — no backend server required for enrollment or kiosk check-in.

## Features

- On-device face detection (ML Kit) and recognition (MobileFaceNet TFLite, 192-dim embeddings)
- Face profiles stored locally (Hive)
- Kiosk mode with real-time matching and check-in / check-out
- Employee and attendance management on the device
- Works offline after the TFLite model is bundled

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install).
2. Download the face model:

   ```bash
   ./scripts/download_mobilefacenet.sh
   ```

3. Run the app:

   ```bash
   flutter pub get
   flutter run
   ```

See [assets/models/README.md](assets/models/README.md) for model requirements.

## Face enrollment

1. Sign in as an operator.
2. Open **Employees** → select an employee → **Configure face** → enroll (multi-pose + blink liveness).
3. Profiles are saved on this device only.

## Kiosk mode

From the home screen, open **Kiosk mode**. The app matches faces against enrolled profiles on the device. Unknown faces show **No Employee Found**.

## Architecture

- Flutter + Riverpod + go_router
- Clean Architecture (`lib/features/*`, `lib/core/*`)
- Local storage: Hive (`employees`, `face_profiles`, `attendance_logs`)
