import 'package:cloud_firestore/cloud_firestore.dart';
import '../secretary/secretary_shell.dart';
import 'solicitud_empleo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/client_service.dart';
import '../../services/perfil_foto_service.dart';
import '../auth/login_screen.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

  static const Color violeta = Color(0xFF7950C2);

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: ClientService.clienteActual(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar tu perfil.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cliente = snapshot.data;
          if (cliente == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu cuenta todavía no está vinculada a una ficha de cliente. '
                  'Comunícate con la tienda para completar el registro.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final nombre = (cliente['nombre'] ?? 'Cliente').toString();
          final telefono = (cliente['telefono'] ?? 'Sin teléfono').toString();
          final direccion = (cliente['direccion'] ?? 'Sin dirección').toString();
          final usuarioId = usuario?.uid ?? cliente['id']?.toString() ?? '';

          final iniciales = nombre
              .trim()
              .split(RegExp(r'\s+'))
              .where((parte) => parte.isNotEmpty)
              .take(2)
              .map((parte) => parte[0])
              .join()
              .toUpperCase();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              const Text(
                'CUENTA DE CLIENTE',
                style: TextStyle(
                  color: violeta,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mi perfil',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Tarjeta principal con avatar interactivo estilo WhatsApp
              Container(
                padding: const EdgeInsets.all(24),
                decoration: _tarjeta(),
                child: Column(
                  children: [
                    StreamBuilder<String?>(
                      stream: PerfilFotoService.fotoStream(usuarioId),
                      builder: (context, fotoSnap) {
                        final foto = fotoSnap.data ?? cliente['fotoBase64']?.toString();

                        return PerfilFotoService.avatarConInsignia(
                          context: context,
                          fotoData: foto,
                          iniciales: iniciales.isEmpty ? 'C' : iniciales,
                          nombreUsuario: nombre,
                          rolUsuario: 'Cliente',
                          radio: 38,
                          onTap: () {
                            PerfilFotoService.mostrarOpcionesFotoWhatsApp(
                              context: context,
                              usuarioId: usuarioId,
                              fotoActual: foto,
                              rol: 'cliente',
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      telefono,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (direccion.isNotEmpty && direccion != 'Sin dirección') ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              direccion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Opciones del perfil
              Container(
                decoration: _tarjeta(),
                child: Column(
                  children: [
                    _dato(
                      icono: Icons.person_outline,
                      titulo: 'Datos personales',
                      subtitulo: '$nombre · $telefono',
                      onTap: () => _abrirFormularioDatos(context, cliente),
                    ),
                    const Divider(height: 1),
                    _dato(
                      icono: Icons.email_outlined,
                      titulo: 'Correo electrónico',
                      subtitulo: usuario?.email ?? 'No disponible',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── Gestión Laboral: Trabajar como Secretario ──
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('secretarios')
                    .where('clienteId', isEqualTo: usuarioId)
                    .where('aprobado', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapEmpleos) {
                  final empleos = snapEmpleos.data?.docs ?? [];

                  if (empleos.isNotEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: violeta,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.badge_outlined, color: Colors.white),
                        label: Text(
                          empleos.length > 1
                              ? 'Cambiar a modo Secretario ( empleos)'
                              : 'Cambiar a modo Secretario',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          if (empleos.length == 1) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const SecretaryShell()),
                            );
                          } else {
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
                                        'Selecciona el Emprendimiento',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        '¿Para cuál de tus emprendedores trabajarás en esta sesión?',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF81798D)),
                                      ),
                                      const SizedBox(height: 14),
                                      ...empleos.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final emp = data['nombreEmprendimiento']?.toString() ??
                                            data['adminNombre']?.toString() ??
                                            'Emprendedor';
                                        return ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFFF0E8FC),
                                            child: Icon(Icons.storefront_outlined, color: violeta),
                                          ),
                                          title: Text(emp, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Código: '),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                          onTap: () {
                                            Navigator.pop(sheetCtx);
                                            Navigator.of(context).pushReplacement(
                                              MaterialPageRoute(builder: (_) => const SecretaryShell()),
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
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Botón para Solicitar Empleo / Postularse con Emprendedores
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SolicitudEmpleoScreen()),
                    );
                  },
                  icon: const Icon(Icons.work_outline, color: violeta),
                  label: const Text(
                    'Trabajar como Secretario (Postularse)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: violeta),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFD6C4F4)),
                    backgroundColor: const Color(0xFFFAF7FD),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

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
                        '¿Estás seguro de que deseas salir de tu cuenta?',
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
  }

  static Widget _dato({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF0E8FC),
        child: Icon(icono, color: violeta),
      ),
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text(
        subtitulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static BoxDecoration _tarjeta() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFECE6F0)),
  );

  static void _abrirFormularioDatos(
    BuildContext context,
    Map<String, dynamic> cliente,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioDatosPersonalesModal(cliente: cliente),
    );
  }
}

class _FormularioDatosPersonalesModal extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const _FormularioDatosPersonalesModal({required this.cliente});

  @override
  State<_FormularioDatosPersonalesModal> createState() =>
      _FormularioDatosPersonalesModalState();
}

class _FormularioDatosPersonalesModalState
    extends State<_FormularioDatosPersonalesModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _direccionController;

  final FocusNode _nombreFocus = FocusNode();
  bool _estaEditando = false;
  bool _guardando = false;

  static const Color violeta = Color(0xFF7950C2);

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.cliente['nombre']?.toString() ?? '',
    );
    _telefonoController = TextEditingController(
      text: widget.cliente['telefono']?.toString() ?? '',
    );
    _direccionController = TextEditingController(
      text: widget.cliente['direccion']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _nombreFocus.dispose();
    super.dispose();
  }

  void _activarEdicion() {
    setState(() {
      _estaEditando = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _nombreFocus.requestFocus();
      }
    });
  }

  Future<void> _guardarDatos() async {
    if (!_formKey.currentState!.validate()) return;

    final clienteId = widget.cliente['id']?.toString();
    if (clienteId == null || clienteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el identificador del cliente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      await ClientService.actualizarCliente(
        clienteId: clienteId,
        nombre: _nombreController.text,
        telefono: _telefonoController.text,
        direccion: _direccionController.text,
      );

      if (!mounted) return;

      setState(() {
        _guardando = false;
        _estaEditando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos personales guardados correctamente'),
          backgroundColor: Color(0xFF15966B),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior de arrastre
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
              const SizedBox(height: 16),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E8FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_outline, color: violeta, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos personales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF241B35),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Consulta o actualiza tu información',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Campo: Nombre
              _campoLabel('Nombre completo'),
              TextFormField(
                controller: _nombreController,
                focusNode: _nombreFocus,
                enabled: _estaEditando && !_guardando,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hintText: 'Tu nombre y apellido',
                  icono: Icons.person_outline,
                  activo: _estaEditando,
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Campo: Teléfono
              _campoLabel('Teléfono'),
              TextFormField(
                controller: _telefonoController,
                enabled: _estaEditando && !_guardando,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  hintText: 'Número de teléfono o celular',
                  icono: Icons.phone_outlined,
                  activo: _estaEditando,
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'El teléfono es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Campo: Dirección
              _campoLabel('Dirección de entrega'),
              TextFormField(
                controller: _direccionController,
                enabled: _estaEditando && !_guardando,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  hintText: 'Calle, número, sector o referencia',
                  icono: Icons.location_on_outlined,
                  activo: _estaEditando,
                ),
              ),
              const SizedBox(height: 24),

              // Botones: Editar y Guardar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardando
                          ? null
                          : () {
                              if (!_estaEditando) {
                                _activarEdicion();
                              } else {
                                setState(() {
                                  _estaEditando = false;
                                  _nombreController.text =
                                      widget.cliente['nombre']?.toString() ?? '';
                                  _telefonoController.text =
                                      widget.cliente['telefono']?.toString() ?? '';
                                  _direccionController.text =
                                      widget.cliente['direccion']?.toString() ?? '';
                                });
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: _estaEditando ? Colors.grey.shade400 : violeta,
                        ),
                        foregroundColor:
                            _estaEditando ? Colors.grey.shade700 : violeta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        _estaEditando ? Icons.cancel_outlined : Icons.edit_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _estaEditando ? 'Cancelar' : 'Editar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (!_estaEditando || _guardando)
                          ? null
                          : _guardarDatos,
                      style: FilledButton.styleFrom(
                        backgroundColor: violeta,
                        disabledBackgroundColor: violeta.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Guardar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF241B35),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icono,
    required bool activo,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icono, color: activo ? violeta : Colors.grey, size: 20),
      filled: true,
      fillColor: activo ? Colors.white : const Color(0xFFF7F5FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E1ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: activo ? const Color(0xFFDCCDF7) : const Color(0xFFE8E1ED),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: violeta, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFECE6F0)),
      ),
    );
  }
}
