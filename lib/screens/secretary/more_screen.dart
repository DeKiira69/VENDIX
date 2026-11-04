import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/client_service.dart';
import '../../services/perfil_foto_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../client/client_shell.dart';
import 'clothing_prices_screen.dart';
import 'jornadas_screen.dart';
import 'payments_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final usuarioId = usuario?.uid ?? '';
    final nombreMostrar = usuario?.displayName ?? 'Daniela León';
    final iniciales = nombreMostrar
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
        children: [
          const Text(
            'ADMINISTRACIÓN',
            style: TextStyle(
              color: AppTheme.violet,
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Más opciones',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 23),

          // Tarjeta de la secretaria con Avatar interactivo estilo WhatsApp
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF56349D), Color(0xFF7650BC)],
              ),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Row(
              children: [
                StreamBuilder<String?>(
                  stream: PerfilFotoService.fotoStream(usuarioId),
                  builder: (context, snapshot) {
                    return PerfilFotoService.avatarConInsignia(
                      fotoData: snapshot.data,
                      iniciales: iniciales.isEmpty ? 'DL' : iniciales,
                      radio: 26,
                      onTap: () {
                        if (usuarioId.isEmpty) return;
                        PerfilFotoService.mostrarOpcionesFotoWhatsApp(
                          context: context,
                          usuarioId: usuarioId,
                          fotoActual: snapshot.data,
                          rol: 'secretaria',
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreMostrar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        usuario?.email ?? 'Secretaria · Acceso de secretaria',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _option(
                  context,
                  Icons.live_tv_outlined,
                  'Jornadas de venta',
                  'Crea y gestiona tus lives',
                  const JornadasScreen(),
                ),
                const Divider(height: 1, color: AppTheme.border),
                _option(
                  context,
                  Icons.checkroom_outlined,
                  'Prendas y precios',
                  'Administra los precios de hoy',
                  const ClothingPricesScreen(),
                ),
                const Divider(height: 1, color: AppTheme.border),
                _option(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Pagos',
                  'Registra abonos pendientes',
                  const PaymentsScreen(),
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading: _icon(Icons.settings_outlined),
                  title: const Text(
                    'Configuración',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Cuenta y preferencias',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La configuración se implementará después.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientShell()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Color(0xFFD6C4F4)),
              foregroundColor: AppTheme.violet,
              backgroundColor: const Color(0xFFF0E9FC),
            ),
            icon: const Icon(Icons.person_outline),
            label: const Text('Ver experiencia de cliente'),
          ),

          const SizedBox(height: 12),

          // Botón de Cerrar Sesión funcionando al 100%
          OutlinedButton.icon(
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                    '¿Estás seguro de que deseas salir de tu cuenta de secretaria?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );

              if (confirmar != true) return;

              await FirebaseAuth.instance.signOut();
              ClientService.limpiarCache();
              if (!context.mounted) return;

              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _icon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E9FC),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: AppTheme.violet),
    );
  }

  static Widget _option(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget destination,
  ) {
    return ListTile(
      leading: _icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      ),
    );
  }
}
