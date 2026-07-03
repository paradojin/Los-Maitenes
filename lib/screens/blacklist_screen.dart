import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/blacklist_service.dart';
import '../theme.dart';
import '../widgets/b_ui.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  final service = BlacklistService();
  String query = "";

  Future<void> _openAddSheet() async {
    final rut = TextEditingController();
    final plate = TextEditingController();
    final reason = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Agregar a lista negra",
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: rut,
                decoration: const InputDecoration(
                  labelText: "RUT (opcional)",
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plate,
                decoration: const InputDecoration(
                  labelText: "Patente (opcional)",
                  prefixIcon: Icon(Icons.directions_car),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Motivo",
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (reason.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Falta el motivo")),
                            );
                            return;
                          }
                          setLocal(() => saving = true);
                          try {
                            final uid =
                                FirebaseAuth.instance.currentUser?.uid ?? "unknown";
                            await service.addBlacklist(
                              rutRaw: rut.text.trim(),
                              patenteRaw: plate.text.trim(),
                              reason: reason.text.trim(),
                              createdByUid: uid,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setLocal(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                        },
                  child: Text(saving ? "Guardando..." : "Guardar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection("blacklist").orderBy("createdAt", descending: true).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        int activos = 0, inactivos = 0;
        for (final d in docs) {
          final active = ((d.data() as Map<String, dynamic>)["active"] ?? true) as bool;
          active ? activos++ : inactivos++;
        }

        // filtro búsqueda
        final q = query.trim().toLowerCase();
        final filtered = docs.where((d) {
          if (q.isEmpty) return true;
          final m = d.data() as Map<String, dynamic>;
          final rut = ((m["rutKey"] ?? "") as String).toLowerCase();
          final plate = ((m["patenteKey"] ?? "") as String).toLowerCase();
          final reason = ((m["reason"] ?? "") as String).toLowerCase();
          return rut.contains(q) || plate.contains(q) || reason.contains(q);
        }).toList();

        return Column(
          children: [
            GreenHeader(
              title: "Lista negra",
              subtitle: "$activos activos · $inactivos inactivo${inactivos == 1 ? '' : 's'}",
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.white,
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                      onPressed: _openAddSheet,
                      icon: const Icon(Icons.block),
                      label: const Text("Agregar a lista negra",
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar por RUT o patente",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppTheme.white,
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => query = ""),
                            ),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !snap.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 48, color: AppTheme.primaryGreen),
                              const SizedBox(height: 12),
                              Text(
                                docs.isEmpty ? "No hay registros" : "Sin coincidencias",
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          children: [
                            Text(
                              "REGISTROS · ${filtered.length}",
                              style: TextStyle(
                                color: AppTheme.darkText.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...filtered.map((d) {
                              final m = d.data() as Map<String, dynamic>;
                              final active = (m["active"] ?? true) as bool;
                              final rutKey = (m["rutKey"] ?? "") as String;
                              final plateKey = (m["patenteKey"] ?? "") as String;
                              final reason = (m["reason"] ?? "") as String;
                              final color =
                                  active ? AppTheme.statusDebt : AppTheme.statusActive;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: StripeCard(
                                  stripeColor: color,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          active ? Icons.block : Icons.check_circle,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              reason,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              "RUT ${rutKey.isEmpty ? '—' : rutKey} · ${plateKey.isEmpty ? 'sin patente' : plateKey}",
                                              style: TextStyle(
                                                color: AppTheme.darkText
                                                    .withValues(alpha: 0.55),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: active,
                                        onChanged: (v) => service.setActive(d.id, v),
                                        activeThumbColor: AppTheme.primaryGreen,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }
}
