import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pricing.dart';
import 'billing.dart';
import 'keys.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<String> createGroup({
  required String responsableNombre,
  required String responsableRut,
  required String responsableCelular,
  required String ingresadoPor,
  required String patente,
  required int adultos,
  required int ninos,
  required String stayType, // "DAY" | "CAMPING"
  required int expectedDays, // 1 para DAY, 1..N para CAMPING
  required Pricing pricing,
}) async {
  final now = DateTime.now();
  final rutKey = normalizeRutKey(responsableRut);
  final plateKey = normalizePlateKey(patente);

  // total esperado (fórmula unificada: noches + último día para acampada)
  final expDays = (stayType == "DAY") ? 1 : (expectedDays < 1 ? 1 : expectedDays);
  final totalExpected = expectedTotalForStay(
    stayType: stayType,
    expectedDays: expDays,
    adults: adultos,
    children: ninos,
    adultDay: pricing.adultDay,
    childDay: pricing.childDay,
    adultCamping: pricing.adultCamping,
    childCamping: pricing.childCamping,
  );

  // Estado inicial: aún sin pagos (totalPaid = 0).
  final dueSoFar = expectedSoFar(
    stayType: stayType,
    arrival: now,
    now: now,
    expectedDays: expDays,
    adults: adultos,
    children: ninos,
    adultDay: pricing.adultDay,
    childDay: pricing.childDay,
    adultCamping: pricing.adultCamping,
    childCamping: pricing.childCamping,
  );
  final initialCheck = 0 >= dueSoFar ? "ACTIVE" : "PENDING";

  // Al crear, NO está pagado aún: paidUntil = "ayer" (o hoy 07:00-1min) para que quede vencido
  final initialPaidUntil = DateTime(now.year, now.month, now.day, 6, 59);

  final groupRef = _db.collection('groups').doc();
  final eventRef = _db.collection('access_events').doc();

  // Nombre del staff que registra: viene del login (parámetro).
  // Fallback al perfil del usuario o 'Sistema' si llegara vacío.
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
      "stayType": stayType, // DAY = "POR EL DÍA"
      "expectedDays": expDays,
      "ratesSnapshot": pricing.toMap(),

      "paidDays": 0,
      "paidUntil": Timestamp.fromDate(initialPaidUntil),

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

    final stayType = (m['stayType'] ?? 'DAY') as String;

    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    final adults = _pickInt(personas, ["adultos", "adults"], 0);
    final kids = _pickInt(personas, ["ninos", "kids", "children"], 0);

    final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    final adultDay = _pickInt(rates, ["adultDay", "adult_day"], 7000);
    final childDay = _pickInt(rates, ["childDay", "child_day"], 5000);
    final adultCamping = _pickInt(rates, ["adultCamping", "adult_camping"], 8000);
    final childCamping = _pickInt(rates, ["childCamping", "child_camping"], 6000);

    final expectedDays = _pickInt(m, ["expectedDays"], 1);

    // El dinero pagado siempre se acumula.
    final oldTotalPaid = _pickInt(m, ["totalPaid"], 0);
    final newTotalPaid = oldTotalPaid + amount;

    // Base de llegada
    DateTime baseArrival = now;
    final arrivalRaw = m["arrivalAt"];
    if (arrivalRaw is Timestamp) baseArrival = arrivalRaw.toDate();

    // Estado: ACTIVO si lo pagado cubre lo que se debe hasta ahora.
    final dueSoFar = expectedSoFar(
      stayType: stayType,
      arrival: baseArrival,
      now: now,
      expectedDays: expectedDays,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );
    final newCheck = newTotalPaid >= dueSoFar ? "ACTIVE" : "PENDING";

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
      "stayType": stayType,
      "createdAt": FieldValue.serverTimestamp(),
      "createdByUid": _uid,
    });
  });
}

