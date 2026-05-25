import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';

abstract class FaceRepository {
  Future<Either<Failure, void>> registerFaceProfile({
    required String employeeId,
    required Map<String, dynamic> profile,
  });

  Future<Either<Failure, void>> resetFaceRegistration(String employeeId);

  Future<Either<Failure, bool>> hasRegisteredFace(String employeeId);

  Future<Either<Failure, FaceMatchOutcome>> matchEmployee(
    List<double> probe, {
    String? lockedEmployeeId,
    double? probeYaw,
    double? probePitch,
  });

  /// Loads enrolled face templates into memory for fast local matching.
  Future<Either<Failure, int>> preloadGallery();

  /// Count of on-device face profiles in the in-memory gallery (0 before preload).
  int get enrolledFaceCount;

  /// Clears the in-memory gallery (call after enroll / reset).
  void invalidateGalleryCache();

  /// Aligns `faceRegistered` flags with on-device face profiles.
  Future<Either<Failure, void>> reconcileFaceRegistrationFlags();

  /// Replaces on-device gallery with server snapshot profiles (v7 tflite only).
  Future<Either<Failure, int>> importServerGallery(
    Map<String, Map<String, dynamic>> profiles,
  );
}
