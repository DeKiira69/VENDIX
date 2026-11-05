import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../client/client_shell.dart';
import '../../services/google_auth_service.dart';

class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoLive = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _direccion = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _ocultar = true;
  bool _cargando = false;

  static const violeta = Color(0xFF6C4AB6);
  static const rosa = Color(0xFFE9A6C8);

  @override
  void dispose() {
    _codigoLive.dispose();
    _nombre.dispose();
    _telefono.dispose();
    _correo.dispose();
    _direccion.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || _cargando) return;

    final codigoIngresado = _codigoLive.text.trim().toUpperCase();
    if (codigoIngresado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código del Live es obligatorio.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final db = FirebaseFirestore.instance;

      // 1. Validar que el código del live existe en un secretario
      final querySec = await db
          .collection('secretarios')
          .where('codigoLive', isEqualTo: codigoIngresado)
          .limit(1)
          .get();

      if (querySec.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Código no válido o no activo. Solicítalo en la transmisión del Live.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _cargando = false);
        }
        return;
      }

      final dataSec = querySec.docs.first.data();
      final secretarioId = querySec.docs.first.id;
      final adminId = dataSec['adminId']?.toString() ?? '';

      // 2. Crear usuario en Firebase Authentication
      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _correo.text.trim(),
            password: _contrasena.text,
          );

      final usuarioCreado = credencial.user;

      if (usuarioCreado == null) {
        throw Exception('Firebase no devolvió la cuenta creada.');
      }

      final uid = usuarioCreado.uid;
      final nombreCompleto = _nombre.text.trim();
      final email = _correo.text.trim();
      final telefono = _telefono.text.trim();
      final direccion = _direccion.text.trim();

      final lote = db.batch();

      lote.set(db.collection('usuarios').doc(uid), {
        'uid': uid,
        'nombre': nombreCompleto,
        'correo': email,
        'telefono': telefono,
        'direccion': direccion,
        'rol': 'cliente',
        'adminId': adminId,
        'secretarioId': secretarioId,
        'codigoLive': codigoIngresado,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      // El UID también identifica al perfil del cliente en 'clientes'
      lote.set(db.collection('clientes').doc(uid), {
        'uid': uid,
        'nombre': nombreCompleto,
        'correo': email,
        'telefono': telefono,
        'direccion': direccion,
        'adminId': adminId,
        'secretarioId': secretarioId,
        'codigoLive': codigoIngresado,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      await lote.commit();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ClientShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String mensaje;

      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Ese correo ya tiene una cuenta.';
          break;
        case 'invalid-email':
          mensaje = 'Escribe un correo electrónico válido.';
          break;
        case 'weak-password':
          mensaje = 'Usa una contraseña más segura (mínimo 6 caracteres).';
          break;
        case 'operation-not-allowed':
          mensaje = 'Activa el acceso con correo y contraseña en Firebase.';
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
          SnackBar(
            content: Text('Error al registrar: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

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
          SnackBar(
            content: Text('Error al registrar con Google: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _mostrarModalDatosGoogle(User usuario) async {
    final partes = (usuario.displayName ?? '').trim().split(RegExp(r'\s+'));
    final nombreDefecto = _nombre.text.trim().isNotEmpty
        ? _nombre.text.trim()
        : (partes.isNotEmpty ? partes.first : '');
    final apellidoDefecto = partes.length > 1 ? partes.sublist(1).join(' ') : '';

    final codigoLiveCtrl = TextEditingController(text: _codigoLive.text.trim().toUpperCase());
    final nombreCtrl = TextEditingController(text: nombreDefecto);
    final apellidoCtrl = TextEditingController(text: apellidoDefecto);
    final direccionCtrl = TextEditingController(text: _direccion.text.trim());
    final telefonoCtrl = TextEditingController(text: _telefono.text.trim());
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
                    'Completa tus datos de Cliente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF241B35),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vinculado a: ${usuario.email ?? ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF81798D)),
                  ),
                  const SizedBox(height: 20),

                  // Código del Live Obligatorio
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1EAFE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDCCBFA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.vpn_key_outlined, size: 16, color: violeta),
                            SizedBox(width: 6),
                            Text(
                              'CÓDIGO DEL LIVE (OBLIGATORIO)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: violeta,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: codigoLiveCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: violeta,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ej. VX-849',
                            hintStyle: const TextStyle(letterSpacing: 1),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa el código del Live'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nombre
                  const Text('Nombre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tu nombre',
                      prefixIcon: const Icon(Icons.person_outline, color: violeta),
                      filled: true,
                      fillColor: const Color(0xFFFAF8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 14),

                  // Apellido
                  const Text('Apellido', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: apellidoCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tu apellido',
                      prefixIcon: const Icon(Icons.badge_outlined, color: violeta),
                      filled: true,
                      fillColor: const Color(0xFFFAF8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu apellido' : null,
                  ),
                  const SizedBox(height: 14),

                  // Dirección (opcional)
                  const Text('Dirección (opcional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: direccionCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej. Av. Amazonas y Colón (opcional)',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: violeta),
                      filled: true,
                      fillColor: const Color(0xFFFAF8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Teléfono (opcional)
                  const Text('Número de teléfono (opcional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Ej. 0991234567 (opcional)',
                      prefixIcon: const Icon(Icons.phone_outlined, color: violeta),
                      filled: true,
                      fillColor: const Color(0xFFFAF8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFECE6F2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón Confirmar
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

                        final cod = codigoLiveCtrl.text.trim().toUpperCase();

                        // Validar código contra 'secretarios'
                        final querySec = await FirebaseFirestore.instance
                            .collection('secretarios')
                            .where('codigoLive', isEqualTo: cod)
                            .limit(1)
                            .get();

                        if (querySec.docs.isEmpty) {
                          if (bottomCtx.mounted) {
                            ScaffoldMessenger.of(bottomCtx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Código no válido o no activo. Solicítalo en la transmisión del Live.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        final dataSec = querySec.docs.first.data();
                        final secId = querySec.docs.first.id;
                        final admId = dataSec['adminId']?.toString() ?? '';

                        if (!bottomCtx.mounted) return;
                        Navigator.pop(bottomCtx);
                        setState(() => _cargando = true);
                        try {
                          await GoogleAuthService.registrarUsuarioGoogle(
                            usuario: usuario,
                            rol: 'cliente',
                            nombre: nombreCtrl.text.trim(),
                            apellido: apellidoCtrl.text.trim(),
                            direccion: direccionCtrl.text.trim(),
                            telefono: telefonoCtrl.text.trim(),
                            adminId: admId,
                            secretarioId: secId,
                            codigoLive: cod,
                          );

                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const ClientShell()),
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
                        'Guardar y Entrar',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FC),
      appBar: AppBar(
        title: const Text('Crear cuenta de cliente'),
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
                      Container(
                        width: 68,
                        height: 68,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [violeta, rosa]),
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Únete a Vendix',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF241B35),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Crea tu cuenta para consultar tus compras y pagos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF81798D), height: 1.5),
                      ),
                      const SizedBox(height: 25),

                      // Tarjeta de Código del Live (Obligatorio)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EAFE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCCBFA), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.vpn_key_outlined, size: 16, color: violeta),
                                SizedBox(width: 6),
                                Text(
                                  'CÓDIGO DEL LIVE (OBLIGATORIO)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: violeta,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pídelo al operador durante la transmisión en vivo.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF6B617A)),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _codigoLive,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 16,
                                color: violeta,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ej. VX-849',
                                hintStyle: const TextStyle(letterSpacing: 1, fontSize: 14),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: violeta, width: 1.5),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Ingresa el código del Live para continuar.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text('Nombre completo', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _nombre,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoracion(
                          'Escribe tus nombres y apellidos',
                          Icons.person_outline,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu nombre completo.';
                          }
                          if (v.trim().length < 3) {
                            return 'Escribe un nombre válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('Número de teléfono', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        decoration: _decoracion(
                          'Ej. 099 123 4567',
                          Icons.phone_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu número de teléfono.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('Correo electrónico', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoracion(
                          'ejemplo@correo.com',
                          Icons.email_outlined,
                        ),
                        validator: (v) {
                          final correo = v?.trim() ?? '';
                          if (correo.isEmpty ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(correo)) {
                            return 'Ingresa un correo válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('Dirección', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _direccion,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoracion(
                          'Dirección de entrega (opcional)',
                          Icons.location_on_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _contrasena,
                        obscureText: _ocultar,
                        decoration:
                            _decoracion(
                              'Mínimo 6 caracteres',
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() => _ocultar = !_ocultar);
                                },
                                icon: Icon(
                                  _ocultar
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return 'Usa al menos 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text('Confirmar contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _confirmacion,
                        obscureText: true,
                        decoration: _decoracion(
                          'Repite tu contraseña',
                          Icons.lock_reset_outlined,
                        ),
                        validator: (v) {
                          if (v != _contrasena.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

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
                                  'Crear cuenta de cliente',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Botón Registrarse con Google
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
}