Future<void> syncGroupStatusesForToday() async {
  final now = DateTime.now();

  // Solo grupos en estadía
  final qs = await _db
      .collection("groups")
      .where("status", isEqualTo: "IN")
      .get();

  final batch = _db.batch();
  int changes = 0;

  for (final doc in qs.docs) {
    final m = doc.data();

    final stayType = (m["stayType"] ?? "DAY") as String;
    final expectedDays = _pickInt(m, ["expectedDays"], 1);
    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    final adults = _pickInt(personas, ["adultos", "adults"], 0);
    final kids = _pickInt(personas, ["ninos", "kids", "children"], 0);
    final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    final adultDay = _pickInt(rates, ["adultDay", "adult_day"], 7000);
    final childDay = _pickInt(rates, ["childDay", "child_day"], 5000);
    final adultCamping = _pickInt(rates, ["adultCamping", "adult_camping"], 8000);
    final childCamping = _pickInt(rates, ["childCamping", "child_camping"], 6000);

    DateTime arrival = now;
    final ar = m["arrivalAt"];
    if (ar is Timestamp) arrival = ar.toDate();

    final totalPaid = _pickInt(m, ["totalPaid"], 0);
    final dueSoFar = expectedSoFar(
      stayType: stayType,
      arrival: arrival,
      now: now,
      expectedDays: expectedDays,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );
    final shouldBe = totalPaid >= dueSoFar ? "ACTIVE" : "PENDING";
    final current = (m["checkInStatus"] ?? "PENDING") as String;

    if (current != shouldBe) {
      batch.update(doc.reference, {
        "checkInStatus": shouldBe,
        "updatedAt": FieldValue.serverTimestamp(),
      });
      changes++;
    }
  }

  if (changes > 0) {
    await batch.commit();
  }
}

Future<void> convertDayToCamping({
  required String groupId,
  required int expectedDays, // ej: 1..N
}) async {
  final groupRef = _db.collection('groups').doc(groupId);

  await _db.runTransaction((tx) async {
    final snap = await tx.get(groupRef);
    if (!snap.exists) throw Exception("Grupo no existe");

    final m = snap.data() as Map<String, dynamic>;
    if ((m["status"] ?? "IN") != "IN") throw Exception("Grupo no está en estadía");

    final now = DateTime.now();

    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    final adults = _pickInt(personas, ["adultos"], 0);
    final kids = _pickInt(personas, ["ninos"], 0);

    final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    final adultDay = _pickInt(rates, ["adultDay", "adult_day"], 7000);
    final childDay = _pickInt(rates, ["childDay", "child_day"], 5000);
    final adultCamping = _pickInt(rates, ["adultCamping", "adult_camping"], 8000);
    final childCamping = _pickInt(rates, ["childCamping", "child_camping"], 6000);

    final expDays = expectedDays < 1 ? 1 : expectedDays;

    // El dinero ya pagado se conserva (no se pierde al convertir).
    final totalPaid = _pickInt(m, ["totalPaid"], 0);

    DateTime arrival = now;
    final arrivalRaw = m["arrivalAt"];
    if (arrivalRaw is Timestamp) arrival = arrivalRaw.toDate();

    final newTotalExpected = expectedTotalForStay(
      stayType: "CAMPING",
      expectedDays: expDays,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );

    final dueSoFar = expectedSoFar(
      stayType: "CAMPING",
      arrival: arrival,
      now: now,
      expectedDays: expDays,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );
    final newCheck = totalPaid >= dueSoFar ? "ACTIVE" : "PENDING";

    tx.update(groupRef, {
      "stayType": "CAMPING",
      "expectedDays": expDays,
      "totalExpected": newTotalExpected,
      "checkInStatus": newCheck,
      "updatedAt": FieldValue.serverTimestamp(),
      "stayTypeChangedAt": FieldValue.serverTimestamp(),
    });
  });
}

