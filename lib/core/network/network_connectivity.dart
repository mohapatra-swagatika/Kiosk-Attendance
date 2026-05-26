import 'package:connectivity_plus/connectivity_plus.dart';

/// Observes device connectivity for offline queue sync.
class NetworkConnectivity {
  NetworkConnectivity({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return isOnline(results);
  }

  static bool isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
