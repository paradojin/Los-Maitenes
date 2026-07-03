import 'package:cloud_firestore/cloud_firestore.dart';
import 'keys.dart';

class BlacklistHit {
  final bool hit;
  final String reason;
  BlacklistHit({required this.hit, required this.reason});
}

class BlacklistService {
  final _db = FirebaseFirestore.instance;

  Future<void> addBlacklist({
    String? rutRaw,
    String? patenteRaw,
    required String reason,
    required String createdByUid,
  }) async {
    final rutKey = (rutRaw == null || rutRaw.trim().isEmpty) ? "" : normalizeRutKey(rutRaw);
    final plateKey = (patenteRaw == null || patenteRaw.trim().isEmpty) ? "" : normalizePlateKey(patenteRaw);

    await _db.collection("blacklist").add({
      "rutKey": rutKey,
      "patenteKey": plateKey,
      "reason": reason.trim(),
      "active": true,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "createdByUid": createdByUid,
    });
  }

  Future<void> setActive(String docId, bool active) async {
    await _db.collection("blacklist").doc(docId).update({
      "active": active,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<BlacklistHit> check({required String rutRaw, required String patenteRaw}) async {
    final rutKey = normalizeRutKey(rutRaw);
    final plateKey = normalizePlateKey(patenteRaw);

    // Buscar por RUT activo
    if (rutKey.isNotEmpty) {
      final q1 = await _db
          .collection("blacklist")
          .where("active", isEqualTo: true)
          .where("rutKey", isEqualTo: rutKey)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        final r = (q1.docs.first.data()["reason"] ?? "Sin motivo") as String;
        return BlacklistHit(hit: true, reason: r);
      }
    }

    // Buscar por PATENTE activa
    if (plateKey.isNotEmpty) {
      final q2 = await _db
          .collection("blacklist")
          .where("active", isEqualTo: true)
          .where("patenteKey", isEqualTo: plateKey)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final r = (q2.docs.first.data()["reason"] ?? "Sin motivo") as String;
        return BlacklistHit(hit: true, reason: r);
      }
    }

    return BlacklistHit(hit: false, reason: "");
  }
}