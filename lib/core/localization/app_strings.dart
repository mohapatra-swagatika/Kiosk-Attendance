// Central source-of-truth for every user-facing string in the app.
//
// Organisation
// ────────────
// One file, grouped by feature. Every group is a `class` with `static const`
// fields (cheap, tree-shakable, compile-time inlined). Strings that need
// runtime data use `static String foo(arg) => '...';`.
//
// Future localisation
// ───────────────────
// When we add a second language, this file becomes the spec for a
// `flutter_localizations` / `gen_l10n` migration:
//
//   1. `flutter pub add flutter_localizations --sdk=flutter intl`
//   2. Configure `l10n.yaml` to point at `lib/l10n/app_en.arb`.
//   3. Copy keys from the classes below into `app_en.arb`, e.g.
//      `"loginTitle": "Sign in"`, `"loginUsernameLabel": "Username"`, …
//   4. Replace `AppStrings.loginTitle` with `AppLocalizations.of(context)!.loginTitle`
//      (or `context.l10n.loginTitle` with a small extension). Same shape — just
//      swap `AppStrings.` for `context.l10n.`.
//   5. Add `app_hi.arb`, `app_es.arb`, … with translated keys.
//
// Until that migration happens, every screen reads from these classes, so
// rewording any user-visible string is a one-file edit.

class AppStrings {
  AppStrings._();

  // Used both by `MaterialApp.title` and the kiosk shell AppBar.
  static const String appTitle = 'Attendance Kiosk';

  // Generic actions, used everywhere.
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String retry = 'Retry';
  static const String dismiss = 'Dismiss';
  static const String back = 'Back';
  static const String signOut = 'Sign out';
  static const String toggleTheme = 'Toggle theme';

  // Drawer destinations (shared between drawer + dashboard tiles).
  static const String menu = 'Menu';
  static const String home = 'Home';
  static const String employees = 'Employees';
  static const String attendance = 'Attendance';
  static const String kiosk = 'Kiosk mode';

  // Generic dashes / placeholders.
  static const String emDash = '—';
  static const String loadingEllipsis = '…';
}

// ───────────────────────────────────────────────────────────────────────────
// Auth / login
// ───────────────────────────────────────────────────────────────────────────

class LoginStrings {
  LoginStrings._();

  static const String heroTitle = 'Sign in';
  static const String heroBody =
      'Sign in with your operator credentials to manage employees, '
      'attendance records, and face-scan kiosk check-in on this device.';
  static const String chipTablet = 'Tablet layout';
  static const String chipOfflineFace = 'Offline face recognition';
  static const String chipLocalSession = 'Local session';

  static const String formTitle = 'Login';
  static const String formSubtitle = 'Username and password are required.';
  static const String domainLabel = 'Domain';
  static const String domainHint = 'Subdomain from device registration';
  static const String usernameLabel = 'Username';
  static const String usernameHint = 'Operator or kiosk user';
  static const String usernameRequired = 'Username is required';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Enter password';
  static const String passwordRequired = 'Password is required';
  static const String showPassword = 'Show password';
  static const String hidePassword = 'Hide password';
  static const String submit = 'Login';
  static const String submitting = 'Signing in…';

  static const String kioskSectionTitle = 'Kiosk mode';
  static const String kioskSectionSubtitle =
      'Fullscreen face scan for check-in/out. Sign in first, then start kiosk.';
  static const String startKioskMode = 'Start Kiosk Mode';
  static const String pinDevice = 'Pin device';
  static const String unpinDevice = 'Unpin';

  static const String kioskStarted =
      'Kiosk / screen pinning started. Use system back or Exit kiosk.';
  static const String kioskStartFailed =
      'Could not start kiosk mode (device policy or OS).';
  static const String kioskIosGuidedAccess =
      'iOS: enable Guided Access in Settings → Accessibility → Guided Access for kiosk-style use.';
  static const String kioskAndroidOnly =
      'Kiosk mode is only available on Android in this build.';
  static const String kioskExitAndroidOnly =
      'Exit kiosk is only wired on Android.';
  static const String kioskExited = 'Kiosk mode ended.';
  static const String kioskExitFailed = 'Could not exit kiosk mode.';
}

// ───────────────────────────────────────────────────────────────────────────
// Kiosk device registration (first-run setup)
// ───────────────────────────────────────────────────────────────────────────

