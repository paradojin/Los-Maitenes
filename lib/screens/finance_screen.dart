import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../utils/money.dart';
import '../theme.dart';
import '../widgets/b_ui.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final service = FinanceService();

  bool loading = true;
  FinanceSummary? day, week, month;
  GroupsBillingStatus? groups;
  String? error;
  int tab = 0; // 0=Hoy 1=Semana 2=Mes

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final d = await service.summarizeToday();
      final w = await service.summarizeThisWeek();
      final m = await service.summarizeThisMonth();
      final g = await service.groupsBillingStatus();
      if (!mounted) return;
      setState(() {
        day = d;
        week = w;
        month = m;
        groups = g;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  FinanceSummary? get _current => tab == 0 ? day : (tab == 1 ? week : month);
  String get _periodLabel => tab == 0 ? "hoy" : (tab == 1 ? "esta semana" : "este mes");

  @override
  Widget build(BuildContext context) {
    final s = _current;
    return Column(
      children: [
        GreenHeader(
          title: "Finanzas",
          trailing: HeaderIconButton(icon: Icons.refresh, onTap: _load),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tabs(),
              const SizedBox(height: 16),
              Text(
                "Recaudado $_periodLabel",
                style: TextStyle(
                  color: AppTheme.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "\$${formatCLP(s?.total ?? 0)}",
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${s?.count ?? 0} pagos · ticket promedio \$${formatCLP(s?.ticketPromedio ?? 0)}",
                style: TextStyle(
                  color: AppTheme.white.withValues(alpha: 0.8),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? _errorView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primaryGreen,
                      child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                      children: [
                        _sectionLabel("POR MÉTODO DE PAGO"),
                        const SizedBox(height: 10),
                        _methodsCard(s!),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _summaryBox(
                                "GRUPOS COBRADOS",
                                "${groups?.cobrados ?? 0} / ${groups?.total ?? 0}",
                                AppTheme.statusActive,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _summaryBox(
                                "POR COBRAR",
                                "\$${formatCLP(groups?.porCobrar ?? 0)}",
                                AppTheme.statusAbono,
                              ),
                            ),
                          ],
                        ),
                      ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _tabs() {
    Widget seg(String label, int i) {
      final sel = tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppTheme.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sel ? AppTheme.primaryGreen : AppTheme.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [seg("Hoy", 0), seg("Semana", 1), seg("Mes", 2)]),
    );
  }

  Widget _methodsCard(FinanceSummary s) {
    final total = s.total == 0 ? 1 : s.total;
    Widget row(IconData icon, String label, String key) {
      final amount = s.byMethod[key] ?? 0;
      final pct = amount / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreenLight2.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(width: 6),
                      Text("${(pct * 100).round()}%",
                          style: TextStyle(
                              color: AppTheme.darkText.withValues(alpha: 0.45),
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: AppTheme.subtleGray,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.statusActive),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "\$${formatCLP(amount)}",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
        children: [
          row(Icons.payments_outlined, "Efectivo", "EFECTIVO"),
          const Divider(height: 1),
          row(Icons.swap_horiz, "Transferencia", "TRANSFERENCIA"),
          const Divider(height: 1),
          row(Icons.credit_card, "Tarjeta", "TARJETA"),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
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
          Text(
            label,
            style: TextStyle(
              color: AppTheme.darkText.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: AppTheme.darkText.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      );

  Widget _errorView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text("Error: $error"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text("Reintentar")),
          ],
        ),
      );
}
