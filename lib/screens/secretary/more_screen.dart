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
import '../../widgets/reports/export_report_dialog.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _opcionesCuentaExpandidas = false;

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

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const Text(
                  'Más opciones',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Tarjeta de la secretaria con Avatar interactivo estilo WhatsApp
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF56349D), Color(0xFF7650BC)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      StreamBuilder<String?>(
                        stream: PerfilFotoService.fotoStream(usuarioId),
                        builder: (context, snapshot) {
                          return PerfilFotoService.avatarConInsignia(
                            fotoData: snapshot.data,
                            iniciales: iniciales.isEmpty ? '?' : iniciales,
                            radio: 22,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreFinal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              usuario?.email ?? 'Secretario · Operador de ventas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

                const SizedBox(height: 8),

                // Tarjeta del Emprendimiento y Emprendedor Activo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E9FC),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 16,
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
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.violet,
                              ),
                            ),
                            Text(
                              nombreEmprendimientoActivo.isNotEmpty
                                  ? nombreEmprendimientoActivo
                                  : 'Sin emprendimiento asignado',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.dark,
                              ),
                            ),
                            Text(
                              adminNombreActivo.isNotEmpty
                                  ? 'Emprendedor: $adminNombreActivo'
                                  : 'Emprendedor Propietario',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: AppTheme.violet),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
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
                ),

                const SizedBox(height: 8),

                // Tarjeta de Código de Acceso para el Live (SOLO LECTURA Y COPIA)
                StreamBuilder<DocumentSnapshot>(
                  stream: adminIdActivo.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('Administradores')
                          .doc(adminIdActivo)
                          .snapshots()
                      : null,
                  builder: (context, adminSnap) {
                    final adminData =
                        adminSnap.data?.data() as Map<String, dynamic>?;
                    final codigoAdmin =
                        adminData?['codigoLive']?.toString().trim() ?? '';
                    final codigoMostrar = codigoAdmin.isNotEmpty
                        ? codigoAdmin
                        : codigoLiveActivo;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: codigoMostrar.isNotEmpty
                              ? AppTheme.violet.withValues(alpha: 0.35)
                              : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0E9FC),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.vpn_key_outlined,
                              size: 16,
                              color: AppTheme.violet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CÓDIGO DE ACCESO PARA EL LIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.violet,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (codigoMostrar.isNotEmpty)
                                  Text(
                                    codigoMostrar,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                      color: AppTheme.violet,
                                    ),
                                  )
                                else
                                  const Text(
                                    'El administrador aún no genera el código.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (codigoMostrar.isNotEmpty)
                            IconButton.filledTonal(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: codigoMostrar),
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
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              tooltip: 'Copiar código',
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1EAFE),
                                foregroundColor: AppTheme.violet,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Accesos operativos principales
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(15),
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

                const SizedBox(height: 8),

                // Lista desplegable agrupada (contraída inicialmente)
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            setState(() {
                              _opcionesCuentaExpandidas =
                                  !_opcionesCuentaExpandidas;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0E9FC),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: AppTheme.violet,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Opciones de cuenta y reportes',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.dark,
                                        ),
                                      ),
                                      Text(
                                        'Modo cliente, reportes y desvinculación',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _opcionesCuentaExpandidas
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.violet,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_opcionesCuentaExpandidas) ...[
                          const Divider(height: 1, color: AppTheme.border),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF6C4AB6),
                                      size: 20,
                                    ),
                                    title: const Text(
                                      'Cambiar a modo Cliente',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                    ),
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (_) => const ClientShell(),
                                        ),
                                        (route) => false,
                                      );
                                    },
                                  ),
                                  const Divider(
                                    height: 1,
                                    color: AppTheme.border,
                                  ),
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(
                                      Icons.table_chart_outlined,
                                      color: Color(0xFF2E7D32),
                                      size: 20,
                                    ),
                                    title: const Text(
                                      'Exportar reportes operativos',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                    ),
                                    onTap: () {
                                      ExportReportDialog.mostrar(context);
                                    },
                                  ),
                                  if (adminIdActivo.isNotEmpty) ...[
                                    const Divider(
                                      height: 1,
                                      color: AppTheme.border,
                                    ),
                                    ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      leading: const Icon(
                                        Icons.work_off_outlined,
                                        color: Color(0xFFD32F2F),
                                        size: 20,
                                      ),
                                      title: const Text(
                                        'Dejar de ser secretario',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD32F2F),
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: Color(0xFFD32F2F),
                                      ),
                                      onTap: () {
                                        _renunciarEmprendimiento(
                                          context: context,
                                          usuarioId: usuarioId,
                                          adminId: adminIdActivo,
                                          nombreEmprendimiento:
                                              nombreEmprendimientoActivo,
                                          todosLosEmpleos: empleosDocs,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                if (!_opcionesCuentaExpandidas) const Spacer(),

                // Botón de Cerrar Sesión siempre visible fuera de la lista desplegable
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

                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E9FC),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: AppTheme.violet, size: 18),
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
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: _icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10.5)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      ),
    );
  }
}
