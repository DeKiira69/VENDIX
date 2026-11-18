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
import '../client/client_welcome_hub_screen.dart';
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
    final adminId = ClientService.activeSecretaryAdminId ?? '';

    final docId = adminId.isNotEmpty ? '${uid}_$adminId' : uid;

    batch.set(db.collection('secretarios').doc(docId), {
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

  Future<void> _renunciarEmprendimiento({
    required BuildContext context,
    required String usuarioId,
    required String adminId,
    required String nombreEmprendimiento,
    required List<QueryDocumentSnapshot> todosLosEmpleos,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Text('Renunciar al empleo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas dejar de ser secretario en "$nombreEmprendimiento"?\n\n'
          'Ya no tendrás acceso a las ventas ni administración de esta tienda. Tu cuenta de VENDIX, tus compras y otros empleos no se verán afectados.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sí, renunciar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final lote = db.batch();

      // 1. Actualizar doc en secretarios
      final docSecretarioRef = db.collection('secretarios').doc('${usuarioId}_$adminId');
      final docSecretario = await docSecretarioRef.get();

      if (docSecretario.exists) {
        lote.update(docSecretarioRef, {
          'estado': false,
          'aprobado': false,
          'estado_solicitud': 'renunciado',
          'fecha_renuncia': FieldValue.serverTimestamp(),
        });
      } else {
        final q = await db
            .collection('secretarios')
            .where('clienteId', isEqualTo: usuarioId)
            .where('adminId', isEqualTo: adminId)
            .get();
        for (final d in q.docs) {
          lote.update(d.reference, {
            'estado': false,
            'aprobado': false,
            'estado_solicitud': 'renunciado',
            'fecha_renuncia': FieldValue.serverTimestamp(),
          });
        }
      }

      // 2. Actualizar en subcolección mis_empleos del usuario
      lote.set(
        db.collection('usuarios').doc(usuarioId).collection('mis_empleos').doc(adminId),
        {
          'estado': 'renunciado',
          'aprobado': false,
          'fecha_renuncia': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 3. Revisar si quedan otros empleos activos
      final otrosEmpleos = todosLosEmpleos.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['adminId'] != adminId &&
            (data['aprobado'] == true || data['estado'] == true) &&
            data['estado_solicitud'] != 'renunciado';
      }).toList();

      if (otrosEmpleos.isEmpty) {
        lote.update(db.collection('usuarios').doc(usuarioId), {
          'rol': 'cliente',
        });
      }

      await lote.commit();

      if (!context.mounted) return;

      if (otrosEmpleos.isNotEmpty) {
        final siguiente = otrosEmpleos.first.data() as Map<String, dynamic>;
        final sigAdminId = siguiente['adminId']?.toString() ?? '';
        final sigEmp = siguiente['nombreEmprendimiento']?.toString() ?? 'Otro emprendimiento';
        final sigAdminNom = siguiente['adminNombre']?.toString() ?? '';

        ClientService.setActiveSecretarySession(
          adminId: sigAdminId,
          nombreEmprendimiento: sigEmp,
          adminNombre: sigAdminNom,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Has renunciado a $nombreEmprendimiento. Ahora estás en $sigEmp.'),
            backgroundColor: AppTheme.violet,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ClientService.limpiarCache();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Has dejado de ser secretario de $nombreEmprendimiento.'),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ClientWelcomeHubScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar la renuncia: $e')),
      );
    }
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('secretarios')
            .where('clienteId', isEqualTo: usuarioId)
            .where('aprobado', isEqualTo: true)
            .snapshots(),
        builder: (context, snapEmpleos) {
          final empleosDocs = snapEmpleos.data?.docs ?? [];

          String adminIdActivo = ClientService.activeSecretaryAdminId ?? '';
          String nombreEmprendimientoActivo =
              ClientService.activeSecretaryNombreEmprendimiento ?? '';
          String adminNombreActivo =
              ClientService.activeSecretaryAdminNombre ?? '';
          String codigoLiveActivo = '';

          if (empleosDocs.isNotEmpty) {
            QueryDocumentSnapshot? docActivo;
            if (adminIdActivo.isNotEmpty) {
              docActivo = empleosDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['adminId'] == adminIdActivo;
              }).firstOrNull;
            }
            docActivo ??= empleosDocs.first;

            final dataActiva = docActivo.data() as Map<String, dynamic>;
            adminIdActivo = dataActiva['adminId']?.toString() ?? adminIdActivo;
            nombreEmprendimientoActivo =
                dataActiva['nombreEmprendimiento']?.toString() ??
                    (nombreEmprendimientoActivo.isNotEmpty
                        ? nombreEmprendimientoActivo
                        : 'Emprendimiento');
            adminNombreActivo = dataActiva['adminNombre']?.toString() ??
                (adminNombreActivo.isNotEmpty
                    ? adminNombreActivo
                    : 'Emprendedor Propietario');
            codigoLiveActivo = dataActiva['codigoLive']?.toString() ?? '';

            ClientService.setActiveSecretarySession(
              adminId: adminIdActivo,
              nombreEmprendimiento: nombreEmprendimientoActivo,
              adminNombre: adminNombreActivo,
            );
          }

          return ListView(
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
              const SizedBox(height: 20),

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
                          iniciales: iniciales.isEmpty ? '?' : iniciales,
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
                            usuario?.email ?? 'Secretario · Operador de ventas',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Tarjeta del Emprendimiento y Emprendedor Activo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E9FC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 18,
                            color: AppTheme.violet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EMPRENDIMIENTO ACTIVO',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.violet,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nombreEmprendimientoActivo.isNotEmpty
                                    ? nombreEmprendimientoActivo
                                    : 'Sin emprendimiento asignado',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                adminNombreActivo.isNotEmpty
                                    ? 'Emprendedor: $adminNombreActivo'
                                    : 'Emprendedor Propietario',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (empleosDocs.length > 1)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              side: const BorderSide(color: AppTheme.violet),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _mostrarSelectorCambioTienda(
                                context,
                                empleosDocs,
                              );
                            },
                            child: const Text(
                              'Cambiar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.violet,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Tarjeta de Código de Acceso para el Live
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: codigoLiveActivo.isNotEmpty
                        ? AppTheme.violet.withValues(alpha: 0.4)
                        : AppTheme.border,
                    width: codigoLiveActivo.isNotEmpty ? 1.5 : 1,
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
                        if (codigoLiveActivo.isNotEmpty)
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
                                Icon(
                                  Icons.circle,
                                  color: Colors.pinkAccent,
                                  size: 7,
                                ),
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
                    if (codigoLiveActivo.isEmpty) ...[
                      const Text(
                        'Genera un código único para que tus clientas puedan registrarse en la app durante tu transmisión en vivo.',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              _generarOGuardarCodigo(context, usuarioId),
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
                                codigoLiveActivo,
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
                                    ClipboardData(text: codigoLiveActivo),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Código copiado al portapapeles',
                                      ),
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
                                    await _generarOGuardarCodigo(
                                      context,
                                      usuarioId,
                                    );
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
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── Botón Renunciar / Desvincularse del Emprendimiento (Requerimiento 2) ───
              if (adminIdActivo.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _renunciarEmprendimiento(
                        context: context,
                        usuarioId: usuarioId,
                        adminId: adminIdActivo,
                        nombreEmprendimiento: nombreEmprendimientoActivo,
                        todosLosEmpleos: empleosDocs,
                      );
                    },
                    icon: const Icon(
                      Icons.work_off_outlined,
                      color: Color(0xFFD32F2F),
                      size: 20,
                    ),
                    label: const Text(
                      'Dejar de ser secretario de este emprendimiento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.red.shade300,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
                    ),
                  ),
                ),

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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.person_outline, color: Colors.white),
                label: const Text(
                  'Cambiar a modo Cliente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Botón de Cerrar Sesión
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
          );
        },
      ),
    );
      }, // cierre builder StreamBuilder datos
    ); // cierre StreamBuilder datos
  } // cierre build

  void _mostrarSelectorCambioTienda(
    BuildContext context,
    List<QueryDocumentSnapshot> empleos,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cambiar Emprendimiento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona el emprendimiento para el cual operarás:',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              ...empleos.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final emp = data['nombreEmprendimiento']?.toString() ??
                    data['adminNombre']?.toString() ??
                    'Emprendimiento';
                final adminNom = data['adminNombre']?.toString() ?? '';
                final adminId = data['adminId']?.toString() ?? '';
                final esActivo =
                    adminId == ClientService.activeSecretaryAdminId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esActivo
                        ? AppTheme.violet
                        : const Color(0xFFF0E9FC),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: esActivo ? Colors.white : AppTheme.violet,
                    ),
                  ),
                  title: Text(
                    emp,
                    style: TextStyle(
                      fontWeight:
                          esActivo ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text('Propietario: $adminNom'),
                  trailing: esActivo
                      ? const Icon(Icons.check_circle, color: AppTheme.violet)
                      : null,
                  onTap: () {
                    ClientService.setActiveSecretarySession(
                      adminId: adminId,
                      nombreEmprendimiento: emp,
                      adminNombre: adminNom,
                    );
                    Navigator.pop(sheetCtx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cambiado a $emp'),
                        backgroundColor: AppTheme.violet,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
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
