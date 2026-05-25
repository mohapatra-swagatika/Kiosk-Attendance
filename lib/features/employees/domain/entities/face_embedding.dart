import 'package:equatable/equatable.dart';

/// Local face template derived from ML Kit landmarks (device-only matching).
class FaceEmbedding extends Equatable {
  const FaceEmbedding({
    required this.employeeId,
    required this.vector,
    required this.registeredAt,
  });

  final String employeeId;
  final List<double> vector;
  final DateTime registeredAt;

  @override
  List<Object?> get props => [employeeId, vector, registeredAt];
}
