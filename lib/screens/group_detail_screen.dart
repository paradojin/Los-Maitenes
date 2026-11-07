import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../services/billing.dart';
import '../services/group_billing.dart';
import '../services/staff_session.dart';
import '../utils/money.dart';
import '../services/blacklist_service.dart';
import '../services/keys.dart';
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
  final _amountCtrl = TextEditingController(text: "0");
  bool loading = false;

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

  /// Sugerido = lo que falta para cubrir el total planificado de la estadía.
  void _calcSuggested(Map<String, dynamic> g) {
    final remaining = _int(g["totalExpected"]) - _int(g["totalPaid"]);
    _amountCtrl.text = formatCLP(remaining > 0 ? remaining : 0);
    setState(() {});
  }

  Future<void> _editPeople(int adults, int kids) async {
    int a = adults, k = kids;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget stp(String label, int value, ValueChanged<int> onCh) => Row(
                children: [
                  Expanded(child: Text(label)),
                  IconButton(
                    onPressed: value <= 0 ? null : () => setLocal(() => onCh(value - 1)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text("$value", style: Theme.of(ctx).textTheme.titleLarge),
                  IconButton(
                    onPressed: () => setLocal(() => onCh(value + 1)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              );
          return AlertDialog(
            title: const Text("Corregir personas"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Solo para corregir un error del registro inicial. "
                  "Si llegaron más personas usa \"Sumar personas\".",
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                stp("Adultos", a, (v) => a = v),
                stp("Niños", k, (v) => k = v),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
              ElevatedButton(
                  onPressed: (a == 0 && k == 0) ? null : () => Navigator.pop(ctx, true),
                  child: const Text("Guardar")),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await fs.updateGroupPeople(groupId: widget.groupId, adultos: a, ninos: k);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Personas actualizadas")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _addSubgroup() async {
    int a = 1, k = 0, nights = 1;
    String type = "DAY";
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget stp(String label, int value, int min, ValueChanged<int> onCh) => Row(
                children: [
                  Expanded(child: Text(label)),
                  IconButton(
                    onPressed: value <= min ? null : () => setLocal(() => onCh(value - 1)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text("$value", style: Theme.of(ctx).textTheme.titleLarge),
                  IconButton(
                    onPressed: () => setLocal(() => onCh(value + 1)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              );
          return AlertDialog(
            title: const Text("Sumar personas"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Se cobran desde ahora, no desde la llegada del grupo.",
                    style: TextStyle(fontSize: 12.5)),
                const SizedBox(height: 8),
                stp("Adultos", a, 0, (v) => a = v),
                stp("Niños", k, 0, (v) => k = v),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: "DAY", label: Text("Por el día")),
                    ButtonSegment(value: "CAMPING", label: Text("Acampada")),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setLocal(() => type = v.first),
                ),
                if (type == "CAMPING")
                  stp("Noches (estimado)", nights, 1, (v) => nights = v),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
              ElevatedButton(
                  onPressed: (a == 0 && k == 0) ? null : () => Navigator.pop(ctx, true),
                  child: const Text("Sumar")),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await fs.addSubgroup(
        groupId: widget.groupId,
        adultos: a,
        ninos: k,
        stayType: type,
        expectedDays: nights,
        ingresadoPor: StaffSession.current ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Personas sumadas al grupo")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _checkoutSubgroup(String subgroupId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Retirar subgrupo"),
        content: const Text(
            "Deja de cobrarse desde ahora. Lo que usó queda en la cuenta del grupo."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true), child: const Text("Retirar")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await fs.checkoutSubgroup(groupId: widget.groupId, subgroupId: subgroupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  String _when(dynamic ts) {
    if (ts is! Timestamp) return "—";
    final d = ts.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}";
  }

  Widget _partyTile({required String title, required String subtitle, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.darkText.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _mainPartyTile(int adults, int kids, String typeLabel, dynamic arrivalAt) =>
      _partyTile(
        title: "Registro inicial · $adults ad · $kids niño",
        subtitle: "$typeLabel · llegó ${_when(arrivalAt)}",
      );

  Widget _subgroupTile(Map<String, dynamic> sg, bool groupIn) {
    final active = subgroupActive(sg);
    final type = sg["stayType"] == "CAMPING" ? "Acampada" : "Por el día";
    final left = active ? "" : " · salió ${_when(sg["checkoutAt"])}";
    return _partyTile(
      title: "Se sumaron · ${_int(sg["adultos"])} ad · ${_int(sg["ninos"])} niño",
      subtitle: "$type · llegó ${_when(sg["arrivalAt"])}$left",
      trailing: active && groupIn
          ? TextButton(
              onPressed: () => _checkoutSubgroup(sg["id"] as String),
              child: const Text("Retirar"))
          : null,
    );
  }

  static const _methodLabel = {
    "EFECTIVO": "Efectivo",
    "TRANSFERENCIA": "Transferencia",
    "TARJETA": "Tarjeta",
  };

  Widget _paymentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("payments")
          .where("groupId", isEqualTo: widget.groupId)
          .snapshots(),
      builder: (_, snap) {
        final docs = [...?snap.data?.docs];
        if (docs.isEmpty) return const SizedBox.shrink();
        // Orden en el cliente: evita exigir un índice compuesto en Firestore.
        DateTime at(QueryDocumentSnapshot d) =>
            ((d.data() as Map<String, dynamic>)["createdAt"] as Timestamp?)?.toDate() ??
            DateTime.now();
        docs.sort((a, b) => at(b).compareTo(at(a)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _label("PAGOS"),
            const SizedBox(height: 10),
            for (final d in docs) _paymentTile(d.id, d.data() as Map<String, dynamic>),
          ],
        );
      },
    );
  }

  Widget _paymentTile(String id, Map<String, dynamic> p) {
    final voided = p["voided"] == true;
    final method = _methodLabel[p["method"]] ?? (p["method"] ?? "") as String;
    final who = (p["registradoPor"] ?? "") as String;
    final amount = "\$${formatCLP(_int(p["amount"]))}";
    return _partyTile(
      title: voided ? "$amount · $method · ANULADO" : "$amount · $method",
      subtitle: voided
          ? "Anuló ${p["voidedBy"] ?? "—"} el ${_when(p["voidedAt"])}: ${p["voidReason"] ?? ""}"
          : "${_when(p["createdAt"])}${who.isEmpty ? "" : " · $who"}",
      trailing: voided
          ? null
          : TextButton(
              onPressed: () => _voidPayment(id, amount, method),
              child: const Text("Anular", style: TextStyle(color: AppTheme.statusDebt)),
            ),
    );
  }

  Future<void> _voidPayment(String paymentId, String amount, String method) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text("Anular pago"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$amount · $method\n\n"
                  "Deja de contar en el grupo y en Finanzas. Queda registrado "
                  "quién lo anuló y por qué. Si corresponde, registra luego el pago correcto."),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(
                  labelText: "Motivo (obligatorio)",
                  hintText: "Ej: era transferencia, no efectivo",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: reasonCtrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text("Anular")),
          ],
        ),
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true) return;
    try {
      await fs.voidPayment(paymentId: paymentId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Pago anulado")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _alertBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusDebt.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.statusDebt),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.statusDebt, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.statusDebt, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
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

          final now = DateTime.now();
          final requiredNow = groupIncurred(g, now);
          final subgroups = subgroupsOf(g);
          final peopleTotal = peopleNow(g);
          final faltaCheckout = requiredNow - totalPaid;
          final canCheckout = faltaCheckout <= 0;
          final overdueDayPass = isIn && dayPassOverdue(stayType, now);

          final subtitle =
              "${plate.isEmpty ? 'Sin patente' : plate} · $typeLabel";

          return Column(
            children: [
              _header(responsable, subtitle, state, totalExpected, totalPaid, falta),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    if (overdueDayPass) ...[
                      _alertBanner(
                          "Pase de día pasado de las 21:00 — retíralo o pásalo a acampada."),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Expanded(
                            child: _infoBox("PERSONAS",
                                subgroups.isEmpty ? "$adults ad · $kids niño" : "$peopleTotal en total")),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _infoBox(
                                "CELULAR",
                                celular.isEmpty ? "—" : formatPhoneCl(celular))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _infoBox("INGRESÓ", ingresadoPor.isEmpty ? "—" : ingresadoPor)),
                      ],
                    ),
                    if (subgroups.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _label("PERSONAS DEL GRUPO"),
                      const SizedBox(height: 10),
                      _mainPartyTile(adults, kids, typeLabel, g["arrivalAt"]),
                      for (final sg in subgroups) _subgroupTile(sg, isIn),
                    ],
                    if (isIn) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text("Sumar personas"),
                        onPressed: _addSubgroup,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text("Corregir personas del registro"),
                        onPressed: () => _editPeople(adults, kids),
                      ),
                      const SizedBox(height: 12),
                      _convertExtendButton(stayType),
                      const SizedBox(height: 20),
                      _label("REGISTRAR PAGO"),
                      const SizedBox(height: 10),
                      _paymentCard(g, stayType),
                    ],
                    _paymentsList(),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              alDia ? "\$${formatCLP(totalPaid)}" : "\$${formatCLP(falta)}",
              maxLines: 1,
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                    const Text("¿Cuántas noches planea quedarse (estimado)?"),
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
      label: const Text("Agregar 1 noche (estimado)"),
      onPressed: () async {
        await fs.extendCampingDays(groupId: widget.groupId, addDays: 1);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Noche agregada al estimado")));
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
