import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  DateTime? _ultimoToqueAtras;

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Si no estamos en Inicio, regresar a Inicio
        if (_indiceActual != 0) {
          cambiarPantalla(0);
          return;
        }

        // 2. Si ya estamos en Inicio, confirmación para salir limpiamente
        final ahora = DateTime.now();
        if (_ultimoToqueAtras == null ||
            ahora.difference(_ultimoToqueAtras!) > const Duration(seconds: 2)) {
          _ultimoToqueAtras = ahora;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presiona atrás de nuevo para salir de la aplicación'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // 3. Salida limpia al sistema operativo sin pantalla negra ni congelamiento
        await SystemNavigator.pop();
      },
      child: Scaffold(
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
      ),
    );
  }
}
