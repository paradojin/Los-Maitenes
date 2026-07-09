import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/pricing_service.dart';
import '../services/billing.dart';
import '../models/pricing.dart';
import 'group_detail_screen.dart';
import '../services/blacklist_service.dart';
import '../services/staff_session.dart';
import '../services/keys.dart';
import '../utils/money.dart';
import '../theme.dart';
import '../widgets/b_ui.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _rut = TextEditingController();
  final _celular = TextEditingController();
  final _plate = TextEditingController();

  int adults = 2;
  int kids = 0;
  int expectedDays = 1; // solo acampada

  String stayType = "DAY";
  String errorText = "";
  bool loading = false;

  Pricing? pricing;
  int totalExpectedLive = 0;

  bool _isFormattingRut = false;

  @override
  void initState() {
    super.initState();
    _loadPricing();
    _rut.addListener(_formatRutVisual);
  }

  @override
  void dispose() {
    _name.dispose();
    _rut.dispose();
    _celular.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    final p = await PricingService().getPricing();
    if (!mounted) return;
    setState(() => pricing = p);
    _recalc();
  }

  // === Formato visual de RUT: "203009623" -> "20.300.962-3" ===
  void _formatRutVisual() {
    if (_isFormattingRut) return;
    final raw = _rut.text;
    final digits = raw.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    if (digits.isEmpty) return;
    final formatted = _formatRut(digits);
    if (formatted != raw) {
      _isFormattingRut = true;
      _rut.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isFormattingRut = false;
    }
  }

  String _formatRut(String digits) {
    if (digits.length == 1) return digits;
    final dv = digits.substring(digits.length - 1);
    String body = digits.substring(0, digits.length - 1);
    final parts = <String>[];
    while (body.length > 3) {
      parts.insert(0, body.substring(body.length - 3));
      body = body.substring(0, body.length - 3);
    }
    parts.insert(0, body);
    return "${parts.join('.')}-$dv";
  }

  void _recalc() {
    final p = pricing;
    if (p == null) return;
    final nights = stayType == "DAY" ? 1 : (expectedDays < 1 ? 1 : expectedDays);
    final total = expectedTotalForStay(
      stayType: stayType,
      nights: nights,
      adults: adults,
      children: kids,
      adultDay: p.adultDay,
      childDay: p.childDay,
      adultCamping: p.adultCamping,
      childCamping: p.childCamping,
    );
    setState(() => totalExpectedLive = total);
  }

  bool _setErr(String msg) {
    setState(() => errorText = msg);
    return false;
  }

  bool _validate() {
    if (_name.text.trim().isEmpty) return _setErr("Falta el nombre del responsable.");
    if (_celular.text.trim().isEmpty) return _setErr("Falta el celular del responsable.");
    if (normalizePhoneCl(_celular.text) == null) {
      return _setErr("Celular inválido. Ej: 9 1234 5678 (con o sin +56).");
    }
    if (adults == 0 && kids == 0) return _setErr("Debe haber al menos 1 persona.");
    if (stayType == "CAMPING" && expectedDays < 1) {
      return _setErr("Las noches de acampada deben ser 1 o más.");
    }
    _setErr("");
    return true;
  }

  Future<void> _createAndGoToPayment() async {
    if (!_validate()) return;
    final p = pricing;
    if (p == null) {
      _setErr("No se pudo cargar precios. Reintenta.");
      return;
    }

    setState(() => loading = true);
    try {
      final fs = FirestoreService();
      final expDays = stayType == "DAY" ? 1 : (expectedDays < 1 ? 1 : expectedDays);

      final rutRaw = _rut.text.trim();
      final plateRaw = _plate.text.trim();

      final hit = await BlacklistService().check(rutRaw: rutRaw, patenteRaw: plateRaw);
      if (hit.hit) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("⚠️ Alerta: Lista negra"),
            content: Text(
                "Esta persona/vehículo está en lista negra.\n\nMotivo:\n${hit.reason}\n\n¿Deseas continuar igual?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancelar")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Continuar")),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => loading = false);
          return;
        }
      }

      final groupId = await fs.createGroup(
        responsableNombre: _name.text.trim(),
        responsableRut: rutRaw,
        responsableCelular: normalizePhoneCl(_celular.text) ?? _celular.text.trim(),
        ingresadoPor: StaffSession.current ?? '',
        patente: plateRaw,
        adultos: adults,
        ninos: kids,
        stayType: stayType,
        expectedDays: expDays,
        pricing: p,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      );
    } catch (e) {
      if (mounted) _setErr("Error creando grupo: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Column(
        children: [
          const GreenHeader(title: "Crear grupo", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              children: [
                _label("TIPO DE ESTADÍA"),
                const SizedBox(height: 8),
                _stayToggle(),
                const SizedBox(height: 20),
                _label("NOMBRE DEL RESPONSABLE"),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: "Nombre completo"),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label("RUT · OPC."),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rut,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: "12.345.678-9"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label("CELULAR"),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _celular,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(hintText: "9 1234 5678"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label("PATENTE · OPCIONAL"),
                const SizedBox(height: 8),
                TextField(
                  controller: _plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: "ABCD-12"),
                ),
                const SizedBox(height: 20),
                _label("PERSONAS"),
                const SizedBox(height: 8),
                _stepper("Adultos", adults, (v) {
                  setState(() => adults = v < 0 ? 0 : v);
                  _recalc();
                }),
                const SizedBox(height: 10),
                _stepper("Niños", kids, (v) {
                  setState(() => kids = v < 0 ? 0 : v);
                  _recalc();
                }),
                if (stayType == "CAMPING") ...[
                  const SizedBox(height: 10),
                  _stepper("Noches (estimado)", expectedDays, (v) {
                    setState(() => expectedDays = v < 1 ? 1 : v);
                    _recalc();
                  }),
                ],
                if (errorText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.statusDebt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.statusDebt),
                    ),
                    child: Text(errorText,
                        style: const TextStyle(
                            color: AppTheme.statusDebt, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _bottomBar() {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("TOTAL A PAGAR",
                      style: TextStyle(
                        color: AppTheme.darkText.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        "\$${formatCLP(totalExpectedLive)}",
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _createAndGoToPayment,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(loading ? "Cargando..." : "Continuar al cobro",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stayToggle() {
    Widget opt(String value, String text, IconData icon) {
      final sel = stayType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => stayType = value);
            _recalc();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primaryGreen : AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? AppTheme.primaryGreen : AppTheme.borderGray),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: sel ? AppTheme.white : AppTheme.darkText),
                const SizedBox(width: 8),
                Text(text,
                    style: TextStyle(
                      color: sel ? AppTheme.white : AppTheme.darkText,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opt("DAY", "Por el día", Icons.wb_sunny_outlined),
        const SizedBox(width: 10),
        opt("CAMPING", "Acampada", Icons.cabin_outlined),
      ],
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    Widget btn(IconData icon, VoidCallback onTap, bool enabled) {
      return Material(
        color: enabled ? AppTheme.primaryGreen : AppTheme.borderGray,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: AppTheme.white, size: 22),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          btn(Icons.remove, () => onChanged(value - 1), value > 0),
          SizedBox(
            width: 44,
            child: Text("$value",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          btn(Icons.add, () => onChanged(value + 1), true),
        ],
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
