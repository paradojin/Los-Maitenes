import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sesión local del staff que opera la app.
///
/// No es una cuenta de Firebase por persona: la auth sigue siendo anónima
/// (para tener acceso a Firestore), pero guardamos el NOMBRE del operador
/// localmente para identificar quién hace cada registro ("ingresadoPor").
/// El nombre persiste entre aperturas para que el ingreso sea rápido.
class StaffSession {
  static const _kStaffName = 'staff_name';

  /// Nombre del staff actual. `null` = no hay sesión iniciada.
  /// Es un [ValueNotifier] para que la UI reaccione al login/logout.
  static final ValueNotifier<String?> name = ValueNotifier<String?>(null);

  static String? get current => name.value;

  /// Carga la sesión guardada. Llamar una vez al arrancar (antes de runApp).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kStaffName);
    name.value = (saved != null && saved.trim().isNotEmpty) ? saved : null;
  }

  /// Inicia sesión de staff: persiste el nombre y lo refleja en el perfil
  /// del usuario anónimo de Firebase (para tenerlo también del lado servidor).
  static Future<void> signIn(String staffName) async {
    final trimmed = staffName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStaffName, trimmed);

    // Asegura sesión de Firebase y refleja el nombre en el perfil.
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    await auth.currentUser?.updateDisplayName(trimmed);

    name.value = trimmed;
  }

  /// Cierra la sesión del staff (no cierra la sesión anónima de Firebase).
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStaffName);
    name.value = null;
  }
}
