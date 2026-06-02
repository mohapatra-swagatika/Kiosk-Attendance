import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
import 'package:attendance_kiosk_app/core/api/employee_snapshot_parser.dart';
import 'package:attendance_kiosk_app/core/api/face_profile_parser.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/domain/repositories/face_data_sync_repository.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/face_profile_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/face_repository.dart';

/// Face gallery stored on-device; kiosk matches against an in-memory cache.
class FaceRepositoryImpl implements FaceRepository {
  FaceRepositoryImpl(
    this._profiles,
    this._employees, {
    FaceDataSyncRepository? faceDataSync,
  }) : _faceDataSync = faceDataSync;

  final FaceProfileLocalDataSource _profiles;
  final EmployeeRepository _employees;
  final FaceDataSyncRepository? _faceDataSync;

  Map<String, Map<String, dynamic>>? _galleryCache;
  bool _emptyGalleryMatchLogged = false;

  @override
  int get enrolledFaceCount => _galleryCache?.length ?? 0;

  @override
  Map<String, Map<String, dynamic>> get gallerySnapshot =>
      Map<String, Map<String, dynamic>>.from(_galleryCache ?? const {});

  @override
  void invalidateGalleryCache() {
    _galleryCache = null;
    _emptyGalleryMatchLogged = false;
  }

  @override
  Future<Either<Failure, int>> preloadGallery() async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      FaceRecognitionTrace.galleryLoaded(
        count: gallery.length,
        employeeIds: gallery.keys.toList(),
      );
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
      var diskVerified = false;
      if (kDebugMode) {
        final readBack = await _profiles.readGallery();
        diskVerified = readBack.containsKey(employeeId);
      }
      FaceRecognitionTrace.profileSaved(
        employeeId: employeeId,
        profile: profile,
        diskVerified: diskVerified,
      );
      if (kDebugMode) {
        debugPrint('FaceRepository: registered $employeeId (on-device)');
      }

      final markResult = await _markEmployeeFaceRegistered(employeeId, registered: true);
      if (markResult.isLeft()) return markResult;

      final syncRepo = _faceDataSync;
      if (syncRepo != null) {
        final syncResult = await syncRepo.enqueueAndSync(
          employeeId: employeeId,
          faceDataJson: Map<String, dynamic>.from(profile),
        );
        syncResult.fold(
          (f) {
            if (kDebugMode) {
              debugPrint('[FaceDataSync] Queue failed: ${f.message}');
            }
          },
          (enqueued) {
            if (kDebugMode && enqueued) {
              debugPrint('[FaceDataSync] Enqueued upload for $employeeId');
            }
          },
        );
      }
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> resetFaceRegistration(String employeeId) async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      if (gallery.containsKey(employeeId)) {
        final updated = Map<String, Map<String, dynamic>>.from(gallery)
          ..remove(employeeId);
        await _profiles.writeGallery(updated);
        _galleryCache = updated;
      }

      final markResult =
          await _markEmployeeFaceRegistered(employeeId, registered: false);
      if (markResult.isLeft()) return markResult;

      final syncRepo = _faceDataSync;
      if (syncRepo != null) {
        final syncResult = await syncRepo.enqueueClearAndSync(
          employeeId: employeeId,
        );
        syncResult.fold(
          (f) {
            if (kDebugMode) {
              debugPrint('[FaceDataSync] Clear queue failed: ${f.message}');
            }
          },
          (enqueued) {
            if (kDebugMode) {
              debugPrint(
                enqueued
                    ? '[FaceDataSync] Enqueued server face clear for $employeeId'
                    : '[FaceDataSync] Server face clear already pending for $employeeId',
              );
            }
          },
        );
      }

      return const Right(null);
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
    FaceRecognitionTrace.similarityScores(
      probe: probe,
      gallery: gallery,
      force: outcome.rejected,
    );
    FaceRecognitionTrace.matchVerdict(
      accepted: !outcome.rejected && outcome.employeeId != null,
      employeeId: outcome.employeeId ?? outcome.bestEmployeeId ?? '?',
      bestScore: outcome.bestScore,
      margin: outcome.margin,
      reason: outcome.reason ?? (outcome.rejected ? 'rejected' : 'matched'),
    );
    return outcome;
  }

  @override
  Future<Either<Failure, int>> importServerGallery(
    Map<String, Map<String, dynamic>> serverProfiles, {
    Set<String>? rosterEmployeeIds,
  }) async {
    try {
      final existing = await _loadGallery(forceRefresh: true);
      final merged = Map<String, Map<String, dynamic>>.from(existing);

      var imported = 0;
      var skipped = 0;
      for (final entry in serverProfiles.entries) {
        final parsed = FaceProfileParser.parse(entry.value);
        if (parsed == null) {
          skipped++;
          if (kDebugMode) {
            debugPrint(
              '[FaceGallery] Skipped unparseable profile for ${entry.key}',
            );
          }
          continue;
        }
        if (_validateNeuralProfile(parsed) != null) {
          skipped++;
          continue;
        }
        merged[entry.key] = parsed;
        imported++;
      }
      if (kDebugMode && skipped > 0) {
        debugPrint('[FaceGallery] Skipped $skipped server profile(s)');
      }

      if (rosterEmployeeIds != null) {
        merged.removeWhere((id, _) => !rosterEmployeeIds.contains(id));
      }

      await _profiles.writeGallery(merged);
      _galleryCache = merged;
      if (kDebugMode) {
        debugPrint(
          'FaceRepository: gallery ${merged.length} profile(s) '
          '($imported from server)',
        );
      }
      await reconcileFaceRegistrationFlags();
      return Right(imported);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reconcileFaceRegistrationFlags() async {
    try {
      final gallery = await _loadGallery(forceRefresh: true);
      final employeesEither = await _employees.getEmployees();
      if (employeesEither.isLeft()) {
        return Left(employeesEither.getLeft().toNullable()!);
      }

      final list = employeesEither.getOrElse((_) => <Employee>[]);
      var changed = false;
      final updated = <Employee>[];

      for (final e in list) {
        final profile = _galleryProfileForEmployee(e, gallery);
        final hasEmbedding = profile != null;
        final hash = hasEmbedding ? FaceProfileParser.contentHash(profile) : null;
        if (e.faceRegistered != hasEmbedding || e.faceProfileHash != hash) {
          changed = true;
          updated.add(
            e.copyWith(
              faceRegistered: hasEmbedding,
              faceProfileHash: hash,
              clearFaceProfileHash: !hasEmbedding,
            ),
          );
        } else {
          updated.add(e);
        }
      }

      if (!changed) return const Right(null);

      // IMPORTANT: Avoid per-employee Hive read/write loops here.
      // Saving one-by-one makes first-load on large rosters feel frozen.
      return await _employees.replaceAll(updated);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Map<String, dynamic>? _galleryProfileForEmployee(
    Employee employee,
    Map<String, Map<String, dynamic>> gallery,
  ) {
    final fromParser =
        EmployeeSnapshotParser.profileForEmployee(employee, gallery);
    if (fromParser != null) return fromParser;
    return gallery[employee.id];
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
      final gallery = _galleryCache ?? await _loadGallery();
      final profile = registered ? gallery[employeeId] : null;
      final hash = profile != null
          ? FaceProfileParser.contentHash(profile)
          : null;
      return _employees.saveEmployee(
        list[idx].copyWith(
          faceRegistered: registered,
          faceProfileHash: hash,
          clearFaceProfileHash: !registered,
        ),
      );
    });
  }
}
