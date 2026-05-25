# Flutter Attendance Kiosk App — Requirements

## Project Overview

Enterprise attendance kiosk for **Android / iPhone / tablets / iPad** using:

- Clean Architecture (feature-first)
- Riverpod, GoRouter, repository pattern
- Hive local storage
- Google ML Kit + camera
- Material 3, glassmorphism, light/dark mode

---

## Theme

Primary brand color:

```dart
Color(0xFF1C6ADC)
```

Requirements:

- Premium enterprise UI
- Material 3
- Modern tablet dashboard
- Gradients using primary color
- Dark / light mode (system toggle in shell)
- Smooth page transitions
- Glassmorphism where appropriate

---

## 1. Registration Screen

Fields: **Code**, **Domain**, **Machine name**, **Description** → **Register** → save locally → **Login**.

---

## 2. Login Screen

- **Username**, **Password**, **Login**
- Dummy auth until APIs exist
- Below login: **Start Kiosk Mode** (sign in, then fullscreen face kiosk)
- Optional **Pin device** / **Unpin** (Android Lock Task via platform channel)

---

## 3. Home Dashboard

Responsive hub with metrics, glass nav tiles: **Employees**, **Attendance**, **Kiosk mode**.

---

## 4. Employees

Each card: image, name, department, face status, **Face Config**.

### Face Config flow

1. Open camera preview  
2. ML Kit — **single face only**  
3. Validate visibility, angle, lighting, size  
4. Capture → store **face embedding** locally (landmark vector)  
5. Mark **Face Registered**  
6. **One-time** registration; block duplicate; **admin reset** to re-register  

Route: `/employees/:id/face-register`

---

## 5. Attendance (admin)

- Attendance logs (Hive JSON)
- Check-in / check-out times
- Active employees today
- Status cards
- **Start Kiosk Mode** button

### Attendance log (local)

```json
{
  "employeeId": "",
  "employeeName": "",
  "checkInTime": "",
  "checkOutTime": "",
  "date": "",
  "deviceId": "",
  "status": ""
}
```

Rules:

- No duplicate check-in without check-out
- Check-out updates same log

---

## 6. Face registration (multi-step liveness)

Route: `/employees/:id/face-register`

Guided enrollment before an employee is marked `faceRegistered`:

1. Look straight  
2. Turn head left  
3. Turn head right  
4. Blink eyes  

Validations (ML Kit **accurate** mode: landmarks, contours, classification, tracking):

- Single face only  
- Face visibility % (bounding box vs frame)  
- Head yaw per step (real left/right rotation, not body movement)  
- Eye blink via `leftEyeOpenProbability` / `rightEyeOpenProbability`  
- Stable frames per pose (anti-blur / alignment)  
- Per-frame dynamic embedding (no static / mock vectors accepted)  

### Embedding pipeline

Two backends, selected at startup based on whether `assets/models/mobile_face_net.tflite`
is present:

#### Primary — MobileFaceNet TFLite (v6)

1. ML Kit detects single face + landmarks + contours per frame (used for liveness, pose, eye checks).
2. At capture time, the live camera frame is converted to RGB, rotated by the camera
   sensor orientation, mirrored for the front lens, aligned by eye landmarks, cropped to
   the face bounding box (expanded 35 %), and resized to **112 × 112**.
3. Pixels normalized to `[-1, 1]` → TFLite `Interpreter.run` → **192-dim** embedding.
4. L2 normalize → cosine similarity for matching.
5. Cosine threshold **≥ 0.65**, margin over second-best **≥ 0.05**.

#### Fallback — ML Kit contour geometry (v5)

If the TFLite model is missing or fails to load, the app falls back to a Procrustes-aligned
contour embedding:

1. Sample ~108 contour points (jaw, eyebrows, eyes, lips, nose).
2. Align: origin = eye midpoint, x-axis along eye line, scale = inter-eye distance.
3. Flatten (x, y) → **216-dim** identity vector → L2 normalize.
4. Cosine threshold **≥ 0.94**, margin **≥ 0.025**.

> The fallback geometry vector is less discriminative than a learned model; cross-person
> duplicate blocking is logged for diagnostics only and never blocks registration.

#### Stored profile (Hive `face_embeddings`)

```json
{
  "v": 6,                    // 6 = tflite, 5 = contour fallback
  "straight":  [N floats],   // N = 192 (v6) or 216 (v5)
  "left":      [N floats],
  "right":     [N floats],
  "combined":  [N floats],
  "yawStraight": 1.9,
  "yawLeft":    -29.7,
  "yawRight":   31.6
}
```

Profiles whose `v` does not match the active mode are auto-purged at startup —
affected employees must re-enroll. Switching modes (e.g. dropping in a new model)
therefore requires a one-time re-enrollment.

Registration completes only after all 4 steps pass (straight → left → right → blink).

---

## 7. Kiosk mode

Route: `/kiosk` (fullscreen, immersive)

- Continuous front camera (stream never stops)
- Strict match (active mode determines thresholds):
  - **tflite (v6)**: cosine ≥ 0.65, margin ≥ 0.05
  - **contour (v5)**: cosine ≥ 0.94, margin ≥ 0.025
- Match only stored embeddings of the active mode; reject unknown / ambiguous / partial faces
- Straight pose + eyes open required at scan time
- On match → **one** modal: photo, name, ID, department, date/time, confidence
- **Check-In** / **Check-Out** → save attendance → close → resume scan
- **No repeated popups**: scan paused while dialog open; **12s cooldown** per employee after dismiss

---

## Local storage (Hive)

| Key | Data |
|-----|------|
| `kiosk_config` | Registration |
| `session` | Login session |
| `employees` | Roster |
| `face_embeddings` | Per-employee multi-pose embeddings (v6 tflite / v5 contour fallback) |
| `attendance_logs` | Attendance records |
| `device_id` | Kiosk device UUID |

---

## ML Kit packages

```yaml
google_mlkit_face_detection:
google_mlkit_commons:
camera:
permission_handler:
tflite_flutter:   # MobileFaceNet inference
image:            # YUV/BGRA → RGB, crop, resize for the model
```

### Model file

Drop a MobileFaceNet TFLite model at `assets/models/mobile_face_net.tflite`
(input `[1,112,112,3]`, output `[1,192]`, range `[-1,1]`). See
`assets/models/README.md` for download sources and verification steps.

---

## iOS

- Minimum deployment **15.5+** (ML Kit)
- Open **`Runner.xcworkspace`** (not `.xcodeproj`)
- Run `pod install` after dependency changes
