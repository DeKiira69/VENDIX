import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/administrador_model.dart';
import '../../services/client_service.dart';
import '../../services/perfil_foto_service.dart';
import '../auth/login_screen.dart';

/// Pantalla de Perfil para el Emprendedor (Administrador).
/// Permite ver y editar datos personales, cambiar la foto de perfil
/// (Cámara, Galería o Enlace con Cloudinary), revisar resumen de la cuenta
/// y cerrar sesión.
class AdminProfileScreen extends StatefulWidget {
  final AdministradorModel admin;

  const AdminProfileScreen({super.key, required this.admin});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const violeta = Color(0xFF6C4AB6);
  static const violetaOscuro = Color(0xFF56349D);
  static const violetaClaro = Color(0xFF7650BC);
  static const textoOscuro = Color(0xFF241B35);
  static const textoGris = Color(0xFF81798D);

  /// Muestra el modal para editar nombre, apellido y teléfono del emprendedor.
  void _mostrarModalEditarDatos({
    required String nombreActual,
    required String apellidoActual,
    required String telefonoActual,
  }) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: nombreActual);
    final apellidoCtrl = TextEditingController(text: apellidoActual);
    final telefonoCtrl = TextEditingController(text: telefonoActual);
    bool guardando = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 26,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Editar datos del perfil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Actualiza tu información personal como emprendedor',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textoGris),
                      ),
                      const SizedBox(height: 22),

                      // Campo Nombre
                      const Text(
                        'Nombre',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textoOscuro),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nombreCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecor('Tu nombre', Icons.person_outline),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                      ),
                      const SizedBox(height: 14),

                      // Campo Apellido
                      const Text(
                        'Apellido',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textoOscuro),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: apellidoCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecor('Tu apellido', Icons.badge_outlined),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa tu apellido' : null,
                      ),
                      const SizedBox(height: 14),

                      // Campo Teléfono
                      const Text(
                        'Teléfono / Celular',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textoOscuro),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecor('Ej. 0991234567', Icons.phone_outlined),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                      ),
                      const SizedBox(height: 24),

                      // Botón Guardar
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: violeta,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: guardando
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => guardando = true);

                                  final uid = widget.admin.id;
                                  final nuevoNombre = nombreCtrl.text.trim();
                                  final nuevoApellido = apellidoCtrl.text.trim();
                                  final nuevoTelefono = telefonoCtrl.text.trim();

                                  try {
                                    final db = FirebaseFirestore.instance;
                                    final batch = db.batch();

                                    final actualizacion = {
                                      'nombre': nuevoNombre,
                                      'apellido': nuevoApellido,
                                      'telefono': nuevoTelefono,
                                      'actualizadoEn': FieldValue.serverTimestamp(),
                                    };

                                    // Sincronizar en Administradores y en usuarios
                                    batch.set(
                                      db.collection('Administradores').doc(uid),
                                      actualizacion,
                                      SetOptions(merge: true),
                                    );
                                    batch.set(
                                      db.collection('usuarios').doc(uid),
                                      actualizacion,
                                      SetOptions(merge: true),
                                    );

                                    await batch.commit();

                                    // Actualizar displayName en FirebaseAuth si es posible
                                    try {
                                      await FirebaseAuth.instance.currentUser
                                          ?.updateDisplayName('$nuevoNombre $nuevoApellido'.trim());
                                    } catch (_) {}

                                    if (!modalCtx.mounted) return;
                                    Navigator.pop(modalCtx);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Perfil actualizado correctamente'),
                                          backgroundColor: Color(0xFF15966B),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => guardando = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error al actualizar: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: guardando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Guardar Cambios',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Envía un correo electrónico para restablecer la contraseña.
  Future<void> _restablecerContrasena(String email) async {
    if (email.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cambiar contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Se enviará un correo con un enlace seguro a:\n\n'
          '📧 $email\n\n'
          'Sigue las instrucciones del correo para definir tu nueva contraseña.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: violeta),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Enviar correo'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo de restablecimiento enviado. Revisa tu bandeja.'),
            backgroundColor: Color(0xFF15966B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar correo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cierra la sesión activa con confirmación.
  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cerrar sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta de Emprendedor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await FirebaseAuth.instance.signOut();
    ClientService.limpiarCache();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  InputDecoration _inputDecor(String hint, IconData icono) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icono, color: violeta, size: 20),
      filled: true,
      fillColor: const Color(0xFFFAF8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: violeta, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.admin.id;

    // Escuchar el documento del admin en Firestore para mantener datos en tiempo real
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Administradores').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final nombre = data['nombre']?.toString() ?? widget.admin.nombre;
        final apellido = data['apellido']?.toString() ?? widget.admin.apellido;
        final nombreCompleto = '$nombre $apellido'.trim().isEmpty
            ? (widget.admin.nombreCompleto.isEmpty ? 'Emprendedor' : widget.admin.nombreCompleto)
            : '$nombre $apellido'.trim();
        final email = data['correo']?.toString() ??
            (FirebaseAuth.instance.currentUser?.email ?? widget.admin.correo);
        final telefono = data['telefono']?.toString() ?? widget.admin.telefono;

        final iniciales = nombreCompleto
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            // ─── Top Bar ───
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PANEL DE EMPRENDEDOR',
                  style: TextStyle(
                    color: violeta,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Mi Perfil',
                  style: TextStyle(
                    color: textoOscuro,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Tarjeta Principal de Perfil con Foto Interactiva ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [violetaOscuro, violetaClaro],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: violeta.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar con insignia interactiva para cambiar foto
                  StreamBuilder<String?>(
                    stream: PerfilFotoService.fotoStream(uid),
                    builder: (context, fotoSnap) {
                      return PerfilFotoService.avatarConInsignia(
                        fotoData: fotoSnap.data,
                        iniciales: iniciales.isEmpty ? 'AD' : iniciales,
                        radio: 42,
                        onTap: () {
                          PerfilFotoService.mostrarOpcionesFotoWhatsApp(
                            context: context,
                            usuarioId: uid,
                            fotoActual: fotoSnap.data,
                            rol: 'administrador',
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Nombre
                  Text(
                    nombreCompleto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Badge de Rol
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 16),
                        SizedBox(width: 5),
                        Text(
                          'Emprendedor / Administrador',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Correo y Teléfono
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.white70, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        email.isEmpty ? 'Sin correo' : email,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  if (telefono.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_outlined, color: Colors.white70, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          telefono,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Botón "Editar Datos"
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _mostrarModalEditarDatos(
                          nombreActual: nombre,
                          apellidoActual: apellido,
                          telefonoActual: telefono,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'Editar mis datos',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ─── Resumen de mi Negocio ───
            const Text(
              'Resumen del Negocio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textoOscuro,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Cantidad de Secretarios a su cargo
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('secretarios')
                        .where('adminId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return _buildStatCard(
                        titulo: 'Secretarios',
                        valor: '$count',
                        subtitulo: 'A tu cargo',
                        icono: Icons.badge_outlined,
                        color: violeta,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Clientes vinculados a este admin
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clientes')
                        .where('adminId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return _buildStatCard(
                        titulo: 'Clientas',
                        valor: '$count',
                        subtitulo: 'Vinculadas',
                        icono: Icons.people_outline,
                        color: const Color(0xFF15966B),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Opciones de Cuenta y Configuración ───
            const Text(
              'Cuenta y Seguridad',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textoOscuro,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECE6F2)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: violeta, size: 20),
                    ),
                    title: const Text(
                      'Cambiar foto de perfil',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Cámara, galería o enlace web',
                      style: TextStyle(fontSize: 12, color: textoGris),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: textoGris),
                    onTap: () {
                      PerfilFotoService.mostrarOpcionesFotoWhatsApp(
                        context: context,
                        usuarioId: uid,
                        rol: 'administrador',
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 20, color: Color(0xFFF0EBF5)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_reset_outlined, color: violeta, size: 20),
                    ),
                    title: const Text(
                      'Restablecer contraseña',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Recibir enlace seguro en tu correo',
                      style: TextStyle(fontSize: 12, color: textoGris),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: textoGris),
                    onTap: () => _restablecerContrasena(email),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Botón Cerrar Sesión ───
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE6F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textoGris,
                ),
              ),
              Icon(icono, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 11, color: textoGris),
          ),
        ],
      ),
    );
  }
}
