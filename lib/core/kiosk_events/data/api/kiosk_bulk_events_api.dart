/// One event in the bulk kiosk upload request body.
class KioskBulkEventUpload {
  const KioskBulkEventUpload({
    required this.eventId,
    required this.payloadJson,
  });

  final String eventId;
  final Map<String, dynamic> payloadJson;
}

abstract class KioskBulkEventsApi {
  Future<void> postBulk({
    required String apiHost,
    required String deviceToken,
    required List<KioskBulkEventUpload> events,
  });
}