class RegistrationStrings {
  RegistrationStrings._();

  static const String heroTitle = 'Device registration';
  static const String heroBody =
      'Enter your organization code, domain,machine name and description to register the device. ';
  static const String chipTablet = 'Tablet layout';
  static const String chipLocalSave = 'Local save';
  static const String chipEnterprise = 'Enterprise ready';

  static const String formTitle = 'Account details';
  static const String formSubtitle =
      'All fields are required to register the device.';

  static const String codeLabel = 'Code';
  static const String codeHint = 'Organization or site code';
  static const String codeRequired = 'Code is required';

  static const String domainLabel = 'Domain';
  static const String domainHint = 'e.g. company';
  static const String domainRequired = 'Domain is required';
  static const String domainSuffix = '.thinksys.com';

  static const String networkError =
      'Could not reach the server. Check the domain and try again.';
  static const String offlineSavedNote =
      'Device paired and saved on this device for offline use.';

  static const String machineLabel = 'Machine name';
  static const String machineHint = 'Label shown in admin consoles';
  static const String machineRequired = 'Machine name is required';

  static const String descriptionLabel = 'Description';
  static const String descriptionHint =
      'Location, floor, or purpose of this kiosk';
  static const String descriptionRequired = 'Description is required';

  static const String submit = 'Register';
  static const String submitting = 'Registering…';

  static const String adminPinDialogTitle = 'Save your admin PIN';
  static const String adminPinDialogBody =
      'Use this PIN on the kiosk to open the admin dashboard. It is stored on this device only.';
  static const String adminPinContinue = 'Continue to kiosk';
}

// ───────────────────────────────────────────────────────────────────────────
// Home dashboard
// ───────────────────────────────────────────────────────────────────────────

class HomeStrings {
  HomeStrings._();

  static const String eyebrow = 'Analytics';
  static const String title = 'Dashboard';
  static const String subtitle =
      'Today’s attendance reporting — rates, punctuality, and roster coverage from kiosk check-ins.';

  static const String summaryTitle = 'Today at a glance';
  static String summarySubtitle(int present, int total) =>
      '$present of $total employees checked in via kiosk';

  static const String attendanceRateTitle = 'Attendance rate';
  static String attendanceRateDetail(int present, int total) =>
      '$present present · $total in roster';

  static const String lateRateTitle = 'Late check-in rate';
  static String lateRateDetail(int late, int present) =>
      '$late late arrivals · $present checked in today';

  static const String presentVsAbsentTitle = 'Present vs absent';
  static const String presentLegend = 'Present';
  static const String absentLegend = 'Absent';

  static const String performanceTitle = 'Overall attendance performance';
  static const String performanceSubtitle =
      'Composite score based on today’s attendance and on-time check-ins (shift start 9:00 AM).';

  static const String statPresent = 'Present today';
  static const String statLate = 'Late check-ins';
  static const String statRoster = 'Roster size';

  static const String analyticsLoading = 'Loading analytics…';
  static const String analyticsError = 'Could not load attendance analytics';
}

// ───────────────────────────────────────────────────────────────────────────
// Employees roster
// ───────────────────────────────────────────────────────────────────────────

class EmployeesStrings {
  EmployeesStrings._();

  static const String title = 'Employees';
  static const String subtitle =
      'View your team roster, manage face enrollment, and keep each employee ready for kiosk check-in.';
  static const String empty = 'No employees yet.';
  static const String syncEmployees = 'Employee sync';
  static String syncedCount(int n) => 'Synced $n employees from server';
}

class EmployeeCardStrings {
  EmployeeCardStrings._();

  static String idTag(String id) => 'ID $id';
  static const String faceRegistered = 'Face registered';
  static const String faceNotConfigured = 'Face not configured';
  static const String viewDetailsButton = 'View details';
}

class EmployeeDetailsStrings {
  EmployeeDetailsStrings._();

  static const String title = 'Employee details';
  static const String notFound = 'Employee not found.';
  static const String faceConfigButton = 'Face configuration';
  static const String pinConfigButton = 'PIN configuration';
  static const String attendanceSectionTitle = 'Attendance history';
  static const String attendanceSectionSubtitle = 'Filter by date';
  static String noRecordsForDate(String dateLabel) => 'No attendance on $dateLabel.';

