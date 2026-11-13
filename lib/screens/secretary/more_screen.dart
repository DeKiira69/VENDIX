import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/client_service.dart';
import '../../services/perfil_foto_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../client/client_shell.dart';
import 'clothing_prices_screen.dart';
import 'jornadas_screen.dart';
import 'payments_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  static String _generarCodigoLive() {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const numeros = '23456789';
    final rnd = Random();
    final prefijo = String.fromCharCodes(
      Iterable.generate(3, (_) => letras.codeUnitAt(rnd.nextInt(letras.length))),
    );
    final sufijo = String.fromCharCodes(
      Iterable.generate(3, (_) => numeros.codeUnitAt(rnd.nextInt(numeros.length))),
    );
    return '$prefijo-$sufijo';
  }

  static Future<void> _generarOGuardarCodigo(
    BuildContext context,
    String uid,
  ) async {
    if (uid.isEmpty) return;
    final nuevoCodigo = _generarCodigoLive();
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    batch.set(db.collection('secretarios').doc(uid), {
      'codigoLive': nuevoCodigo,
      'codigoActualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(db.collection('usuarios').doc(uid), {
      'codigoLive': nuevoCodigo,
    }, SetOptions(merge: true));

    await batch.commit();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código de Live generado: $nuevoCodigo'),
        backgroundColor: AppTheme.violet,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final usuarioId = usuario?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioId)
          .snapshots(),
      builder: (context, snap) {
        final datos = snap.data?.data() as Map<String, dynamic>?;
        final nombre = datos?['nombre']?.toString() ?? '';
        final apellido = datos?['apellido']?.toString() ?? '';
        final nombreMostrar = [nombre, apellido]
            .where((s) => s.isNotEmpty)
            .join(' ')
            .trim();
        final nombreFinal = nombreMostrar.isNotEmpty
            ? nombreMostrar
            : (usuario?.displayName ?? usuario?.email ?? 'Secretario');
        final iniciales = nombreFinal
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
                      context: context,
                      fotoData: snapshot.data,
                      iniciales: iniciales.isEmpty ? '?' : iniciales,
                      nombreUsuario: nombreFinal,
                      rolUsuario: 'Secretaria',
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
                        nombreFinal,
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

          // Tarjeta de Código de Acceso para el Live
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('secretarios')
                .doc(usuarioId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final codigoActual = data?['codigoLive']?.toString() ?? '';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: codigoActual.isNotEmpty
                        ? AppTheme.violet.withValues(alpha: 0.4)
                        : AppTheme.border,
                    width: codigoActual.isNotEmpty ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E9FC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.vpn_key_outlined,
                            size: 16,
                            color: AppTheme.violet,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'CÓDIGO DE ACCESO PARA EL LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.violet,
                          ),
                        ),
                        const Spacer(),
                        if (codigoActual.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.pinkAccent, size: 7),
                                SizedBox(width: 4),
                                Text(
                                  'ACTIVO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (codigoActual.isEmpty) ...[
                      const Text(
                        'Genera un código único para que tus clientas puedan registrarse en la app durante tu transmisión en vivo.',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _generarOGuardarCodigo(context, usuarioId),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Generar código del Live'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.violet,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Código actual para tus clientas:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                codigoActual,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.5,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: codigoActual),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Código copiado al portapapeles'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copiar código',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1EAFE),
                                  foregroundColor: AppTheme.violet,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton.outlined(
                                onPressed: () async {
                                  final confirmar = await showDialog<bool>(
                                    context: context,
                                    builder: (dlgCtx) => AlertDialog(
                                      title: const Text('¿Regenerar código?'),
                                      content: const Text(
                                        'Se generará un nuevo código. Las clientas necesitarán el nuevo código para registrarse.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dlgCtx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dlgCtx, true),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppTheme.violet,
                                          ),
                                          child: const Text('Regenerar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmar == true && context.mounted) {
                                    await _generarOGuardarCodigo(context, usuarioId);
                                  }
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: 'Generar nuevo código',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
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

          // Botón para alternar a modo Cliente
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ClientShell()),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: const Color(0xFF6C4AB6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.person_outline, color: Colors.white),
            label: const Text('Cambiar a modo Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
      }, // cierre builder StreamBuilder datos
    ); // cierre StreamBuilder datos
  } // cierre build

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
