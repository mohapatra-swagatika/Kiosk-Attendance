import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';

/// Fuses recent kiosk probes on Android when they agree (reduces frame-to-frame noise).
abstract final class AndroidKioskProbeFusion {
  AndroidKioskProbeFusion._();

  static const int maxRing = 3;
  static const double minPairwiseSimilarity = 0.68;

  static List<double> combine(List<List<double>> ring, List<double> latest) {
    if (ring.isEmpty) return latest;
    final pool = [...ring, latest];
    if (pool.length < 2) return latest;

    var minPair = 1.0;
    for (var i = 0; i < pool.length; i++) {
      for (var j = i + 1; j < pool.length; j++) {
        if (pool[i].length != pool[j].length) continue;
        final s = FaceEmbeddingCodec.cosineSimilarity(pool[i], pool[j]);
        if (s < minPair) minPair = s;
      }
    }
    if (minPair < minPairwiseSimilarity) return latest;
    return FaceEmbeddingCodec.fuseProbeEmbeddings(pool) ?? latest;
  }
}