  static const String profileSectionTitle = 'Profile';
  static const String labelEmployeeCode = 'Employee code';
  static const String labelEmail = 'Email';
  static const String labelPhone = 'Phone';
  static const String labelDesignation = 'Designation';
  static const String labelDepartment = 'Department';
  static const String labelPin = 'Kiosk PIN';
  static const String labelFace = 'Face enrollment';
  static const String labelStatus = 'Status';
  static const String labelLocation = 'Location';
  static const String labelReportingManager = 'Reporting manager';
  static const String labelTodayShift = "Today's shift";
  static String todayShiftValue(String name, String code) =>
      code.isNotEmpty ? '$name ($code)' : name;
}

class EmployeePinStrings {
  EmployeePinStrings._();

  static const String sheetTitle = 'Employee PIN';
  static String subtitle({required String name, required String id}) =>
      '$name · $id';
  static const String hint = 'Use this PIN at the kiosk if face scan is unavailable.';
  static const String noPin = '—';
  static const String copied = 'PIN copied';
  static const String copyButton = 'Copy PIN';
}

class FaceConfigStrings {
  FaceConfigStrings._();

  static const String title = 'Face registration';
  static String subtitle({required String name, required String id}) =>
      '$name · $id';

  static const String alreadyRegistered =
      'A face profile is stored for this employee on this device. '
      'Reset only if you need to re-enroll.';
  static const String startInstructions =
      "Set up Face ID: center your face in the circle and move your head gently. It only takes a few seconds.";
  static const String startButton = 'Start face registration';
  static const String resetButton = 'Admin reset (this employee only)';
  static const String resetSnackbar =
      'Face registration reset for this employee.';
}

// ───────────────────────────────────────────────────────────────────────────
// Guided face enrollment
// ───────────────────────────────────────────────────────────────────────────

class FaceRegistrationStrings {
  FaceRegistrationStrings._();

  static const String pageTitleFallback = 'Face ID';
  static const String preparingCamera = 'Preparing camera…';

  static const String alreadyEnrolledTitle = 'Already enrolled';
  static String alreadyEnrolledBody(String employeeId) =>
      'This employee ($employeeId) already has a face on this device.';
  static const String alreadyEnrolledHint =
      'Admin reset on Employees to re-register.';

  static const String cameraRequiredTitle = 'Camera required';
  static const String cameraRequiredBody = 'Allow camera access in Settings.';

  static const String saving = 'Saving Face ID…';
  static const String saveFailed = 'Could not save Face ID. Try again.';
  static const String saveFailedHint =
      'Tap "View match details" for scores (also in debug console).';
  static String savedSnackbar(String employeeId) =>
      'Face ID set up for $employeeId';

  static const String debugDialogTitle = 'Face match debug';
  static const String unavailable = 'Unavailable';

  // Apple-style copy — kept simple, no forced poses.
  static const String faceIdTitle = 'Set Up Face ID';
  static const String faceIdSetupSubtitle =
      'Center your face in the circle and move your head gently. We will do the rest.';
  static const String faceIdPositionFace = 'Center your face in the circle';
  static const String faceIdFaceDetected = 'Looks great — keep going';
  static const String faceIdCompleteCircle = 'Move your head slowly in a small circle';
  static const String faceIdAlmostDone = 'Almost done';
  static const String faceIdBlink = 'Blink once';
  static const String faceIdComplete = 'Face ID is set up';
  static const String faceIdHoldStill = 'Hold still';
  static const String faceIdMoveCloser = 'Move a little closer';
  static const String faceIdMoveFarther = 'Move a little farther away';
  static const String faceIdSingleFace = 'Only one person at a time';
  static const String faceIdReady = 'Face ID is ready';
  static const String faceIdSlowScanHint =
      'Move your head gently — left, right, up, down';
  static const String faceIdTurnLeft = 'Slight turn to the left';
  static const String faceIdTurnRight = 'Slight turn to the right';
  static const String faceIdTiltUp = 'A small look up';
  static const String faceIdTiltDown = 'A small look down';
  static const String faceIdHoldStillForScan = 'Hold steady';
  static const String faceIdCapturingSample = 'Capturing…';
  static const String faceIdMoreAnglesNeeded =
      'Keep moving — almost there';
  static const String faceIdOpenEyes = 'Open your eyes';
}

