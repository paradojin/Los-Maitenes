import 'package:flutter/material.dart';

import '../models/pricing.dart';
import '../services/pricing_service.dart';
import '../services/staff_session.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/b_ui.dart';

class PricesScreen extends StatefulWidget {
  const PricesScreen({super.key});

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  final _service = PricingService();
  final _adultDay = TextEditingController();
  final _childDay = TextEditingController();
  final _adultCamping = TextEditingController();
  final _childCamping = TextEditingController();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _service.getPricing().then((p) {
      if (!mounted) return;
      _adultDay.text = formatCLP(p.adultDay);
      _childDay.text = formatCLP(p.childDay);
      _adultCamping.text = formatCLP(p.adultCamping);
      _childCamping.text = formatCLP(p.childCamping);
      setState(() => loading = false);
    });
  }

  @override
  void dispose() {
    for (final c in [_adultDay, _childDay, _adultCamping, _childCamping]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = [_adultDay, _childDay, _adultCamping, _childCamping]
        .map((c) => parseCLP(c.text))
        .toList();
    if (values.any((v) => v <= 0)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Todos los precios deben ser mayores a 0")));
      return;
    }
    setState(() => saving = true);
    try {
      await _service.savePricing(
        Pricing(
          adultDay: values[0],
          childDay: values[1],
          adultCamping: values[2],
          childCamping: values[3],
        ),
        StaffSession.current ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Precios guardados")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, prefixText: "\$ "),
          onChanged: (v) {
            final f = formatCLP(parseCLP(v));
            c.value = TextEditingValue(
                text: f, selection: TextSelection.collapsed(offset: f.length));
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Column(
        children: [
          const GreenHeader(title: "Precios", showBack: true),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Text(
                        "Por persona. Aplica a los grupos que ingresen desde ahora; "
                        "los grupos en estadía mantienen el precio con que ingresaron.",
                        style: TextStyle(
                            color: AppTheme.darkText.withValues(alpha: 0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _field("Adulto · por el día", _adultDay),
                      _field("Niño · por el día", _childDay),
                      _field("Adulto · acampada (por noche)", _adultCamping),
                      _field("Niño · acampada (por noche)", _childCamping),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(saving ? "Guardando..." : "Guardar precios"),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
