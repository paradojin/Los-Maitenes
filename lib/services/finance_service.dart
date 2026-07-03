import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceSummary {
  final int total;
  final int count; // cantidad de pagos
  final Map<String, int> byMethod; // EFECTIVO/TRANSFERENCIA/TARJETA
  FinanceSummary({
    required this.total,
    required this.count,
    required this.byMethod,
  });

  int get ticketPromedio => count > 0 ? (total ~/ count) : 0;
}

/// Estado de cobro de los grupos en estadía (para las cajas inferiores).
class GroupsBillingStatus {
  final int cobrados; // grupos al día (sin deuda)
  final int total; // grupos en estadía
  final int porCobrar; // suma de lo que falta
  GroupsBillingStatus({
    required this.cobrados,
    required this.total,
    required this.porCobrar,
  });
}

class FinanceService {
  final _db = FirebaseFirestore.instance;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTime _startOfWeek(DateTime d) {
    // Semana LUNES -> DOMINGO
    final weekday = d.weekday; // 1=Lunes
    return _startOfDay(d.subtract(Duration(days: weekday - 1)));
  }

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  Future<FinanceSummary> summarizeRange(DateTime start, DateTime end) async {
    final qs = await _db
        .collection("payments")
        .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where("createdAt", isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    int total = 0;
    int count = 0;
    final byMethod = <String, int>{
      "EFECTIVO": 0,
      "TRANSFERENCIA": 0,
      "TARJETA": 0,
    };

    for (final doc in qs.docs) {
      final m = doc.data();
      final rawAmount = m["amount"] ?? 0;
      final amount = rawAmount is int ? rawAmount : (rawAmount as num).toInt();
      final method = (m["method"] ?? "EFECTIVO") as String;

      total += amount;
      count++;
      byMethod[method] = (byMethod[method] ?? 0) + amount;
    }

    return FinanceSummary(total: total, count: count, byMethod: byMethod);
  }

  /// Estado de cobro de los grupos actualmente en estadía.
  Future<GroupsBillingStatus> groupsBillingStatus() async {
    final qs = await _db
        .collection("groups")
        .where("status", isEqualTo: "IN")
        .get();

    int cobrados = 0;
    int porCobrar = 0;
    for (final doc in qs.docs) {
      final m = doc.data();
      int pick(String k) {
        final v = m[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        return 0;
      }

      final falta = pick("totalExpected") - pick("totalPaid");
      if (falta <= 0) {
        cobrados++;
      } else {
        porCobrar += falta;
      }
    }
    return GroupsBillingStatus(
      cobrados: cobrados,
      total: qs.docs.length,
      porCobrar: porCobrar,
    );
  }

  Future<FinanceSummary> summarizeToday() async {
    final now = DateTime.now();
    return summarizeRange(_startOfDay(now), _endOfDay(now));
  }

  Future<FinanceSummary> summarizeThisWeek() async {
    final now = DateTime.now();
    final start = _startOfWeek(now);
    final end = _endOfDay(start.add(const Duration(days: 6)));
    return summarizeRange(start, end);
  }

  Future<FinanceSummary> summarizeThisMonth() async {
    final now = DateTime.now();
    final start = _startOfMonth(now);
    final end = _endOfDay(DateTime(now.year, now.month + 1, 0)); // último día del mes
    return summarizeRange(start, end);
  }
}