class FaceIdStrings {
  FaceIdStrings._();

  static const String title = 'Face ID';
  static const String kioskScanning = 'Look at the kiosk';
  static const String kioskReady = 'Look at the kiosk to check in';
  static const String kioskAlign = 'Center your face in the circle';
  static const String kioskRecognizing = 'Recognizing…';
  static const String verified = 'Face recognized';
  static const String welcomeBack = 'Welcome back';
}

// ───────────────────────────────────────────────────────────────────────────
// Kiosk fullscreen mode
// ───────────────────────────────────────────────────────────────────────────

class KioskStrings {
  KioskStrings._();

  static const String scanning = 'Align your face — scanning…';
  static const String scanningShort = 'Scanning…';
  static const String holdStill = 'Hold still — verifying…';
  static const String verified = 'Face verified';
  static const String cameraPermissionRequired = 'Camera permission required';
  static const String faceNotRecognized = 'Face not recognized';
  static const String unknownFace = 'No Employee Found';
  static const String tryAgain = 'Please try again';

  static const String noEmployeeFoundTitle = 'No Employee Found';
  static const String noEmployeeFoundHint =
      'If you are a registered employee, ask an administrator to enroll your face.';
}

class MatchDialogStrings {
  MatchDialogStrings._();

  static String employeeId(String id) => 'Employee ID: $id';
  static String department(String dept) => 'Department: $dept';
  static String date(String date) => 'Date: $date';
  static String time(String time) => 'Time: $time';
  static String confidence(int pct) => 'Match confidence: $pct%';

  static const String statusCheckedIn = 'Status: Checked in';
  static const String statusNotCheckedIn = 'Status: Not checked in today';

  static const String checkIn = 'Check-In';
  static const String checkOut = 'Check-Out';
  static const String dismiss = 'Dismiss';
  static const String checkInRecorded = 'Check-in recorded';
  static const String checkOutRecorded = 'Check-out recorded';
}

// ───────────────────────────────────────────────────────────────────────────
// Attendance (workspace + admin)
// ───────────────────────────────────────────────────────────────────────────

class AttendanceStrings {
  AttendanceStrings._();

  static const String title = 'Attendance';
  static String pipelineBlurb(int faceCount) =>
      'Real-time face detection (Google ML Kit) using the front camera. '
      'Faces detected: $faceCount';
  static String faceCount(int n) => n == 1 ? '$n face' : '$n faces';

  static const String pillLive = 'Live';
  static const String pillPaused = 'Paused';

  static const String queueTitle = 'Queue';
  static const String queueSubtitle =
      'Stack cards for the next guest, verification, and completion states.';
  static const String queueNext = 'Next in queue';
  static const String queueNextStatus = 'Ready';
  static const String queueVerifying = 'Verifying…';
  static const String queueVerifyingStatus = 'Hold still';
  static const String queueCompleted = 'Completed';
  static const String queueCompletedStatus = 'Checked-in';

  static const String errAndroidIosOnly =
      'Live face detection needs Android or iOS (camera + ML Kit).';
  static const String errCameraPermission =
      'Camera permission is required for attendance scanning.';
  static const String errNoCameras = 'No cameras found on this device.';
  static String errCameraGeneric(Object e) => 'Camera error: $e';
}

class AttendanceAdminStrings {
  AttendanceAdminStrings._();

  static const String title = 'Attendance';
  static const String subtitle =
      'Logs, active check-ins, and kiosk face scanning.';
  static const String startKiosk = 'Start Kiosk Mode';

  static const String metricTotalLogs = 'Total logs';
  static const String metricDayLogs = 'Records this day';
  static const String metricActiveNow = 'Active now';
  static const String metricToday = 'Today';
  static const String metricSelectedDay = 'Selected day';
  static const String filterAllEmployees = 'All employees — pick a date to filter';
  static String historyForDate(String date) => 'Logs for $date';
  static String noRecordsForDate(String date) => 'No attendance records for $date';

  static const String activeSectionTitle = 'Active employees';
  static const String activeSectionSubtitle =
      'Checked in today without check-out';
  static const String activeEmpty = 'No active check-ins';

  static const String historyTitle = 'Attendance history';
  static const String historyEmpty =
      'No attendance logs yet. Use Kiosk Mode to check in.';

  static String checkInLine(String time) => 'In: $time';
  static String checkOutLine(String time) => 'Out: $time';
}

