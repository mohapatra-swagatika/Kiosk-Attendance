import 'package:equatable/equatable.dart';

/// Domain value object for kiosk operator sign-in.
class LoginCredentials extends Equatable {
  const LoginCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}
