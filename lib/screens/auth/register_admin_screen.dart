import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/administrador_model.dart';
import '../../services/google_auth_service.dart';
import '../admin/admin_home_screen.dart';

/// Pantalla de registro para Emprendedores (Administradores).
/// El emprendedor se registra directamente desde la app y entra
/// de inmediato sin necesidad de aprobación.
class RegisterAdminScreen extends StatefulWidget {
  /// Si se pasa un [googleUser], significa que el usuario ya se
  /// autenticó con Google y solo falta completar sus datos.
  final User? googleUser;

  const RegisterAdminScreen({super.key, this.googleUser});

  @override
  State<RegisterAdminScreen> createState() => _RegisterAdminScreenState();
}

class _RegisterAdminScreenState extends State<RegisterAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _emprendimiento = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _ocultar = true;
  bool _cargando = false;

  static const violeta = Color(0xFF6C4AB6);
  static const rosa = Color(0xFFE9A6C8);

  @override
  void initState() {
    super.initState();
    // Si ya viene autenticado con Google, mostramos el modal de datos directamente
    if (widget.googleUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarModalDatosGoogle(widget.googleUser!);
      });
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _emprendimiento.dispose();
    _telefono.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }
  String? _validarContrasena(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Ingresa una contraseña.';
    }
    if (v.length < 6) {
      return 'Usa al menos 6 caracteres.';
    }
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(v)) {
      return 'Debe incluir caracteres alfanuméricos (letras o números).';
    }
    if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(v)) {
      return 'Debe incluir al menos un carácter especial (ej. @, #, \$, *, !).';
    }
    return null;
  }


  /// Registra el emprendedor con correo y contraseña.
  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _cargando) return;

    setState(() => _cargando = true);

    User? usuarioCreado;

    try {
      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _correo.text.trim(),
            password: _contrasena.text,
          );

      usuarioCreado = credencial.user;
      if (usuarioCreado == null) throw Exception('Firebase no devolvió la cuenta.');

      await _guardarEnFirestore(
        uid: usuarioCreado.uid,
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        nombreEmprendimiento: _emprendimiento.text.trim(),
        correo: _correo.text.trim(),
        telefono: _telefono.text.trim(),
        fotoUrl: '',
        metodo: 'correo',
      );

      if (!mounted) return;

      final admin = AdministradorModel(
        id: usuarioCreado.uid,
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        nombreEmprendimiento: _emprendimiento.text.trim(),
        correo: _correo.text.trim(),
        telefono: _telefono.text.trim(),
        estado: true,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AdminHomeScreen(admin: admin)),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String mensaje;
      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Ese correo ya está registrado.';
          break;
        case 'invalid-email':
          mensaje = 'Escribe un correo electrónico válido.';
          break;
        case 'weak-password':
          mensaje = 'Usa una contraseña más segura (mínimo 6 caracteres).';
          break;
        default:
          mensaje = 'No se pudo crear la cuenta: ${e.message ?? e.code}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Registra con Google (inicia el flujo desde cero, sin un usuario previo).
  Future<void> _registrarConGoogle() async {
    setState(() => _cargando = true);
    try {
      final credencial = await GoogleAuthService.autenticarConGoogle();
      if (credencial == null || credencial.user == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }
      final usuario = credencial.user!;
      if (!mounted) return;
      setState(() => _cargando = false);
      await _mostrarModalDatosGoogle(usuario);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(GoogleAuthService.formatearErrorGoogle(e))),
        );
        setState(() => _cargando = false);
      }
    }
  }

  /// Modal para completar datos cuando el usuario viene de Google.
  Future<void> _mostrarModalDatosGoogle(User usuario) async {
    final partes = (usuario.displayName ?? '').trim().split(RegExp(r'\s+'));
    final nombreCtrl =
        TextEditingController(text: partes.isNotEmpty ? partes.first : '');
    final apellidoCtrl = TextEditingController(
      text: partes.length > 1 ? partes.sublist(1).join(' ') : '',
    );
    final emprendimientoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return Container(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 20,
            bottom: MediaQuery.of(bottomCtx).viewInsets.bottom + 24,
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
                  // Barra indicadora
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
                    'Completa tus datos de Emprendedor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF241B35),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cuenta Google: ${usuario.email ?? ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF81798D)),
                  ),
                  const SizedBox(height: 20),

                  // Nombre
                  const Text(
                    'Nombre',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: _decoracion('Tu nombre', Icons.person_outline),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 14),

                  // Apellido
                  const Text(
                    'Apellido',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: apellidoCtrl,
                    decoration: _decoracion('Tu apellido', Icons.badge_outlined),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu apellido' : null,
                  ),
                  const SizedBox(height: 14),

                  // Nombre del Emprendimiento
                  const Text(
                    'Nombre del Emprendimiento / Tienda',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: emprendimientoCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoracion('Ej. Boutique Vendix', Icons.storefront_outlined),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa el nombre de tu emprendimiento' : null,
                  ),
                  const SizedBox(height: 14),

                  // Teléfono
                  const Text(
                    'Teléfono',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _decoracion('Ej. 0991234567', Icons.phone_outlined),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                  ),
                  const SizedBox(height: 24),

                  // Botón confirmar
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: violeta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(bottomCtx);
                        setState(() => _cargando = true);
                        try {
                          await _guardarEnFirestore(
                            uid: usuario.uid,
                            nombre: nombreCtrl.text.trim(),
                            apellido: apellidoCtrl.text.trim(),
                            nombreEmprendimiento: emprendimientoCtrl.text.trim(),
                            correo: usuario.email ?? '',
                            telefono: telefonoCtrl.text.trim(),
                            fotoUrl: usuario.photoURL ?? '',
                            metodo: 'google',
                          );

                          if (!mounted) return;

                          final admin = AdministradorModel(
                            id: usuario.uid,
                            nombre: nombreCtrl.text.trim(),
                            apellido: apellidoCtrl.text.trim(),
                            nombreEmprendimiento: emprendimientoCtrl.text.trim(),
                            correo: usuario.email ?? '',
                            telefono: telefonoCtrl.text.trim(),
                            estado: true,
                          );

                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => AdminHomeScreen(admin: admin),
                            ),
                            (route) => false,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al registrar: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _cargando = false);
                        }
                      },
                      child: const Text(
                        'Crear cuenta de Emprendedor',
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
  }

  /// Guarda el emprendedor en Firestore: colecciones 'Administradores' y 'usuarios'.
  Future<void> _guardarEnFirestore({
    required String uid,
    required String nombre,
    required String apellido,
    required String nombreEmprendimiento,
    required String correo,
    required String telefono,
    required String fotoUrl,
    required String metodo,
  }) async {
    final db = FirebaseFirestore.instance;
    final lote = db.batch();

    // Colección principal de administradores (usada para identificar el rol)
    lote.set(db.collection('Administradores').doc(uid), {
      'uid': uid,
      'nombre': nombre,
      'apellido': apellido,
      'nombreEmprendimiento': nombreEmprendimiento,
      'correo': correo,
      'telefono': telefono,
      'fotoUrl': fotoUrl,
      'estado': true,
      'creadoEn': FieldValue.serverTimestamp(),
      'metodo_registro': metodo,
    });

    // Colección general de usuarios para la resolución de roles en login
    lote.set(db.collection('usuarios').doc(uid), {
      'uid': uid,
      'nombre': nombre,
      'apellido': apellido,
      'nombreEmprendimiento': nombreEmprendimiento,
      'correo': correo,
      'telefono': telefono,
      'fotoUrl': fotoUrl,
      'rol': 'administrador',
      'estado': true,
      'creadoEn': FieldValue.serverTimestamp(),
      'metodo_registro': metodo,
    });

    await lote.commit();
  }

  InputDecoration _decoracion(String texto, IconData icono) {
    return InputDecoration(
      hintText: texto,
      prefixIcon: Icon(icono, color: violeta),
      filled: true,
      fillColor: const Color(0xFFFAF8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: violeta, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si viene de Google, solo mostramos un loading mientras abre el modal
    if (widget.googleUser != null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF8FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FC),
      appBar: AppBar(
        title: const Text('Registro de Emprendedor'),
        foregroundColor: violeta,
        backgroundColor: const Color(0xFFFAF8FC),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: const Color(0xFFECE6F2)),
                    boxShadow: [
                      BoxShadow(
                        color: violeta.withValues(alpha: 0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icono
                      Container(
                        width: 68,
                        height: 68,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [violeta, rosa]),
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Registro de Emprendedor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF241B35),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Crea tu cuenta como emprendedor para gestionar tus ventas en vivo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF81798D), height: 1.5),
                      ),
                      const SizedBox(height: 25),

                      // Nombre
                      const Text(
                        'Nombre',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _nombre,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoracion('Tu nombre', Icons.person_outline),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu nombre.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Apellido
                      const Text(
                        'Apellido',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _apellido,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoracion('Tu apellido', Icons.badge_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu apellido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nombre del Emprendimiento
                      const Text(
                        'Nombre del Emprendimiento / Tienda',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _emprendimiento,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoracion('Ej. Boutique Vendix / Moda & Estilo', Icons.storefront_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el nombre de tu emprendimiento.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Teléfono
                      const Text(
                        'Teléfono',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        decoration: _decoracion('Ej. 099 123 4567', Icons.phone_outlined),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu número de teléfono.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Correo
                      const Text(
                        'Correo electrónico',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoracion('ejemplo@correo.com', Icons.email_outlined),
                        validator: (v) {
                          final c = v?.trim() ?? '';
                          if (c.isEmpty ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(c)) {
                            return 'Ingresa un correo válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contraseña
                      const Text(
                        'Contraseña',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _contrasena,
                        obscureText: _ocultar,
                        decoration: _decoracion('Mínimo 6 caracteres y 1 símbolo (@, #, \$...)', Icons.lock_outline)
                            .copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _ocultar = !_ocultar),
                            icon: Icon(
                              _ocultar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: _validarContrasena,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Debe contener mínimo 6 caracteres, letras/números y al menos un carácter especial (@, #, \$, *, !).',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),

                      // Confirmar contraseña
                      const Text(
                        'Confirmar contraseña',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _confirmacion,
                        obscureText: true,
                        decoration:
                            _decoracion('Repite tu contraseña', Icons.lock_reset_outlined),
                        validator: (v) {
                          if (v != _contrasena.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Botón principal
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _cargando ? null : _registrar,
                          style: FilledButton.styleFrom(
                            backgroundColor: violeta,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _cargando
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Crear cuenta de Emprendedor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Google
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _cargando ? null : _registrarConGoogle,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF241B35),
                            side: const BorderSide(
                              color: Color(0xFFECE6F2),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  'https://i.ibb.co/q3b1Qb2v/Google-G-logo-svg.webp',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 26,
                                    color: Color(0xFFDB4437),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Registrarse con Google',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
      ),
    );
  }
}
