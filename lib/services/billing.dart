DateTime serviceDayStart(DateTime dt) {
  final startToday = DateTime(dt.year, dt.month, dt.day, 7, 0);
  if (dt.isBefore(startToday)) {
    final prev = dt.subtract(const Duration(days: 1));
    return DateTime(prev.year, prev.month, prev.day, 7, 0);
  }
  return startToday;
}

DateTime serviceDayEnd(DateTime serviceStart) =>
    DateTime(serviceStart.year, serviceStart.month, serviceStart.day, 23, 0);

DateTime paidUntilAfter(DateTime startServiceDay, int daysToAdd) {
  final d = daysToAdd < 1 ? 1 : daysToAdd;
  final lastStart = startServiceDay.add(Duration(days: d - 1));
  return serviceDayEnd(lastStart);
}

DateTime nextBillingServiceDay(DateTime now, DateTime paidUntil) {
  if (paidUntil.isBefore(now)) return serviceDayStart(now);
  final paidStart = serviceDayStart(paidUntil);
  return paidStart.add(const Duration(days: 1));
}

String ymd(DateTime dt) {
  String two(int x) => x.toString().padLeft(2, '0');
  return "${dt.year}-${two(dt.month)}-${two(dt.day)}";
}

int suggestedAmount({
  required DateTime now,
  required String stayType, // "DAY" | "CAMPING"
  required int adults,
  required int children,
  required int adultDay,
  required int adultCamping,
  required int childDay,
  required int childCamping,
  int daysToPay = 1, // para CAMPING puede ser >1
  int expectedTotalDays = 1, // para CAMPING: días esperados totales
}) {
  final cutoff = DateTime(now.year, now.month, now.day, 23, 0);

  // Si ya pasó las 23:00, DAY no aplica.
  if (stayType == "DAY" && now.isAfter(cutoff)) {
    stayType = "CAMPING";
  }

  if (stayType == "DAY") {
    return (adults * adultDay) + (children * childDay);
  } else {
    final d = daysToPay < 1 ? 1 : daysToPay;
    final totalDays = expectedTotalDays < 1 ? 1 : expectedTotalDays;
    
    final perNight = (adults * adultCamping) + (children * childCamping); // 8000
    final perLastDay = (adults * adultDay) + (children * childDay); // 7000
    
    // Si es solo 1 día total, se cobra como 7000 (sin noche)
    if (totalDays == 1) {
      return perLastDay;
    }
    
    // Si es N días, calcular según cuántos pagos se hagan:
    // - Primeros (N-1) días: 8000 cada uno
    // - Último día: 7000
    if (d >= totalDays) {
      // Pagar todos los días
      return (perNight * (totalDays - 1)) + perLastDay;
    } else {
      // Pagar solo d días (que no incluyen el último)
      return perNight * d;
    }
  }
}

DateTime endOfToday23(DateTime now) =>
    DateTime(now.year, now.month, now.day, 23, 0);

bool isCoveredForToday(DateTime paidUntil, DateTime now) {
  return !paidUntil.isBefore(endOfToday23(now)); // paidUntil >= hoy 23:00
}

// ===========================================================================
// Modelo unificado de cobro (fuente única de verdad)
//
//  - DÍA: tarifa día.
//  - ACAMPADA de N días: (N-1) noches a tarifa acampada + 1 día a tarifa día.
//  - Retiro antes de las 10:30: se exime el último día (solo noches).
// ===========================================================================

int groupPerNight(int adults, int kids, int adultCamping, int childCamping) =>
    adults * adultCamping + kids * childCamping;

int groupPerDay(int adults, int kids, int adultDay, int childDay) =>
    adults * adultDay + kids * childDay;

/// Noches entre la llegada y [now], contadas por día de servicio (corte 07:00).
/// Mismo día de servicio = 0 noches; cada nuevo día de servicio suma 1 noche.
int serviceNightsBetween(DateTime arrival, DateTime now) {
  final a = serviceDayStart(arrival);
  final b = serviceDayStart(now);
  final n = b.difference(a).inDays;
  return n < 0 ? 0 : n;
}

/// True si [now] es antes de las 10:30 AM (exime el último día en acampada).
bool beforeMorningCutoff(DateTime now) =>
    now.hour < 10 || (now.hour == 10 && now.minute < 30);

/// Total esperado (planificado) de una estadía completa.
int expectedTotalForStay({
  required String stayType,
  required int expectedDays,
  required int adults,
  required int children,
  required int adultDay,
  required int childDay,
  required int adultCamping,
  required int childCamping,
}) {
  final perDay = groupPerDay(adults, children, adultDay, childDay);
  if (stayType == "DAY") return perDay;
  final n = expectedDays < 1 ? 1 : expectedDays;
  if (n == 1) return perDay; // 1 día de acampada = pase de día
  final perNight = groupPerNight(adults, children, adultCamping, childCamping);
  return perNight * (n - 1) + perDay;
}

/// Monto que el grupo debería tener pagado "hasta ahora" (para ACTIVO/PENDIENTE).
/// Cuenta las noches ya dormidas + el cargo del último día si ya están en el
/// día final (o más) y pasó las 10:30.
int expectedSoFar({
  required String stayType,
  required DateTime arrival,
  required DateTime now,
  required int expectedDays,
  required int adults,
  required int children,
  required int adultDay,
  required int childDay,
  required int adultCamping,
  required int childCamping,
}) {
  final perDay = groupPerDay(adults, children, adultDay, childDay);
  if (stayType == "DAY") return perDay; // el pase de día se debe el mismo día
  final perNight = groupPerNight(adults, children, adultCamping, childCamping);
  final nights = serviceNightsBetween(arrival, now);
  final n = expectedDays < 1 ? 1 : expectedDays;
  final onOrPastLastDay = (nights + 1) >= n; // dayIndex = nights + 1
  final lastDayDue = (onOrPastLastDay && !beforeMorningCutoff(now)) ? perDay : 0;
  return perNight * nights + lastDayDue;
}

/// Monto requerido para poder retirar al grupo en [now].
/// Aplica la regla de las 10:30: antes de esa hora solo se cobran las noches.
int checkoutRequired({
  required String stayType,
  required DateTime arrival,
  required DateTime now,
  required int adults,
  required int children,
  required int adultDay,
  required int childDay,
  required int adultCamping,
  required int childCamping,
}) {
  final perDay = groupPerDay(adults, children, adultDay, childDay);
  if (stayType == "DAY") return perDay;
  final perNight = groupPerNight(adults, children, adultCamping, childCamping);
  final nights = serviceNightsBetween(arrival, now);
  final lastDay = beforeMorningCutoff(now) ? 0 : perDay;
  return perNight * nights + lastDay;
}
