String normalizeRutKey(String rutRaw) {
  // Ej: "12.345.678-9" -> "123456789"
  return rutRaw.replaceAll(RegExp(r'[^0-9kK]'), '').toLowerCase();
}

String normalizePlateKey(String plateRaw) {
  final cleaned = plateRaw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return cleaned; // si viene vacío, devuelve ""
}

/// Normaliza un celular chileno a formato canónico "+569XXXXXXXX".
/// Acepta: "+56 9 1234 5678", "569XXXXXXXX", "9XXXXXXXX" y los 8 dígitos
/// sin el 9 (les antepone el 9). Devuelve null si no es un celular válido.
String? normalizePhoneCl(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('56')) d = d.substring(2); // quita código país
  if (d.length == 8) d = '9$d'; // 8 dígitos sin el 9 -> anteponer 9
  if (d.length == 9 && d.startsWith('9')) return '+56$d';
  return null; // inválido
}

/// Formatea un celular canónico "+569XXXXXXXX" a "+56 9 XXXX XXXX".
String formatPhoneCl(String canonical) {
  final d = canonical.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 11 && d.startsWith('569')) {
    return "+56 9 ${d.substring(3, 7)} ${d.substring(7)}";
  }
  return canonical;
}
