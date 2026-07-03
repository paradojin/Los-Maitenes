String normalizeRutKey(String rutRaw) {
  // Ej: "12.345.678-9" -> "123456789"
  return rutRaw.replaceAll(RegExp(r'[^0-9kK]'), '').toLowerCase();
}

String normalizePlateKey(String plateRaw) {
  final cleaned = plateRaw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return cleaned; // si viene vacío, devuelve ""
}
