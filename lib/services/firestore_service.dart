import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pricing.dart';
import 'billing.dart';
import 'keys.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  int _pickInt(Map<String, dynamic> m, List<String> keys, int fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return fallback;
  }

  // --- Helpers de cobro sobre el documento del grupo -----------------------

  DateTime _arrivalOf(Map<String, dynamic> m, DateTime fallback) {
    final ar = m["arrivalAt"];
    if (ar is Timestamp) return ar.toDate();
    return fallback;
  }

  /// Monto incurrido hasta [now] según el estado actual del grupo.
  int _incurred(Map<String, dynamic> m, DateTime now) {
    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    return amountIncurredNow(
      stayType: (m['stayType'] ?? 'DAY') as String,
      arrival: _arrivalOf(m, now),
      now: now,
      adults: _pickInt(personas, ["adultos", "adults"], 0),
      children: _pickInt(personas, ["ninos", "kids", "children"], 0),
      adultDay: _pickInt(rates, ["adultDay", "adult_day"], 7000),
      childDay: _pickInt(rates, ["childDay", "child_day"], 5000),
      adultCamping: _pickInt(rates, ["adultCamping", "adult_camping"], 8000),
      childCamping: _pickInt(rates, ["childCamping", "child_camping"], 6000),
      extraCharges: _pickInt(m, ["extraCharges"], 0),
    );
  }

  /// Total planificado según el estado actual del grupo.
  int _expectedTotal(Map<String, dynamic> m, {String? stayType, int? nights}) {
    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    return expectedTotalForStay(
      stayType: stayType ?? (m['stayType'] ?? 'DAY') as String,
      nights: nights ?? _pickInt(m, ["expectedDays"], 1),
      adults: _pickInt(personas, ["adultos", "adults"], 0),
      children: _pickInt(personas, ["ninos", "kids", "children"], 0),
      adultDay: _pickInt(rates, ["adultDay", "adult_day"], 7000),
      childDay: _pickInt(rates, ["childDay", "child_day"], 5000),
      adultCamping: _pickInt(rates, ["adultCamping", "adult_camping"], 8000),
      childCamping: _pickInt(rates, ["childCamping", "child_camping"], 6000),
      extraCharges: _pickInt(m, ["extraCharges"], 0),
    );
  }

  String _statusFor(Map<String, dynamic> m, DateTime now, int totalPaid) =>
      totalPaid >= _incurred(m, now) ? "ACTIVE" : "PENDING";

  // -------------------------------------------------------------------------

  Future<String> createGroup({
    required String responsableNombre,
    required String responsableRut,
    required String responsableCelular,
    required String ingresadoPor,
    required String patente,
    required int adultos,
    required int ninos,
    required String stayType, // "DAY" | "CAMPING"
    required int expectedDays, // noches (1 para DAY)
    required Pricing pricing,
  }) async {
    final now = DateTime.now();
    final rutKey = normalizeRutKey(responsableRut);
    final plateKey = normalizePlateKey(patente);

    final nights = (stayType == "DAY") ? 1 : (expectedDays < 1 ? 1 : expectedDays);

    final totalExpected = expectedTotalForStay(
      stayType: stayType,
      nights: nights,
      adults: adultos,
      children: ninos,
      adultDay: pricing.adultDay,
      childDay: pricing.childDay,
      adultCamping: pricing.adultCamping,
      childCamping: pricing.childCamping,
    );

    // Estado inicial: sin pagos, ya se debe la primera unidad (día o 1ª noche).
    final dueNow = amountIncurredNow(
      stayType: stayType,
      arrival: now,
      now: now,
      adults: adultos,
      children: ninos,
      adultDay: pricing.adultDay,
      childDay: pricing.childDay,
      adultCamping: pricing.adultCamping,
      childCamping: pricing.childCamping,
    );
    final initialCheck = 0 >= dueNow ? "ACTIVE" : "PENDING";

    final groupRef = _db.collection('groups').doc();
    final eventRef = _db.collection('access_events').doc();

    // Nombre del staff que registra (viene del login).
    final currentUser = FirebaseAuth.instance.currentUser;
    final staff = ingresadoPor.trim().isNotEmpty
        ? ingresadoPor.trim()
        : (currentUser?.displayName ?? currentUser?.email ?? 'Sistema');

    await _db.runTransaction((tx) async {
      tx.set(groupRef, {
        "responsableNombre": responsableNombre,
        "responsableRut": responsableRut,
        "rutKey": rutKey,
        "responsableCelular": responsableCelular,
        "patente": patente,
        "patenteKey": plateKey,
        "personas": {"adultos": adultos, "ninos": ninos},
        "arrivalAt": FieldValue.serverTimestamp(),
        "status": "IN",
        "stayType": stayType,
        "expectedDays": nights, // = noches
        "extraCharges": 0,
        "ratesSnapshot": pricing.toMap(),
        "totalExpected": totalExpected,
        "totalPaid": 0,
        "checkInStatus": initialCheck,
        "ingresadoPor": staff,
        "createdByUid": _uid,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      tx.set(eventRef, {
        "groupId": groupRef.id,
        "type": "INGRESO",
        "timestamp": FieldValue.serverTimestamp(),
        "createdByUid": _uid,
        "rutKey": rutKey,
        "patenteKey": plateKey,
      });
    });

    return groupRef.id;
  }

  Future<void> registerPayment({
    required String groupId,
    required int amount,
    required String method,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final paymentRef = _db.collection('payments').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) throw Exception("Grupo no existe");

      final m = snap.data() as Map<String, dynamic>;
      final now = DateTime.now();

      final newTotalPaid = _pickInt(m, ["totalPaid"], 0) + amount;
      final newCheck = _statusFor(m, now, newTotalPaid);

      tx.update(groupRef, {
        "totalPaid": newTotalPaid,
        "checkInStatus": newCheck,
        "lastPaymentAmount": amount,
        "lastPaymentMethod": method,
        "lastPaymentAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      tx.set(paymentRef, {
        "groupId": groupId,
        "amount": amount,
        "method": method,
        "stayType": (m['stayType'] ?? 'DAY') as String,
        "createdAt": FieldValue.serverTimestamp(),
        "createdByUid": _uid,
      });
    });
  }

  Future<void> syncGroupStatusesForToday() async {
    final now = DateTime.now();
    final qs = await _db.collection("groups").where("status", isEqualTo: "IN").get();

    final batch = _db.batch();
    int changes = 0;
    for (final doc in qs.docs) {
      final m = doc.data();
      final shouldBe = _statusFor(m, now, _pickInt(m, ["totalPaid"], 0));
      final current = (m["checkInStatus"] ?? "PENDING") as String;
      if (current != shouldBe) {
        batch.update(doc.reference, {
          "checkInStatus": shouldBe,
          "updatedAt": FieldValue.serverTimestamp(),
        });
        changes++;
      }
    }
    if (changes > 0) await batch.commit();
  }

  /// Editar la cantidad de personas de un grupo en estadía (recalcula total).
  Future<void> updateGroupPeople({
    required String groupId,
    required int adultos,
    required int ninos,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) throw Exception("Grupo no existe");
      final m = snap.data() as Map<String, dynamic>;
      if ((m["status"] ?? "IN") != "IN") {
        throw Exception("Grupo no está en estadía");
      }
      final now = DateTime.now();
      // Reemplazar personas y recalcular sobre el mapa actualizado.
      final updated = Map<String, dynamic>.from(m);
      updated["personas"] = {"adultos": adultos, "ninos": ninos};

      final totalPaid = _pickInt(m, ["totalPaid"], 0);
      tx.update(groupRef, {
        "personas": {"adultos": adultos, "ninos": ninos},
        "totalExpected": _expectedTotal(updated),
        "checkInStatus": _statusFor(updated, now, totalPaid),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  /// Pasar un pase de día a acampada. La noche se SUMA al día ya usado
  /// (se guarda ese día como cargo extra).
  Future<void> convertDayToCamping({
    required String groupId,
    required int expectedDays, // noches estimadas
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) throw Exception("Grupo no existe");
      final m = snap.data() as Map<String, dynamic>;
      if ((m["status"] ?? "IN") != "IN") {
        throw Exception("Grupo no está en estadía");
      }

      final now = DateTime.now();
      final nights = expectedDays < 1 ? 1 : expectedDays;

      final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
      final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
      final adults = _pickInt(personas, ["adultos", "adults"], 0);
      final kids = _pickInt(personas, ["ninos", "kids", "children"], 0);
      // El día que ya estuvo como pase de día se conserva como cargo extra.
      final dayCharge = groupPerDay(
        adults,
        kids,
        _pickInt(rates, ["adultDay", "adult_day"], 7000),
        _pickInt(rates, ["childDay", "child_day"], 5000),
      );

      final updated = Map<String, dynamic>.from(m);
      updated["stayType"] = "CAMPING";
      updated["expectedDays"] = nights;
      updated["extraCharges"] = dayCharge;

      final totalPaid = _pickInt(m, ["totalPaid"], 0);
      tx.update(groupRef, {
        "stayType": "CAMPING",
        "expectedDays": nights,
        "extraCharges": dayCharge,
        "totalExpected": _expectedTotal(updated),
        "checkInStatus": _statusFor(updated, now, totalPaid),
        "updatedAt": FieldValue.serverTimestamp(),
        "stayTypeChangedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  /// Agregar noches al estimado de una acampada.
  Future<void> extendCampingDays({
    required String groupId,
    required int addDays, // noches a sumar
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) throw Exception("Grupo no existe");
      final m = snap.data() as Map<String, dynamic>;
      if ((m["status"] ?? "IN") != "IN") {
        throw Exception("Grupo no está en estadía");
      }
      if ((m["stayType"] ?? "DAY") != "CAMPING") {
        throw Exception("Solo aplica a ACAMPADA");
      }

      final now = DateTime.now();
      final newNights = (_pickInt(m, ["expectedDays"], 1) + addDays).clamp(1, 999);

      final updated = Map<String, dynamic>.from(m);
      updated["expectedDays"] = newNights;

      final totalPaid = _pickInt(m, ["totalPaid"], 0);
      tx.update(groupRef, {
        "expectedDays": newNights,
        "totalExpected": _expectedTotal(updated),
        "checkInStatus": _statusFor(updated, now, totalPaid),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> checkoutGroup(String groupId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final eventRef = _db.collection('access_events').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(groupRef);
      if (!snap.exists) throw Exception("Grupo no existe");

      final data = snap.data() as Map<String, dynamic>;
      if ((data["status"] ?? "IN") != "IN") return;

      // Requiere pagar lo realmente usado (noches usadas + recargo si aplica).
      final now = DateTime.now();
      final required = _incurred(data, now);
      final totalPaid = _pickInt(data, ["totalPaid"], 0);
      if (totalPaid < required) {
        throw Exception(
            "Pago insuficiente para retirar (requiere \$$required, pagado \$$totalPaid).");
      }

      tx.update(groupRef, {
        "status": "OUT",
        "checkoutAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      tx.set(eventRef, {
        "groupId": groupId,
        "type": "RETIRO",
        "timestamp": FieldValue.serverTimestamp(),
        "createdByUid": _uid,
        "rutKey": data["rutKey"],
        "patenteKey": data["patenteKey"],
      });
    });
  }
}
