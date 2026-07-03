import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'group_detail_screen.dart';
import '../theme.dart';
import '../services/firestore_service.dart';
import '../utils/money.dart';
import '../widgets/b_ui.dart';

enum HomeFilter { all, active, pending }

enum StayTypeFilter { all, day, camping }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String query = "";
  HomeFilter filter = HomeFilter.all;
  StayTypeFilter typeFilter = StayTypeFilter.all;

  bool _didSync = false;
  bool _syncing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSync) {
      _didSync = true;
      _syncStatusesOnce();
    }
  }

  Future<void> _syncStatusesOnce() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await FirestoreService().syncGroupStatusesForToday();
    } catch (_) {
      // silencioso
    } finally {
      _syncing = false;
    }
  }

  int _int(dynamic v, [int d = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: db.collection('groups').where('status', isEqualTo: 'IN').snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            final maps = docs.map((d) => d.data() as Map<String, dynamic>).toList();

            // Métricas globales para el header
            int personasHoy = 0;
            int porCobrar = 0;
            for (final m in maps) {
              final personas = (m["personas"] ?? {}) as Map<String, dynamic>;
              personasHoy += _int(personas["adultos"]) + _int(personas["ninos"]);
              final falta = _int(m["totalExpected"]) - _int(m["totalPaid"]);
              if (falta > 0) porCobrar++;
            }
            final gruposActivos = maps.length;

            return GreenHeader(
              title: "Los Maitenes",
              child: Row(
                children: [
                  _StatChip(value: "$personasHoy", label: "Personas hoy"),
                  const SizedBox(width: 10),
                  _StatChip(value: "$gruposActivos", label: "Grupos activos"),
                  const SizedBox(width: 10),
                  _StatChip(value: "$porCobrar", label: "Por cobrar"),
                ],
              ),
            );
          },
        ),
        // Cuerpo: filtros + lista
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('groups').where('status', isEqualTo: 'IN').snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              final maps = docs.map((d) => d.data() as Map<String, dynamic>).toList();
              final ids = docs.map((d) => d.id).toList();

              List<int> idx = List.generate(maps.length, (i) => i);
              idx = idx.where((i) {
                final isPending = (maps[i]["checkInStatus"] ?? "PENDING") != "ACTIVE";
                if (filter == HomeFilter.all) return true;
                if (filter == HomeFilter.pending) return isPending;
                return !isPending;
              }).toList();
              idx = idx.where((i) {
                final st = (maps[i]["stayType"] ?? "DAY") as String;
                if (typeFilter == StayTypeFilter.all) return true;
                if (typeFilter == StayTypeFilter.day) return st == "DAY";
                return st == "CAMPING";
              }).toList();
              final q = query.trim().toLowerCase();
              if (q.isNotEmpty) {
                idx = idx.where((i) {
                  final m = maps[i];
                  final name = ((m["responsableNombre"] ?? "") as String).toLowerCase();
                  final plate = ((m["patenteKey"] ?? m["patente"] ?? "") as String).toLowerCase();
                  return name.contains(q) || plate.contains(q);
                }).toList();
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  // Buscador
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar nombre o patente",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => query = ""),
                            ),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 14),
                  // Filtros de estado
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip("Todos", filter == HomeFilter.all,
                          () => setState(() => filter = HomeFilter.all)),
                      _chip("Activos", filter == HomeFilter.active,
                          () => setState(() => filter = HomeFilter.active)),
                      _chip("Pendientes", filter == HomeFilter.pending,
                          () => setState(() => filter = HomeFilter.pending)),
                      _chip("Acampada", typeFilter == StayTypeFilter.camping, () {
                        setState(() => typeFilter =
                            typeFilter == StayTypeFilter.camping
                                ? StayTypeFilter.all
                                : StayTypeFilter.camping);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "EN ESTADÍA · ${maps.length}",
                    style: TextStyle(
                      color: AppTheme.darkText.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (idx.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "No hay grupos con esos filtros.",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    ...idx.map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _groupCard(maps[i], ids[i]),
                        )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _groupCard(Map<String, dynamic> m, String groupId) {
    final name = (m["responsableNombre"] ?? "") as String;
    final plate = ((m["patenteKey"] ?? m["patente"] ?? "") as String).trim();
    final personas = (m["personas"] ?? {}) as Map<String, dynamic>;
    final adults = _int(personas["adultos"]);
    final kids = _int(personas["ninos"]);
    final stayType = (m["stayType"] ?? "DAY") as String;
    final typeLabel = stayType == "DAY" ? "Por el día" : "Acampada";
    final totalExpected = _int(m["totalExpected"]);
    final totalPaid = _int(m["totalPaid"]);
    final falta = totalExpected - totalPaid;

    final state = payStateFrom(totalExpected: totalExpected, totalPaid: totalPaid);

    final subtitle = [
      if (plate.isNotEmpty) plate else "Sin patente",
      "$adults adultos $kids niños",
      typeLabel,
    ].join(" · ");

    return StripeCard(
      stripeColor: state.color,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              Text(
                state.label,
                style: TextStyle(
                  color: state.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.darkText.withValues(alpha: 0.55),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  "Pagó \$${formatCLP(totalPaid)} / \$${formatCLP(totalExpected)}",
                  style: TextStyle(
                    color: AppTheme.darkText.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (state == PayState.alDia)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: state.color),
                    const SizedBox(width: 4),
                    Text(
                      "Al día",
                      style: TextStyle(
                        color: state.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  "\$${formatCLP(falta)}",
                  style: TextStyle(
                    color: state.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : AppTheme.borderGray,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.white : AppTheme.darkText,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.white.withValues(alpha: 0.85),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
