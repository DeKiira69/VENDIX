import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client_home_screen.dart';
import 'client_purchases_screen.dart';
import 'client_balance_screen.dart';
import 'client_profile_screen.dart';
import 'widgets/client_chatbot_sheet.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _seleccion = 0;
  DateTime? _ultimoToqueAtras;

  late final List<Widget> _pantallas;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      ClientHomeScreen(onIrAPerfil: () => setState(() => _seleccion = 3)),
      const ClientPurchasesScreen(),
      const ClientBalanceScreen(),
      const ClientProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Si no estamos en Inicio, volver a la primera pestaña
        if (_seleccion != 0) {
          setState(() => _seleccion = 0);
          return;
        }

        // 2. Si ya estamos en Inicio, confirmar salida
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

        // 3. Salida limpia al sistema operativo sin congelar la app
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6FA),
        body: IndexedStack(index: _seleccion, children: _pantallas),
        floatingActionButton: _seleccion == 0 ? const ClientChatbotFAB() : null,
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFF0E8FC),
          selectedIndex: _seleccion,
          onDestinationSelected: (indice) {
            setState(() => _seleccion = indice);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Compras',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Saldo',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
