/// Thrown by [HttpRegistrationApi] for transport / parse failures.
class RegistrationApiException implements Exception {
  const RegistrationApiException(this.message, {this.isNetworkError = false});

  final String message;
  final bool isNetworkError;

  @override
  String toString() => message;
}
