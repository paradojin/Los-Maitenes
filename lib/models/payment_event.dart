import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentEvent {
  final String id;
  final String groupId;
  final int amount;
  final String method; // EFECTIVO | TRANSFERENCIA | TARJETA
  final int coversDays; // 0 = abono, >0 = días que cubre
  final String stayType; // DAY | CAMPING
  final DateTime createdAt;
  final String createdByUid;

  PaymentEvent({
    required this.id,
    required this.groupId,
    required this.amount,
    required this.method,
    required this.coversDays,
    required this.stayType,
    required this.createdAt,
    required this.createdByUid,
  });

  factory PaymentEvent.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return PaymentEvent(
      id: doc.id,
      groupId: (m["groupId"] ?? "") as String,
      amount: (m["amount"] ?? 0) as int,
      method: (m["method"] ?? "EFECTIVO") as String,
      coversDays: (m["coversDays"] ?? 0) as int,
      stayType: (m["stayType"] ?? "DAY") as String,
      createdAt: (m["createdAt"] as Timestamp).toDate(),
      createdByUid: (m["createdByUid"] ?? "") as String,
    );
  }

  Map<String, dynamic> toMap() => {
        "groupId": groupId,
        "amount": amount,
        "method": method,
        "coversDays": coversDays,
        "stayType": stayType,
        "createdAt": Timestamp.fromDate(createdAt),
        "createdByUid": createdByUid,
      };
}
