import 'package:intl/intl.dart';

final _clpFormat = NumberFormat("#,##0", "es_CL");

String formatCLP(int value) {
  return _clpFormat.format(value);
}

int parseCLP(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) return 0;
  return int.parse(cleaned);
}