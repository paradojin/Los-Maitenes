import 'package:cloud_firestore/cloud_firestore.dart';

class GroupStay {
  final String id;
  final String responsableNombre;
  final String responsableRut;
  final String rutKey;
  final String responsableCelular;
  final String patente;
  final String patenteKey;

  final int adultos;
  final int ninos;

  final String stayType; // DAY | CAMPING
  final String status; // IN | OUT

  final DateTime arrivalAt;
  final DateTime? checkoutAt;

  final int paidDays;
  final DateTime paidUntil;

  final String ingresadoPor; // Nombre del staff que ingresó

  GroupStay({
    required this.id,
    required this.responsableNombre,
    required this.responsableRut,
    required this.rutKey,
    required this.responsableCelular,
    required this.patente,
    required this.patenteKey,
    required this.adultos,
    required this.ninos,
    required this.stayType,
    required this.status,
    required this.arrivalAt,
    required this.checkoutAt,
    required this.paidDays,
    required this.paidUntil,
    required this.ingresadoPor,
  });

  factory GroupStay.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    DateTime tsToDt(dynamic v) => (v as Timestamp).toDate();

    final personas = (m['personas'] ?? {}) as Map<String, dynamic>;
    return GroupStay(
      id: doc.id,
      responsableNombre: (m['responsableNombre'] ?? '') as String,
      responsableRut: (m['responsableRut'] ?? '') as String,
      rutKey: (m['rutKey'] ?? '') as String,
      responsableCelular: (m['responsableCelular'] ?? '') as String,
      patente: (m['patente'] ?? '') as String,
      patenteKey: (m['patenteKey'] ?? '') as String,
      adultos: (personas['adultos'] ?? 0) as int,
      ninos: (personas['ninos'] ?? 0) as int,
      stayType: (m['stayType'] ?? 'DAY') as String,
      status: (m['status'] ?? 'IN') as String,
      arrivalAt: tsToDt(m['arrivalAt']),
      checkoutAt: m['checkoutAt'] == null ? null : tsToDt(m['checkoutAt']),
      paidDays: (m['paidDays'] ?? 0) as int,
      paidUntil: tsToDt(m['paidUntil']),
      ingresadoPor: (m['ingresadoPor'] ?? '') as String,
    );
  }
}
