// Cobro sobre el documento completo de un grupo: grupo principal + subgrupos.
//
// Un subgrupo son personas que se suman a un grupo ya registrado. Cada uno se
// cobra desde SU llegada hasta SU salida (o ahora), con su propio tipo de
// estadía. La cuenta (totalPaid) es común a todo el grupo.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'billing.dart';

int pickInt(Map<String, dynamic> m, List<String> keys, int fallback) {
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

DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

int _adults(Map<String, dynamic> p) => pickInt(p, ["adultos", "adults"], 0);
int _kids(Map<String, dynamic> p) => pickInt(p, ["ninos", "kids", "children"], 0);

List<Map<String, dynamic>> subgroupsOf(Map<String, dynamic> g) =>
    ((g["subgroups"] ?? const []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

bool subgroupActive(Map<String, dynamic> s) => s["checkoutAt"] == null;

/// Personas presentes ahora: principal + subgrupos que no se han retirado.
int peopleNow(Map<String, dynamic> g) {
  final personas = (g["personas"] ?? {}) as Map<String, dynamic>;
  var n = _adults(personas) + _kids(personas);
  for (final s in subgroupsOf(g)) {
    if (subgroupActive(s)) n += _adults(s) + _kids(s);
  }
  return n;
}

class _Rates {
  final int adultDay, childDay, adultCamping, childCamping;
  _Rates(Map<String, dynamic> g)
      : adultDay = pickInt(_r(g), ["adultDay", "adult_day"], 7000),
        childDay = pickInt(_r(g), ["childDay", "child_day"], 5000),
        adultCamping = pickInt(_r(g), ["adultCamping", "adult_camping"], 8000),
        childCamping = pickInt(_r(g), ["childCamping", "child_camping"], 6000);
  static Map<String, dynamic> _r(Map<String, dynamic> g) =>
      (g["ratesSnapshot"] ?? {}) as Map<String, dynamic>;
}

/// Lo incurrido por un subgrupo hasta su salida (o hasta [now]).
int subgroupIncurred(Map<String, dynamic> g, Map<String, dynamic> s, DateTime now) {
  final r = _Rates(g);
  return amountIncurredNow(
    stayType: (s["stayType"] ?? "DAY") as String,
    arrival: _date(s["arrivalAt"]) ?? now,
    now: _date(s["checkoutAt"]) ?? now,
    adults: _adults(s),
    children: _kids(s),
    adultDay: r.adultDay,
    childDay: r.childDay,
    adultCamping: r.adultCamping,
    childCamping: r.childCamping,
  );
}

/// Monto incurrido hasta [now] por todo el grupo (lo requerido para retirar).
int groupIncurred(Map<String, dynamic> g, DateTime now) {
  final r = _Rates(g);
  final personas = (g["personas"] ?? {}) as Map<String, dynamic>;
  var total = amountIncurredNow(
    stayType: (g["stayType"] ?? "DAY") as String,
    arrival: _date(g["arrivalAt"]) ?? now,
    now: now,
    adults: _adults(personas),
    children: _kids(personas),
    adultDay: r.adultDay,
    childDay: r.childDay,
    adultCamping: r.adultCamping,
    childCamping: r.childCamping,
    extraCharges: pickInt(g, ["extraCharges"], 0),
  );
  for (final s in subgroupsOf(g)) {
    total += subgroupIncurred(g, s, now);
  }
  return total;
}

/// Total planificado de todo el grupo. Un subgrupo ya retirado cuenta lo que
/// realmente usó; uno activo, lo planificado.
int groupExpected(Map<String, dynamic> g, DateTime now) {
  final r = _Rates(g);
  final personas = (g["personas"] ?? {}) as Map<String, dynamic>;
  var total = expectedTotalForStay(
    stayType: (g["stayType"] ?? "DAY") as String,
    nights: pickInt(g, ["expectedDays"], 1),
    adults: _adults(personas),
    children: _kids(personas),
    adultDay: r.adultDay,
    childDay: r.childDay,
    adultCamping: r.adultCamping,
    childCamping: r.childCamping,
    extraCharges: pickInt(g, ["extraCharges"], 0),
  );
  for (final s in subgroupsOf(g)) {
    total += subgroupActive(s)
        ? expectedTotalForStay(
            stayType: (s["stayType"] ?? "DAY") as String,
            nights: pickInt(s, ["expectedDays"], 1),
            adults: _adults(s),
            children: _kids(s),
            adultDay: r.adultDay,
            childDay: r.childDay,
            adultCamping: r.adultCamping,
            childCamping: r.childCamping,
          )
        : subgroupIncurred(g, s, now);
  }
  return total;
}
