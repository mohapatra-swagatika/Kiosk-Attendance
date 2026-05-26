/// Server `eventType` values for bulk kiosk events.
abstract final class KioskEventTypes {
  static const checkIn = 'checkin';
  static const checkOut = 'checkOut';
}

/// How attendance was authenticated at the kiosk.
abstract final class KioskAuthMethods {
  static const face = 'face';
  static const pin = 'pin';
}
