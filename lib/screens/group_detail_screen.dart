import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../services/pricing_service.dart';
import '../services/billing.dart';
import '../models/pricing.dart';
import '../utils/money.dart';
import '../services/blacklist_service.dart';
import '../theme.dart';
import '../widgets/b_ui.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final fs = FirestoreService();
  String method = "EFECTIVO";
  int campingDaysToPay = 1;
  final _amountCtrl = TextEditingController(text: "0");
  bool loading = false;
  Pricing? pricing;

  @override
  void initState() {
    super.initState();
    PricingService().getPricing().then((p) {
      if (mounted) setState(() => pricing = p);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int _int(dynamic v, [int d = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return d;
  }

  int _parseMoney(String s) {
    final c = s.replaceAll(RegExp(r'[^0-9]'), '');
    return c.isEmpty ? 0 : int.parse(c);
  }

  Future<void> _calcSuggested(Map<String, dynamic> g) async {
    final p = pricing ?? await PricingService().getPricing();
    if (mounted) setState(() => pricing = p);
    final stayType = (g["stayType"] ?? "DAY") as String;
    final expectedDays = _int(g["expectedDays"], 1);
    final personas = (g["personas"] ?? {}) as Map<String, dynamic>;
    final adults = _int(personas["adultos"]);
    final kids = _int(personas["ninos"]);
    final daysToPay = stayType == "DAY" ? 1 : campingDaysToPay;
    final suggested = suggestedAmount(
      now: DateTime.now(),
      stayType: stayType,
      adults: adults,
      children: kids,
      adultDay: p.adultDay,
      adultCamping: p.adultCamping,
      childDay: p.childDay,
      childCamping: p.childCamping,
      daysToPay: daysToPay,
      expectedTotalDays: expectedDays,
    );
    if (mounted) {
      _amountCtrl.text = formatCLP(suggested);
      setState(() {});
    }
  }

  Future<void> _registerPayment() async {
    final amount = _parseMoney(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Monto inválido")));
      return;
    }
    setState(() => loading = true);
    try {
      await fs.registerPayment(groupId: widget.groupId, amount: amount, method: method);
      if (!mounted) return;
      _amountCtrl.text = "0";
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Pago registrado")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _quickBlacklist(String rutRaw, String plateRaw) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Agregar a lista negra"),
        content: TextField(
          controller: reasonCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: "Motivo", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Guardar")),
        ],
      ),
    );
    if (ok != true) return;
    if (reasonCtrl.text.trim().isEmpty) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
      await BlacklistService().addBlacklist(
        rutRaw: rutRaw,
        patenteRaw: plateRaw,
        reason: reasonCtrl.text.trim(),
        createdByUid: uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Agregado a lista negra")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection("groups").doc(widget.groupId).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text("Grupo no existe"));
          }
          final g = snap.data!.data() as Map<String, dynamic>;

          final statusRaw = (g["status"] ?? "IN") as String;
          final isIn = statusRaw == "IN";
          final stayType = (g["stayType"] ?? "DAY") as String;
          final typeLabel = stayType == "DAY" ? "Por el día" : "Acampada";
          final responsable = (g["responsableNombre"] ?? "") as String;
          final rut = (g["responsableRut"] ?? "") as String;
          final celular = (g["responsableCelular"] ?? "") as String;
          final ingresadoPor = (g["ingresadoPor"] ?? "") as String;
          final plate = ((g["patente"] ?? "") as String).trim();
          final personas = (g["personas"] ?? {}) as Map<String, dynamic>;
          final adults = _int(personas["adultos"]);
          final kids = _int(personas["ninos"]);
          final totalExpected = _int(g["totalExpected"]);
          final totalPaid = _int(g["totalPaid"]);
          final falta = totalExpected - totalPaid;

          final state = payStateFrom(totalExpected: totalExpected, totalPaid: totalPaid);

          final rates = (g["ratesSnapshot"] ?? {}) as Map<String, dynamic>;
          int rate(String k, int d) => _int(rates[k], d);
          final arrivalAt = (g["arrivalAt"] as Timestamp?)?.toDate();
          final now = DateTime.now();
          final requiredNow = checkoutRequired(
            stayType: stayType,
            arrival: arrivalAt ?? now,
            now: now,
            adults: adults,
            children: kids,
            adultDay: rate("adultDay", 7000),
            childDay: rate("childDay", 5000),
            adultCamping: rate("adultCamping", 8000),
            childCamping: rate("childCamping", 6000),
          );
          final faltaCheckout = requiredNow - totalPaid;
          final canCheckout = faltaCheckout <= 0;

          final subtitle =
              "${plate.isEmpty ? 'Sin patente' : plate} · $typeLabel";

          return Column(
            children: [
              _header(responsable, subtitle, state, totalExpected, totalPaid, falta),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _infoBox("PERSONAS", "$adults ad · $kids niño")),
                        const SizedBox(width: 10),
                        Expanded(child: _infoBox("CELULAR", celular.isEmpty ? "—" : celular)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _infoBox("INGRESÓ", ingresadoPor.isEmpty ? "—" : ingresadoPor)),
                      ],
                    ),
                    if (isIn) ...[
                      const SizedBox(height: 16),
                      _convertExtendButton(stayType),
                      const SizedBox(height: 20),
                      _label("REGISTRAR PAGO"),
                      const SizedBox(height: 10),
                      _paymentCard(g, stayType),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.block),
                      label: const Text("Agregar a lista negra"),
                      onPressed: () => _quickBlacklist(rut, plate),
                    ),
                  ],
                ),
              ),
              if (isIn) _checkoutBar(canCheckout, requiredNow, totalPaid, faltaCheckout),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String name, String subtitle, PayState state, int totalExpected,
      int totalPaid, int falta) {
    final progress = totalExpected > 0 ? (totalPaid / totalExpected).clamp(0.0, 1.0) : 1.0;
    final alDia = state == PayState.alDia;
    return GreenHeader(
      title: name,
      subtitle: subtitle,
      showBack: true,
      trailing: StatusPill(text: state.label, color: AppTheme.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alDia ? "TOTAL PAGADO" : "FALTA POR COBRAR",
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alDia ? "\$${formatCLP(totalPaid)}" : "\$${formatCLP(falta)}",
            style: const TextStyle(
              color: AppTheme.white,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 6,
              backgroundColor: AppTheme.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(AppTheme.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Pagó \$${formatCLP(totalPaid)} de \$${formatCLP(totalExpected)}",
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: AppTheme.darkText.withValues(alpha: 0.5),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _convertExtendButton(String stayType) {
    if (stayType == "DAY") {
      return OutlinedButton.icon(
        icon: const Icon(Icons.cabin_outlined),
        label: const Text("Cambiar a Acampada"),
        onPressed: () async {
          int days = 1;
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => StatefulBuilder(
              builder: (ctx, setLocal) => AlertDialog(
                title: const Text("Cambiar a Acampada"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("¿Cuántos días planea quedarse (estimado)?"),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: days <= 1 ? null : () => setLocal(() => days--),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text("$days",
                            style: Theme.of(context).textTheme.titleLarge),
                        IconButton(
                          onPressed: () => setLocal(() => days++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Confirmar")),
                ],
              ),
            ),
          );
          if (ok == true) {
            await fs.convertDayToCamping(groupId: widget.groupId, expectedDays: days);
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Ahora es ACAMPADA")));
            }
          }
        },
      );
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.add),
      label: const Text("Agregar 1 día (estimado)"),
      onPressed: () async {
        await fs.extendCampingDays(groupId: widget.groupId, addDays: 1);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Día agregado al estimado")));
        }
      },
    );
  }

  Widget _paymentCard(Map<String, dynamic> g, String stayType) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _methodSelector(),
          if (stayType == "CAMPING") ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Text("Días a pagar",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: campingDaysToPay <= 1
                      ? null
                      : () => setState(() => campingDaysToPay--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text("$campingDaysToPay",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => campingDaysToPay++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: "\$ ",
              suffixIcon: TextButton(
                onPressed: () => _calcSuggested(g),
                child: const Text("Sugerido"),
              ),
            ),
            onChanged: (value) {
              final n = parseCLP(value);
              final f = formatCLP(n);
              _amountCtrl.value = TextEditingValue(
                text: f,
                selection: TextSelection.collapsed(offset: f.length),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: loading ? null : _registerPayment,
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.payments),
              label: Text(loading ? "Registrando..." : "Registrar pago",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodSelector() {
    Widget seg(String value, String text) {
      final sel = method == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => method = value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primaryGreen : AppTheme.subtleGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sel ? AppTheme.white : AppTheme.darkText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg("EFECTIVO", "Efectivo"),
        seg("TRANSFERENCIA", "Transfer."),
        seg("TARJETA", "Tarjeta"),
      ],
    );
  }

  Widget _checkoutBar(bool canCheckout, int requiredNow, int totalPaid, int faltaCheckout) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canCheckout ? AppTheme.primaryGreen : AppTheme.borderGray,
                foregroundColor: canCheckout ? AppTheme.white : AppTheme.darkText,
              ),
              icon: Icon(canCheckout ? Icons.exit_to_app : Icons.lock),
              label: Text(
                canCheckout ? "Retirar grupo" : "Retirar · falta pago",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                if (!canCheckout) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("⚠️ No se puede retirar"),
                      content: Text(
                        "Falta pago para poder retirar este grupo.\n\n"
                        "Requerido ahora: \$${formatCLP(requiredNow)}\n"
                        "Pagado: \$${formatCLP(totalPaid)}\n"
                        "Falta: \$${formatCLP(faltaCheckout)}\n\n"
                        "Antes de las 10:30 solo se cobran las noches.",
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK")),
                      ],
                    ),
                  );
                  return;
                }
                try {
                  await fs.checkoutGroup(widget.groupId);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: TextStyle(
          color: AppTheme.darkText.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      );
}
