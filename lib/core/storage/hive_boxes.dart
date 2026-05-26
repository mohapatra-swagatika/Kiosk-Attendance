/// Centralized Hive box and key names.
abstract final class HiveBoxes {
  static const String app = 'app_box';
}

abstract final class HiveKeys {
  static const String kioskConfig = 'kiosk_config';
  static const String session = 'session';
  static const String employees = 'employees';
  static const String attendanceLogs = 'attendance_logs';
  static const String deviceId = 'device_id';
  static const String faceProfiles = 'face_profiles';
  static const String syncQueue = 'sync_queue';
  static const String syncMetadata = 'sync_metadata';
  static const String kioskEventsQueue = 'kiosk_events_queue';
  static const String faceDataSyncQueue = 'face_data_sync_queue';
  static const String faceDataSyncMetadata = 'face_data_sync_metadata';
  static const String employeeSyncMetadata = 'employee_sync_metadata';
}
