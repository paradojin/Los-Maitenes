import 'package:flutter/material.dart';

import '../theme.dart';
import 'home_screen.dart';
import 'finance_screen.dart';
import 'blacklist_screen.dart';
import 'account_screen.dart';
import 'create_group_screen.dart';

/// Contenedor principal con barra de navegación inferior verde y FAB central
/// para crear grupo (Propuesta B "Operativo y directo").
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Se incrementa al entrar a Finanzas para forzar su recarga (datos frescos).
  int _financeTick = 0;

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeScreen(),
      FinanceScreen(key: ValueKey('finance-$_financeTick')),
      const BlacklistScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      extendBody: true,
      body: IndexedStack(index: _index, children: tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
          onPressed: _openCreate,
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.primaryGreen,
          elevation: 3,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.headerGreen,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 68,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: "Inicio",
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _NavItem(
              icon: Icons.attach_money_rounded,
              label: "Finanzas",
              selected: _index == 1,
              // Recarga los datos cada vez que se entra a Finanzas.
              onTap: () => setState(() {
                _index = 1;
                _financeTick++;
              }),
            ),
            const SizedBox(width: 64), // hueco para el FAB
            _NavItem(
              icon: Icons.block_rounded,
              label: "Lista",
              selected: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: "Cuenta",
              selected: _index == 3,
              onTap: () => setState(() => _index = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.white : AppTheme.white.withValues(alpha: 0.6);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
