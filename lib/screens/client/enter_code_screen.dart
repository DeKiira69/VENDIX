import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/client_service.dart';
import '../../services/invitation_code_service.dart';
import 'client_shell.dart';

/// Pantalla que se muestra cuando el cliente ya se registró pero aún
/// no tiene un código de Live vinculado. Es OBLIGATORIA — no se puede
/// saltar. El usuario debe ingresar un código válido de un secretario
/// o cerrar sesión y usar otra cuenta.
class EnterCodeScreen extends StatefulWidget {
  final String? codigoInicial;

  const EnterCodeScreen({super.key, this.codigoInicial});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _codigoCtrl = TextEditingController();
  bool _cargando = false;

  static const violeta = Color(0xFF6C4AB6);
  static const rosa = Color(0xFFE9A6C8);

  @override
  void initState() {
    super.initState();
    final inicial = widget.codigoInicial;
    if (inicial != null && inicial.trim().isNotEmpty) {
      _codigoCtrl.text = InvitationCodeService.extraerCodigoDeEntrada(inicial);
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _vincularCodigo() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigoCtrl.text.trim().toUpperCase();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el código del Live para continuar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) throw Exception('No hay sesión activa.');

      // Validar código contra 'secretarios' y, si no existe allí, contra 'Administradores'
      final querySec = await db
          .collection('secretarios')
          .where('codigoLive', isEqualTo: codigo)
          .limit(1)
          .get();

      String adminId = '';
      String secretarioId = '';
      String nombreEmprendimiento = '';
      String adminNombre = '';

      if (querySec.docs.isNotEmpty) {
        final dataSec = querySec.docs.first.data();
        secretarioId = querySec.docs.first.id;

        // Resolver adminId de forma ultra-robusta para evitar errores de ruta vacía
        adminId = dataSec['adminId']?.toString().trim() ?? '';
        if (adminId.isEmpty && dataSec['administradorId'] != null) {
          adminId = dataSec['administradorId'].toString().trim();
        }
        if (adminId.isEmpty && secretarioId.contains('_')) {
          adminId = secretarioId.split('_').last.trim();
        }
        if (adminId.isEmpty) {
          final secUid =
              dataSec['clienteId']?.toString() ?? dataSec['uid']?.toString() ?? '';
          if (secUid.isNotEmpty) {
            try {
              final userDoc = await db.collection('usuarios').doc(secUid).get();
              adminId = userDoc.data()?['adminId']?.toString().trim() ?? '';
            } catch (_) {}
          }
        }

        nombreEmprendimiento =
            dataSec['nombreEmprendimiento']?.toString().trim() ?? '';
        adminNombre = dataSec['adminNombre']?.toString().trim() ?? '';
      } else {
        final queryAdmin = await db
            .collection('Administradores')
            .where('codigoLive', isEqualTo: codigo)
            .limit(1)
            .get();

        if (queryAdmin.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Código no válido o no activo. Pídelo al emprendedor o al operador durante el Live.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
            setState(() => _cargando = false);
          }
          return;
        }

        final adminDocFound = queryAdmin.docs.first;
        final adminData = adminDocFound.data();
        adminId = adminDocFound.id;
        nombreEmprendimiento =
            adminData['nombreEmprendimiento']?.toString().trim() ??
            adminData['negocio']?.toString().trim() ??
            '';
        final nom = adminData['nombre']?.toString().trim() ?? '';
        final ape = adminData['apellido']?.toString().trim() ?? '';
        adminNombre = [nom, ape].where((s) => s.isNotEmpty).join(' ');
      }

      // Completar datos del emprendimiento desde Administradores si hace falta
      if (adminId.isNotEmpty &&
          (nombreEmprendimiento.isEmpty || adminNombre.isEmpty)) {
        try {
          final adminDoc = await db.collection('Administradores').doc(adminId).get();
          if (adminDoc.exists) {
            final adminData = adminDoc.data() ?? {};
            final nombreTienda = adminData['nombreEmprendimiento']?.toString().trim() ??
                adminData['negocio']?.toString().trim() ?? '';
            if (nombreEmprendimiento.isEmpty && nombreTienda.isNotEmpty) {
              nombreEmprendimiento = nombreTienda;
            }
            final nom = adminData['nombre']?.toString().trim() ?? '';
            final ape = adminData['apellido']?.toString().trim() ?? '';
            final nombreCompleto = [nom, ape].where((s) => s.isNotEmpty).join(' ');
            if (adminNombre.isEmpty && nombreCompleto.isNotEmpty) {
              adminNombre = nombreCompleto;
            }
          }
        } catch (_) {}
      }

      if (nombreEmprendimiento.isEmpty) {
        nombreEmprendimiento = 'Tienda en Vivo';
      }

      final actualizacion = {
        'adminId': adminId,
        'secretarioId': secretarioId,
        'codigoLive': codigo,
      };

      // Guardar vínculo en usuarios, clientes Y mis_tiendas con merge seguro
      final lote = db.batch();
      lote.set(
        db.collection('usuarios').doc(uid),
        actualizacion,
        SetOptions(merge: true),
      );
      lote.set(
        db.collection('clientes').doc(uid),
        actualizacion,
        SetOptions(merge: true),
      );

      // Usar adminId si existe, o secretarioId como clave para la subcolección
      final claveTienda = adminId.isNotEmpty ? adminId : secretarioId;
      if (claveTienda.isNotEmpty) {
        lote.set(
          db.collection('usuarios').doc(uid).collection('mis_tiendas').doc(claveTienda),
          {
            'adminId': adminId.isNotEmpty ? adminId : claveTienda,
            'nombreEmprendimiento': nombreEmprendimiento,
            'adminNombre': adminNombre,
            'codigoLive': codigo,
            'secretarioId': secretarioId,
            'fecha_asociacion': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await lote.commit();
      ClientService.limpiarCache();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ClientShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Se cerrará tu sesión y volverás a la pantalla de inicio. '
          'Cuando vuelvas a entrar, deberás ingresar el código del Live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: violeta),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    // Reiniciar la app volviendo a la pantalla de inicio
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.canPop(context);

    return PopScope(
      canPop: puedeVolver,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8FC),
        appBar: puedeVolver
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF241B35)),
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Volver al menú principal',
                ),
                title: const Text(
                  'Asociarse a tienda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241B35),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono con degradado
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [violeta, rosa],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: violeta.withValues(alpha: 0.28),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      '¡Un paso más! 🛍️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF241B35),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Para ver las ventas en vivo necesitas vincularte con tu operador. '
                      'Pídele el código durante la transmisión en vivo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF81798D),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tarjeta del campo de código
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFECE6F2)),
                        boxShadow: [
                          BoxShadow(
                            color: violeta.withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.vpn_key_outlined, size: 16, color: violeta),
                              SizedBox(width: 6),
                              Text(
                                'CÓDIGO DEL LIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: violeta,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _codigoCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              fontSize: 22,
                              color: violeta,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'VX-849',
                              hintStyle: const TextStyle(
                                letterSpacing: 2,
                                fontSize: 18,
                                color: Color(0xFFCDC6DA),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF1EAFE),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: violeta, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _cargando ? null : _vincularCodigo,
                              style: FilledButton.styleFrom(
                                backgroundColor: violeta,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _cargando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Vincularme y Entrar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _cargando ? null : _cerrarSesion,
                      child: const Text(
                        'Cerrar sesión e iniciar con otra cuenta',
                        style: TextStyle(
                          color: Color(0xFF81798D),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