Future<void> extendCampingDays({
  required String groupId,
  required int addDays, // +1, +2, etc.
}) async {
  final groupRef = _db.collection('groups').doc(groupId);

  await _db.runTransaction((tx) async {
    final snap = await tx.get(groupRef);
    if (!snap.exists) throw Exception("Grupo no existe");

    final m = snap.data() as Map<String, dynamic>;
    if ((m["status"] ?? "IN") != "IN") throw Exception("Grupo no está en estadía");

    final stayType = (m["stayType"] ?? "DAY") as String;
    if (stayType != "CAMPING") throw Exception("Solo aplica a ACAMPADA");

    final now = DateTime.now();
    final currentExpected = _pickInt(m, ["expectedDays"], 1);
    final newExpected = (currentExpected + addDays);
    final exp = newExpected < 1 ? 1 : newExpected;

    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    final adults = _pickInt(personas, ["adultos"], 0);
    final kids = _pickInt(personas, ["ninos"], 0);

    final rates = (m['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    final adultDay = _pickInt(rates, ["adultDay", "adult_day"], 7000);
    final childDay = _pickInt(rates, ["childDay", "child_day"], 5000);
    final adultCamping = _pickInt(rates, ["adultCamping", "adult_camping"], 8000);
    final childCamping = _pickInt(rates, ["childCamping", "child_camping"], 6000);

    final newTotalExpected = expectedTotalForStay(
      stayType: "CAMPING",
      expectedDays: exp,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );

    DateTime arrival = now;
    final arrivalRaw = m["arrivalAt"];
    if (arrivalRaw is Timestamp) arrival = arrivalRaw.toDate();

    final totalPaid = _pickInt(m, ["totalPaid"], 0);
    final dueSoFar = expectedSoFar(
      stayType: "CAMPING",
      arrival: arrival,
      now: now,
      expectedDays: exp,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );
    final newCheck = totalPaid >= dueSoFar ? "ACTIVE" : "PENDING";

    // totalExpected y estado actualizados
    tx.update(groupRef, {
      "expectedDays": exp,
      "totalExpected": newTotalExpected,
      "checkInStatus": newCheck,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  });
}


  Future<void> checkoutGroup(String groupId) async {
  final groupRef = _db.collection('groups').doc(groupId);
  final eventRef = _db.collection('access_events').doc();

  await _db.runTransaction((tx) async {
    final snap = await tx.get(groupRef);
    if (!snap.exists) {
      throw Exception("Grupo no existe");
    }

    final data = snap.data() as Map<String, dynamic>;
    final status = data["status"] ?? "IN";

    // Si ya está retirado, no hacemos nada
    if (status != "IN") return;

    // Validar que el pago alcance según la regla de las 10:30
    // (antes de esa hora solo se cobran las noches en acampada).
    final now = DateTime.now();
    final stayType = (data["stayType"] ?? "DAY") as String;
    final personas = (data['personas'] ?? {}) as Map<String, dynamic>;
    final adults = _pickInt(personas, ["adultos", "adults"], 0);
    final kids = _pickInt(personas, ["ninos", "kids", "children"], 0);
    final rates = (data['ratesSnapshot'] ?? {}) as Map<String, dynamic>;
    final adultDay = _pickInt(rates, ["adultDay", "adult_day"], 7000);
    final childDay = _pickInt(rates, ["childDay", "child_day"], 5000);
    final adultCamping = _pickInt(rates, ["adultCamping", "adult_camping"], 8000);
    final childCamping = _pickInt(rates, ["childCamping", "child_camping"], 6000);
    DateTime arrival = now;
    final ar = data["arrivalAt"];
    if (ar is Timestamp) arrival = ar.toDate();

    final required = checkoutRequired(
      stayType: stayType,
      arrival: arrival,
      now: now,
      adults: adults,
      children: kids,
      adultDay: adultDay,
      childDay: childDay,
      adultCamping: adultCamping,
      childCamping: childCamping,
    );
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
