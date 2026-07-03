import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pricing.dart';

class PricingService {
  final _db = FirebaseFirestore.instance;

  Future<Pricing> getPricing() async {
    final doc = await _db.collection('settings').doc('pricing').get();
    if (!doc.exists) {
      // crea defaults si no existe (opcional)
      final defaults = const Pricing(
        adultDay: 7000,
        adultCamping: 8000,
        childDay: 5000,
        childCamping: 6000,
      );
      await _db.collection('settings').doc('pricing').set(defaults.toMap());
      return defaults;
    }
    return Pricing.fromMap(doc.data()!);
  }
}
