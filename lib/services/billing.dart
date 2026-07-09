// ===========================================================================
// Motor de cobro de Los Maitenes  (modelo por NOCHES)
//
//  DÍA (pase de día): tarifa día por persona.
//  ACAMPADA: unidad = NOCHE.
//    - Al ingresar se cobra 1 noche; esa noche cubre hasta las 10:30 del día
//      siguiente.
//    - Día de salida (sin quedarse otra noche):
//        · hasta 10:30  -> nada extra (la noche ya lo cubría)
//        · 10:30–21:00  -> se suma 1 "día" (tarifa día)
//        · pasadas 21:00 -> cuenta como otra noche (tarifa acampada)
//    - La sobre-estadía se cobra sola (cada 21:00 que siguen presentes = otra
//      noche).
//  Un "por el día" no debería seguir después de las 21:00 -> la UI avisa.
// ===========================================================================

const int kMorningCutoffHour = 10;
const int kMorningCutoffMin = 30; // 10:30
const int kNightCutoffHour = 21; // 21:00

DateTime _at(DateTime d, int h, int m) => DateTime(d.year, d.month, d.day, h, m);

int groupPerNight(int adults, int kids, int adultCamping, int childCamping) =>
    adults * adultCamping + kids * childCamping;

int groupPerDay(int adults, int kids, int adultDay, int childDay) =>
    adults * adultDay + kids * childDay;

/// Unidades de acampada incurridas hasta [now]: nº de noches y si corresponde
/// el recargo de "día" (estar presente el día de salida entre 10:30 y 21:00).
class CampingUnits {
  final int nights;
  final bool daySurcharge;
  const CampingUnits(this.nights, this.daySurcharge);
}

CampingUnits campingUnitsIncurred(DateTime arrival, DateTime now) {
  int nights = 1; // primera noche al ingresar
  // La noche cubre hasta las 10:30 del día siguiente.
  DateTime coverUntil = _at(arrival.add(const Duration(days: 1)),
      kMorningCutoffHour, kMorningCutoffMin);

  while (true) {
    if (!now.isAfter(coverUntil)) {
      return CampingUnits(nights, false); // dentro de la cobertura de la noche
    }
    // Pasó las 10:30 del día de salida. ¿Pasó también las 21:00?
    final nightThreshold = _at(coverUntil, kNightCutoffHour, 0);
    if (now.isBefore(nightThreshold)) {
      return CampingUnits(nights, true); // 10:30–21:00 -> recargo de día
    }
    // Pasadas las 21:00 -> otra noche completa.
    nights += 1;
    coverUntil = _at(coverUntil.add(const Duration(days: 1)),
        kMorningCutoffHour, kMorningCutoffMin);
  }
}

/// Un pase de día que sigue presente pasadas las 21:00 (la UI debe avisar).
bool dayPassOverdue(String stayType, DateTime now) =>
    stayType == "DAY" && now.hour >= kNightCutoffHour;

/// Total planificado de una estadía (lo que se estima al crear).
///  - DÍA: tarifa día.
///  - ACAMPADA: noches planificadas × tarifa noche  (+ cargos extra).
/// El recargo de "día" de salida NO se incluye acá; se suma al retirar.
int expectedTotalForStay({
  required String stayType,
  required int nights,
  required int adults,
  required int children,
  required int adultDay,
  required int childDay,
  required int adultCamping,
  required int childCamping,
  int extraCharges = 0,
}) {
  final perDay = groupPerDay(adults, children, adultDay, childDay);
  if (stayType == "DAY") return perDay + extraCharges;
  final n = nights < 1 ? 1 : nights;
  return groupPerNight(adults, children, adultCamping, childCamping) * n +
      extraCharges;
}

/// Monto realmente incurrido hasta [now]: sirve tanto para el estado
/// (ACTIVO/PENDIENTE) como para lo requerido al retirar.
///  - DÍA: tarifa día.
///  - ACAMPADA: noches incurridas × noche + (recargo día si aplica).
///  - [extraCharges]: p. ej. el día ya usado cuando un pase de día se convierte.
int amountIncurredNow({
  required String stayType,
  required DateTime arrival,
  required DateTime now,
  required int adults,
  required int children,
  required int adultDay,
  required int childDay,
  required int adultCamping,
  required int childCamping,
  int extraCharges = 0,
}) {
  final perDay = groupPerDay(adults, children, adultDay, childDay);
  if (stayType == "DAY") return perDay + extraCharges;
  final perNight = groupPerNight(adults, children, adultCamping, childCamping);
  final u = campingUnitsIncurred(arrival, now);
  return perNight * u.nights + (u.daySurcharge ? perDay : 0) + extraCharges;
}
