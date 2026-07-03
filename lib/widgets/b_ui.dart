import 'package:flutter/material.dart';
import '../theme.dart';

/// Encabezado verde sólido de la Propuesta B "Operativo y directo".
/// Ocupa el tope de la pantalla (detrás de la barra de estado) con esquinas
/// inferiores redondeadas. Acepta contenido extra (stats, cifras grandes).
class GreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onBack;

  const GreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.trailing,
    this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.headerGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBack)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.arrow_back, color: AppTheme.white),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: AppTheme.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: 16),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón circular translúcido para el header (ej. perfil, refrescar).
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const HeaderIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: AppTheme.white, size: 20),
        ),
      ),
    );
  }
}

/// Estado de pago de un grupo, derivado de lo esperado vs pagado.
enum PayState { alDia, abono, pendiente }

PayState payStateFrom({required int totalExpected, required int totalPaid}) {
  final falta = totalExpected - totalPaid;
  if (falta <= 0) return PayState.alDia;
  if (totalPaid > 0) return PayState.abono;
  return PayState.pendiente;
}

extension PayStateStyle on PayState {
  Color get color {
    switch (this) {
      case PayState.alDia:
        return AppTheme.statusActive;
      case PayState.abono:
        return AppTheme.statusAbono;
      case PayState.pendiente:
        return AppTheme.statusDebt;
    }
  }

  String get label {
    switch (this) {
      case PayState.alDia:
        return "AL DÍA";
      case PayState.abono:
        return "ABONO";
      case PayState.pendiente:
        return "PENDIENTE";
    }
  }
}

/// Píldora de estado (texto en color sobre fondo tenue del mismo color).
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const StatusPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Tarjeta con franja de color a la izquierda (patrón central de la Propuesta B).
class StripeCard extends StatelessWidget {
  final Color stripeColor;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const StripeCard({
    super.key,
    required this.stripeColor,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: stripeColor),
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
