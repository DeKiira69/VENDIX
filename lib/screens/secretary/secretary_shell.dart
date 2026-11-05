import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'quick_sales_screen.dart';
import 'clients_screen.dart';
import 'statistics_screen.dart';
import 'more_screen.dart';
import '../../theme/app_theme.dart';

class SecretaryShell extends StatefulWidget {
  const SecretaryShell({super.key});

  @override
  State<SecretaryShell> createState() => _SecretaryShellState();
}

class _SecretaryShellState extends State<SecretaryShell> {
  int _indiceActual = 0;

  void cambiarPantalla(int indice) {
    if (indice < 0 || indice > 4) return;

    setState(() {
      _indiceActual = indice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      HomeScreen(
        alAbrirVentas: () => cambiarPantalla(1),
        alAbrirClientes: () => cambiarPantalla(2),
        alAbrirEstadisticas: () => cambiarPantalla(3),
        alAbrirMas: () => cambiarPantalla(4),
      ),
      QuickSalesScreen(onVolver: () => cambiarPantalla(0)),
      ClientsScreen(onVolver: () => cambiarPantalla(0)),
      StatisticsScreen(onVolver: () => cambiarPantalla(0)),
      const MoreScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(index: _indiceActual, children: pantallas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: cambiarPantalla,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.violet,
        unselectedItemColor: AppTheme.muted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Ventas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Clientas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Estadísticas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Más'),
        ],
      ),
    );
  }
}
