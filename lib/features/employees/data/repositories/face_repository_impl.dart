import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/face_profile_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/face_repository.dart';

/// Face gallery stored on-device; kiosk matches against an in-memory cache.
class FaceRepositoryImpl implements FaceRepository {
  FaceRepositoryImpl(this._profiles, this._employees);

  final FaceProfileLocalDataSource _profiles;
  final EmployeeRepository _employees;

  Map<String, Map<String, dynamic>>? _galleryCache;
  bool _emptyGalleryMatchLogged = false;

  @override
  int get enrolledFaceCount => _galleryCache?.length ?? 0;

  @override
  void invalidateGalleryCache() {
    _galleryCache = null;
    _emptyGalleryMatchLogged = false;
  }

  @override
  Future<Either<Failure, int>> preloadGallery() async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      if (kDebugMode) {
        debugPrint('FaceRepository: gallery preloaded (${gallery.length} profiles)');
      }
      return Right(gallery.length);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadGallery({bool forceRefresh = false}) async {
    if (!forceRefresh && _galleryCache != null) {
      return _galleryCache!;
    }
    final raw = await _profiles.readGallery();
    // Drop stale-version profiles from in-memory gallery so matchProbe never
    // compares the new canonical-aligned probe against old bounding-box embeddings.
    // Users with stale profiles will see "Unknown face" and must re-enroll.
    final filtered = <String, Map<String, dynamic>>{};
    final skipped = <String>[];
    for (final entry in raw.entries) {
      final v = entry.value['v'];
      if (v == FaceEmbeddingCodec.storageVersionTflite) {
        filtered[entry.key] = entry.value;
      } else {
        skipped.add('${entry.key}(v$v)');
      }
    }
    if (skipped.isNotEmpty) {
      FaceMatchDebugLog.log(
        'Gallery: skipped stale profiles (re-enroll required) → '
        '${skipped.join(', ')}',
      );
    }
    _galleryCache = filtered;
    return filtered;
  }