class AttendanceDetailStrings {
  AttendanceDetailStrings._();

  static const String statusCheckedIn = 'Checked in';
  static const String statusCheckedOut = 'Checked out';
  static String checkInAt(String time) => 'Check-in at $time';
  static String sessionTimeRange(String checkIn, String checkOut) =>
      '$checkIn – $checkOut';
  static String durationHoursMinutes(int hours, int minutes) =>
      'Duration: ${hours}h ${minutes}m';
  static String durationMinutes(int minutes) => 'Duration: ${minutes}m';
}

// ───────────────────────────────────────────────────────────────────────────
// Shell / drawer / error view
// ───────────────────────────────────────────────────────────────────────────

class DrawerStrings {
  DrawerStrings._();

  static const String footer =
      'Kiosk mode ready — extend with platform channels.';
  static const String adminRole = 'Administrator';
  static const String employeeRole = 'Employee';
}

class KioskSidebarStrings {
  KioskSidebarStrings._();

  static const String faceScan = 'Face attendance';
  static const String pinAttendance = 'PIN attendance';
  static const String loginWithPin = 'Login using PIN';
  static const String settings = 'Settings';
  static const String lastSync = 'Last sync';
  static const String neverSynced = 'Not synced yet';
  static const String syncNow = 'Sync now';
  static String pendingCount(int n) => '$n pending upload(s)';
  static String syncedCount(int n) => 'Synced $n item(s) to server';
}

class KioskPinStrings {
  KioskPinStrings._();

  static const String title = 'Enter your PIN';
  static const String submit = 'Continue';
  static const String backToScan = 'Back to face scan';
  static const String pinTooShort = 'Enter at least 4 digits';
  static const String pinAttendanceHint = 'Enter your employee PIN to check in or out';
  static const String markAttendance = 'Mark attendance';
  static const String adminUseLogin = 'Administrator PIN — use Login using PIN instead';
  static const String employeeNotFound = 'Invalid PIN — employee not found';
}

class KioskSettingsStrings {
  KioskSettingsStrings._();

  static const String offlineNote =
      'Attendance is saved on this device first, then uploaded when you tap Sync.';
  static const String noConfig = 'Device is not registered yet.';
  static const String domainLabel = 'Domain';
  static const String machineLabel = 'Machine';
  static const String codeLabel = 'Code';
  static const String adminLabel = 'Admin';
  static const String emailLabel = 'Email';
  static const String attendanceModeTitle = 'Attendance mode';
  static const String attendanceModeSubtitle =
      'Choose how employees mark attendance at this kiosk.';
  static const String faceMode = 'Face attendance';
  static const String pinMode = 'PIN attendance';
  static const String modeSaved = 'Attendance mode updated';
  static const String deviceInfoTitle = 'Device information';
  static const String appearanceTitle = 'Appearance';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String themeSystem = 'System';
}

class EmployeePortalStrings {
  EmployeePortalStrings._();

  static const String dashboardTab = 'Dashboard';
  static const String attendanceTab = 'Attendance';
  static const String dashboardSubtitle =
      'Your details and today\'s attendance at a glance.';
  static const String detailsTitle = 'Employee details';
  static const String departmentLabel = 'Department';
  static const String faceLabel = 'Face ID';
  static const String todayAttendance = 'Today';
  static const String statusCheckedIn = 'You are checked in today';
  static const String statusNotCheckedIn = 'Not checked in today';
  static const String offlineHint =
      'Records are stored locally and added to the sync queue.';
  static const String sessionMissing = 'Session expired — log in again from the kiosk.';
  static const String filterByDate = 'Filter by date';
  static const String previousDay = 'Previous day';
  static const String nextDay = 'Next day';
  static String noRecordsForDate(String date) => 'No attendance records for $date';
  static const String captureTitleCheckIn = 'Check-in selfie';
  static const String captureTitleCheckOut = 'Check-out selfie';
  static const String captureHint = 'Position your face in the frame and tap capture';
  static const String captureButton = 'Capture & confirm';
  static const String captureLoading = 'Opening camera…';
  static const String captureSaving = 'Saving attendance…';
  static const String captureFailed = 'Could not save photo. Try again.';
  static const String cameraPermissionRequired =
      'Camera permission is required for attendance photos.';
}
