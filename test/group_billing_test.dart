import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:los_maitenes/services/group_billing.dart';

Timestamp ts(int day, int hour, [int min = 0]) =>
    Timestamp.fromDate(DateTime(2026, 10, day, hour, min));

// Tarifas por defecto: adulto día 7000, adulto noche 8000.
Map<String, dynamic> group({List<Map<String, dynamic>> subgroups = const []}) => {
      "personas": {"adultos": 2, "ninos": 0},
      "stayType": "CAMPING",
      "arrivalAt": ts(5, 12), // lunes 12:00
      "expectedDays": 3,
      "ratesSnapshot": <String, dynamic>{},
      "subgroups": subgroups,
    };

void main() {
  final thu1000 = DateTime(2026, 10, 8, 10, 0);

  test('grupo sin subgrupos cobra igual que antes', () {
    // 2 adultos × 3 noches × 8000
    expect(groupIncurred(group(), thu1000), 48000);
    expect(groupExpected(group(), thu1000), 48000);
    expect(peopleNow(group()), 2);
  });

  test('subgrupo se cobra desde su llegada, no desde la del grupo', () {
    final g = group(subgroups: [
      {"id": "a", "adultos": 1, "ninos": 0, "stayType": "CAMPING",
       "expectedDays": 1, "arrivalAt": ts(7, 12), "checkoutAt": null},
    ]);
    // principal 48000 + subgrupo 1 noche (8000). Antes cobraba 3 noches.
    expect(groupIncurred(g, thu1000), 56000);
    expect(groupExpected(g, thu1000), 56000);
    expect(peopleNow(g), 3);
  });

  test('subgrupo retirado deja de cobrar y no cuenta como presente', () {
    final g = group(subgroups: [
      {"id": "a", "adultos": 1, "ninos": 0, "stayType": "CAMPING",
       "expectedDays": 5, "arrivalAt": ts(5, 12), "checkoutAt": ts(6, 9)},
      {"id": "b", "adultos": 2, "ninos": 0, "stayType": "DAY",
       "expectedDays": 1, "arrivalAt": ts(6, 12), "checkoutAt": ts(6, 18)},
    ]);
    // a: 1 noche (salió antes de 10:30) = 8000; b: 2 × día 7000 = 14000.
    expect(groupIncurred(g, thu1000), 48000 + 8000 + 14000);
    // Retirado cuenta lo usado, no lo planificado (5 noches).
    expect(groupExpected(g, thu1000), 48000 + 8000 + 14000);
    expect(peopleNow(g), 2);
  });
}