  @override
  Future<Either<Failure, void>> registerFaceProfile({
    required String employeeId,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      if (gallery.containsKey(employeeId)) {
        return const Left(
          ValidationFailure(
            'This employee already has a face profile. Use Admin Reset on Employees to enroll again.',
          ),
        );
      }

      FaceMatchDebugLog.log('registerFaceProfile employeeId=$employeeId');
      FaceMatchDebugLog.log('Gallery keys: ${gallery.keys.join(', ')}');

      final validationError = _validateNeuralProfile(profile);
      if (validationError != null) {
        return Left(ValidationFailure(validationError));
      }

      final duplicate = FaceEmbeddingCodec.checkDuplicateProfile(
        newProfile: profile,
        gallery: gallery,
        registeringEmployeeId: employeeId,
      );
      if (duplicate.isDuplicate) {
        final other = duplicate.matchedEmployeeId ?? 'another employee';
        return Left(
          ValidationFailure(
            'This face is too similar to $other (${(duplicate.straightScore * 100).round()}% match). '
            'Use a unique face or reset the other profile first.',
          ),
        );
      }

      final updated = Map<String, Map<String, dynamic>>.from(gallery)
        ..[employeeId] = profile;
      await _profiles.writeGallery(updated);
      _galleryCache = updated;
      if (kDebugMode) {
        debugPrint('FaceRepository: registered $employeeId (on-device)');
      }
      return _markEmployeeFaceRegistered(employeeId, registered: true);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> resetFaceRegistration(String employeeId) async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      if (!gallery.containsKey(employeeId)) {
        return _markEmployeeFaceRegistered(employeeId, registered: false);
      }
      final updated = Map<String, Map<String, dynamic>>.from(gallery)..remove(employeeId);
      await _profiles.writeGallery(updated);
      _galleryCache = updated;
      return _markEmployeeFaceRegistered(employeeId, registered: false);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> hasRegisteredFace(String employeeId) async {
    try {
      final gallery = await _loadGallery();
      return Right(gallery.containsKey(employeeId));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, FaceMatchOutcome>> matchEmployee(
    List<double> probe, {
    String? lockedEmployeeId,
    double? probeYaw,
    double? probePitch,
  }) async {
    try {
      if (probe.length != FaceEmbeddingCodec.neuralEmbeddingDim) {
        return const Left(
          ValidationFailure(
            'Invalid probe embedding — MobileFaceNet model may not be loaded.',
          ),
        );
      }

      final gallery = _galleryCache ?? await _loadGallery();
      if (gallery.isEmpty) {
        if (!_emptyGalleryMatchLogged && kDebugMode) {
          _emptyGalleryMatchLogged = true;
          debugPrint(
            '[FaceMatch] No enrolled faces — kiosk matching skipped (register employees first).',
          );
        }
        return const Right(
          FaceMatchOutcome(
            rejected: true,
            reason: 'No registered faces',
          ),
        );
      }
      _emptyGalleryMatchLogged = false;
      return Right(_matchProbeLocal(
        probe,
        gallery,
        lockedEmployeeId: lockedEmployeeId,
        probeYaw: probeYaw,
        probePitch: probePitch,
      ));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  FaceMatchOutcome _matchProbeLocal(
    List<double> probe,
    Map<String, Map<String, dynamic>> gallery, {
    String? lockedEmployeeId,
    double? probeYaw,
    double? probePitch,
  }) {
    FaceMatchDebugLog.log(
      'KIOSK MATCH (local, n=${gallery.length}): '
      '${FaceMatchDebugLog.vectorPreview(probe)}',
    );
    final outcome = FaceEmbeddingCodec.matchProbe(
      probe: probe,
      gallery: gallery,
      lockedEmployeeId: lockedEmployeeId,
      probeYaw: probeYaw,
      probePitch: probePitch,
    );
    FaceMatchDebugLog.log(
      outcome.rejected
          ? 'RESULT: rejected — ${outcome.reason} (best=${outcome.bestScore.toStringAsFixed(4)})'
          : 'RESULT: matched ${outcome.employeeId} conf=${outcome.confidence.toStringAsFixed(4)}',
    );
    return outcome;
  }

  @override
  Future<Either<Failure, int>> importServerGallery(
    Map<String, Map<String, dynamic>> profiles,
  ) async {
    try {
      final valid = <String, Map<String, dynamic>>{};
      for (final entry in profiles.entries) {
        final error = _validateNeuralProfile(entry.value);
        if (error == null) {
          valid[entry.key] = entry.value;
        }
      }
      await _profiles.writeGallery(valid);
      _galleryCache = valid;
      await reconcileFaceRegistrationFlags();
      return Right(valid.length);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reconcileFaceRegistrationFlags() async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      final enrolledIds = gallery.keys.toSet();
      final employeesEither = await _employees.getEmployees();
      return employeesEither.fold(Left.new, (list) async {
        for (final e in list) {
          final hasEmbedding = enrolledIds.contains(e.id);
          if (e.faceRegistered != hasEmbedding) {
            final result = await _employees.saveEmployee(
              e.copyWith(faceRegistered: hasEmbedding),
            );
            if (result.isLeft()) return result;
          }
        }
        return const Right(null);
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  String? _validateNeuralProfile(Map<String, dynamic> profile) {
    final v = profile['v'];
    if (v != FaceEmbeddingCodec.storageVersionTflite) {
      return 'Profile uses an older alignment (v$v). Please re-enroll for accurate recognition.';
    }
    for (final pose in FaceProfilePoses.required) {
      final raw = profile[pose];
      if (raw is! List || raw.length != FaceEmbeddingCodec.neuralEmbeddingDim) {
        return 'Missing or invalid "$pose" embedding — re-enroll with all guided poses.';
      }
    }
    return null;
  }

  Future<Either<Failure, void>> _markEmployeeFaceRegistered(
    String employeeId, {
    required bool registered,
  }) async {
    final employeesEither = await _employees.getEmployees();
    return employeesEither.fold(Left.new, (list) async {
      final idx = list.indexWhere((e) => e.id == employeeId);
      if (idx < 0) return const Left(ValidationFailure('Employee not found'));
      return _employees.saveEmployee(list[idx].copyWith(faceRegistered: registered));
    });
  }
}
