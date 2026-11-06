import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../client/client_shell.dart';
import '../secretary/secretary_shell.dart';
import '../admin/admin_home_screen.dart';
import '../../models/administrador_model.dart';
import '../../services/client_service.dart';
import '../../services/google_auth_service.dart';
import '../client/enter_code_screen.dart';
import 'register_client_screen.dart';
import 'register_entrepreneur_screen.dart';
import 'register_admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  bool _ocultarContrasena = true;
  bool _recordarSesion = true;
  bool _cargando = false;
  DateTime? _ultimoToqueAtras;

  static const Color violeta = Color(0xFF6C4AB6);
  static const Color rosa = Color(0xFFE9A6C8);
  static const Color texto = Color(0xFF241B35);
  static const Color textoSecundario = Color(0xFF81798D);

  @override
  void initState() {
    super.initState();
    _verificarSesionExistente();
  }

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  /// Si el usuario ya tenía una sesión activa y no la cerró, ingresa automáticamente
  /// de forma instantánea usando la caché local de Firestore.
  Future<void> _verificarSesionExistente() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    setState(() => _cargando = true);

    try {
      final pantalla = await _resolverPantalla(usuario);
      if (!mounted) return;

      if (pantalla != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => pantalla),
          (route) => false,
        );
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  /// Construye la pantalla correspondiente a partir del rol y datos del usuario.
  Widget? _crearPantallaSegunRol(Map<String, dynamic> datos, User usuario) {
    final rol = datos['rol']?.toString().trim().toLowerCase();
    final estado = datos['estado']?.toString().trim().toLowerCase();
    final aprobado = datos['aprobado'] == true;

    if (rol == 'cliente') {
      final codigo = datos['codigoLive']?.toString().trim() ?? '';
      if (codigo.isEmpty) {
        return const EnterCodeScreen();
      }
      return const ClientShell();
    } else if (rol == 'secretaria' || rol == 'secretario' || rol == 'operador') {
      if (estado == 'pendiente' || !aprobado) {
        return null; // Cuenta en revisión
      }
      return const SecretaryShell();
    } else if (rol == 'administrador' || rol == 'admin') {
      final nombre = datos['nombre'] ?? usuario.displayName ?? 'Administrador';
      final admin = AdministradorModel(
        id: usuario.uid,
        nombre: nombre,
        apellido: datos['apellido'] ?? '',
        correo: datos['correo'] ?? usuario.email ?? '',
        telefono: datos['telefono'] ?? '',
        estado: datos['estado'] ?? true,
      );
      return AdminHomeScreen(admin: admin);
    }
    return null;
  }

  /// Determina la pantalla adecuada según el rol del usuario utilizando
  /// una estrategia de alto rendimiento con comprobación de estado de cuenta:
  Future<Widget?> _resolverPantalla(User usuario) async {
    final uid = usuario.uid;
    final email = usuario.email?.trim().toLowerCase();

    // 1. INTENTO ULTRARRÁPIDO EN CACHÉ LOCAL (< 10 ms)
    try {
      final cacheDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));

      if (cacheDoc.exists && cacheDoc.data() != null) {
        final pantalla = _crearPantallaSegunRol(cacheDoc.data()!, usuario);
        if (pantalla != null) return pantalla;
      }
    } catch (_) {}

    // 2. CONSULTA AL SERVIDOR EN 'usuarios' (con timeout)
    try {
      final serverDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get()
          .timeout(const Duration(milliseconds: 3500));

      if (serverDoc.exists && serverDoc.data() != null) {
        final pantalla = _crearPantallaSegunRol(serverDoc.data()!, usuario);
        if (pantalla != null) return pantalla;
      }
    } catch (_) {}

    // 3. CONSULTAS DE RESPALDO EN PARALELO (Future.wait)
    try {
      final futures = <Future<dynamic>>[
        FirebaseFirestore.instance.collection('Administradores').doc(uid).get(),
        FirebaseFirestore.instance.collection('clientes').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('clientes')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get(),
      ];

      if (email != null && email.isNotEmpty) {
        futures.add(
          FirebaseFirestore.instance
              .collection('secretarios')
              .where('correo', isEqualTo: email)
              .limit(1)
              .get(),
        );
      }

      final respuestas = await Future.wait(futures).timeout(const Duration(seconds: 4));

      final adminDoc = respuestas[0] as DocumentSnapshot<Map<String, dynamic>>;
      final clienteDocDirecto = respuestas[1] as DocumentSnapshot<Map<String, dynamic>>;
      final clienteQuery = respuestas[2] as QuerySnapshot<Map<String, dynamic>>;

      if (adminDoc.exists && adminDoc.data() != null) {
        final admin = AdministradorModel.fromMap(adminDoc.id, adminDoc.data()!);
        return AdminHomeScreen(admin: admin);
      }

      if (clienteDocDirecto.exists || clienteQuery.docs.isNotEmpty) {
        final data = clienteDocDirecto.exists
            ? clienteDocDirecto.data()
            : clienteQuery.docs.first.data();
        final cod = data?['codigoLive']?.toString().trim() ?? '';
        if (cod.isEmpty) {
          return const EnterCodeScreen();
        }
        return const ClientShell();
      }

      if (respuestas.length > 3) {
        final secQuery = respuestas[3] as QuerySnapshot<Map<String, dynamic>>;
        if (secQuery.docs.isNotEmpty) {
          final data = secQuery.docs.first.data();
          final estado = data['estado'];
          final aprobado = data['aprobado'] == true;
          final estadoSol = data['estado_solicitud']?.toString().toLowerCase();

          if (estado == true || (aprobado && estadoSol != 'pendiente')) {
            return const SecretaryShell();
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // Comprueba el rol guardado en Firestore y abre la interfaz correcta.
  Future<void> _abrirInterfazPorRol(User usuario) async {
    Widget? pantalla;
    String? mensajeBloqueo;

    // Verificar si está en estado pendiente en 'secretarios' o 'usuarios'
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final d = userDoc.data()!;
        final rol = d['rol']?.toString().toLowerCase();
        final estado = d['estado']?.toString().toLowerCase();
        final aprobado = d['aprobado'] == true;

        if (rol == 'secretaria' || rol == 'secretario' || rol == 'operador') {
          if (estado == 'pendiente' || !aprobado) {
            mensajeBloqueo = 'Tu cuenta de secretario está en revisión pendiente. El administrador debe verificarla y aprobarla antes de ingresar.';
          }
        }
      }
    } catch (_) {}

    if (mensajeBloqueo == null) {
      pantalla = await _resolverPantalla(usuario);
    }

    if (!mounted) return;

    if (mensajeBloqueo != null) {
      await FirebaseAuth.instance.signOut();
      ClientService.limpiarCache();
      if (!mounted) return;
      _mostrarDialogoPendiente(mensajeBloqueo);
      return;
    }

    if (pantalla == null) {
      await FirebaseAuth.instance.signOut();
      ClientService.limpiarCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta cuenta no tiene un rol registrado o sigue en revisión pendiente. '
            'Solicita al administrador su activación.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => pantalla!),
      (route) => false,
    );
  }

  /// Inicia sesión o registra con cuenta de Google
  Future<void> _iniciarConGoogle() async {
    setState(() => _cargando = true);
    try {
      final credencial = await GoogleAuthService.autenticarConGoogle();
      if (credencial == null || credencial.user == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }

      final usuario = credencial.user!;
      final perfilDoc = await GoogleAuthService.obtenerPerfil(usuario.uid);

      if (!perfilDoc.exists || perfilDoc.data() == null) {
        // Usuario nuevo con Google: preguntamos si es Cliente o Secretario
        if (!mounted) return;
        setState(() => _cargando = false);
        await _mostrarDialogoSeleccionRolGoogle(usuario);
        return;
      }

      // Si ya tiene perfil, abrimos según su rol
      await _abrirInterfazPorRol(usuario);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(GoogleAuthService.formatearErrorGoogle(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Si es una cuenta Google nueva, le permitimos elegir si desea registrarse como Cliente o Secretario
  Future<void> _mostrarDialogoSeleccionRolGoogle(User usuario) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Elige tu tipo de cuenta',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¡Hola ${usuario.displayName ?? ''}! Es tu primera vez con Google en VENDIX. ¿Cómo deseas usar la app?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: textoSecundario),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFECE6F2)),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3E5F5),
                child: Icon(Icons.person, color: violeta),
              ),
              title: const Text(
                'Soy Cliente',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Comprar y revisar pedidos en vivo',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(dialogCtx);
                await _mostrarModalDatosGoogle(usuario: usuario, rol: 'cliente');
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFECE6F2)),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.badge, color: Color(0xFFF39C12)),
              ),
              title: const Text(
                'Soy Secretario (Operador)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Requiere aprobación previa del administrador',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(dialogCtx);
                await _mostrarModalDatosGoogle(usuario: usuario, rol: 'secretario');
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFECE6F2)),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.storefront, color: Color(0xFF2E7D32)),
              ),
              title: const Text(
                'Soy Emprendedor (Administrador)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Gestionar tienda, inventario y secretarios',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                Navigator.pop(dialogCtx);
                await _mostrarModalDatosGoogle(usuario: usuario, rol: 'administrador');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Modal para completar Nombre, Apellido, Dirección (opcional) y Teléfono (opcional)
  Future<void> _mostrarModalDatosGoogle({
    required User usuario,
    required String rol,
  }) async {
    final partes = (usuario.displayName ?? '').trim().split(RegExp(r'\s+'));
    final nombreDefecto = partes.isNotEmpty ? partes.first : '';
    final apellidoDefecto = partes.length > 1 ? partes.sublist(1).join(' ') : '';

    final nombreCtrl = TextEditingController(text: nombreDefecto);
    final apellidoCtrl = TextEditingController(text: apellidoDefecto);
    final direccionCtrl = TextEditingController();
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
                  Text(
                    rol == 'cliente'
                        ? 'Completa tus datos de Cliente'
                        : (rol == 'administrador'
                            ? 'Completa tus datos de Emprendedor'
                            : 'Completa tus datos de Secretario'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: texto,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vinculado a: ${usuario.email ?? ""}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: textoSecundario),
                  ),
                  const SizedBox(height: 20),

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
                        Navigator.pop(bottomCtx);
                        setState(() => _cargando = true);
                        try {
                          await GoogleAuthService.registrarUsuarioGoogle(
                            usuario: usuario,
                            rol: rol,
                            nombre: nombreCtrl.text.trim(),
                            apellido: apellidoCtrl.text.trim(),
                            direccion: direccionCtrl.text.trim(),
                            telefono: telefonoCtrl.text.trim(),
                          );

                          if (rol == 'cliente' || rol == 'administrador') {
                            await _abrirInterfazPorRol(usuario);
                          } else {
                            await FirebaseAuth.instance.signOut();
                            ClientService.limpiarCache();
                            if (mounted) {
                              _mostrarDialogoPendiente(
                                'Tu cuenta de secretario ha sido registrada con tu cuenta de Google.\n\n'
                                'Se encuentra en estado PENDIENTE. El administrador debe verificarla y activarla antes de tu acceso.',
                              );
                            }
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
                      },
                      child: const Text(
                        'Guardar y Continuar',
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

  void _mostrarDialogoPendiente(String mensaje) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.hourglass_empty_rounded,
          color: Color(0xFFF39C12),
          size: 48,
        ),
        title: const Text(
          'Acceso Pendiente de Aprobación',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: violeta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarSesion() async {
    FocusScope.of(context).unfocus();

    if (_cargando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _correoController.text.trim(),
        password: _contrasenaController.text,
      );

      final usuario = credencial.user;

      if (usuario == null) {
        throw Exception('No se pudo obtener el usuario autenticado.');
      }

      await _abrirInterfazPorRol(usuario);
    } on FirebaseAuthException catch (e) {
      String mensaje;

      switch (e.code) {
        case 'user-not-found':
          mensaje = 'No existe una cuenta con este correo.';
          break;
        case 'wrong-password':
          mensaje = 'La contraseña es incorrecta.';
          break;
        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;
        case 'user-disabled':
          mensaje = 'Esta cuenta ha sido inhabilitada.';
          break;
        case 'invalid-credential':
          mensaje = 'Correo o contraseña incorrectos. Verifica tus datos.';
          break;
        default:
          mensaje = 'Error al iniciar sesión: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _irARegistroCliente() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterClientScreen()),
    );
  }

  void _irARegistroSecretario() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterEntrepreneurScreen()),
    );
  }

  void _irARegistroEmprendedor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterAdminScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

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

        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Logo y cabecera
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [violeta, rosa],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: violeta.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bienvenido a Vendix',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: texto,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gestiona tus pedidos y ventas en transmisiones en vivo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textoSecundario,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo de Correo
                    const Text(
                      'Correo electrónico',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: texto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'ejemplo@correo.com',
                        hintStyle: const TextStyle(color: Color(0xFFB0A9BD), fontSize: 14),
                        prefixIcon: const Icon(Icons.email_outlined, color: violeta, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF9F7FC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEDE8F5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEDE8F5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: violeta, width: 1.5),
                        ),
                      ),
                      validator: (valor) {
                        final texto = valor?.trim() ?? '';
                        if (texto.isEmpty) {
                          return 'Ingresa tu correo electrónico';
                        }
                        if (!texto.contains('@') || !texto.contains('.')) {
                          return 'Ingresa un correo electrónico válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Campo de Contraseña
                    const Text(
                      'Contraseña',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: texto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _iniciarSesion(),
                      decoration: InputDecoration(
                        hintText: 'Tu contraseña',
                        hintStyle: const TextStyle(color: Color(0xFFB0A9BD), fontSize: 14),
                        prefixIcon: const Icon(Icons.lock_outline, color: violeta, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarContrasena
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF81798D),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _ocultarContrasena = !_ocultarContrasena;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9F7FC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEDE8F5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEDE8F5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: violeta, width: 1.5),
                        ),
                      ),
                      validator: (valor) {
                        if (valor == null || valor.isEmpty) {
                          return 'Ingresa tu contraseña';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Opciones secundarias
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _recordarSesion,
                            activeColor: violeta,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setState(() => _recordarSesion = val ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recordar sesión',
                          style: TextStyle(fontSize: 13, color: textoSecundario),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón Iniciar Sesión
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _cargando ? null : _iniciarSesion,
                        style: FilledButton.styleFrom(
                          backgroundColor: violeta,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
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
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Botón Continuar con Google
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _cargando ? null : _iniciarConGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: texto,
                          side: const BorderSide(color: Color(0xFFEDE8F5), width: 1.5),
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
                              'Continuar con Google',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Separador "¿No tienes cuenta?"
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFEDE8F5))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '¿No tienes cuenta? Regístrate',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textoSecundario.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFEDE8F5))),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Selector interactivo de registro (Secretario / Cliente / Emprendedor)
                    _SelectorRegistroAnimado(
                      onSecretario: _irARegistroSecretario,
                      onCliente: _irARegistroCliente,
                      onEmprendedor: _irARegistroEmprendedor,
                    ),
                    const SizedBox(height: 16),
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

class _SelectorRegistroAnimado extends StatefulWidget {
  final VoidCallback onSecretario;
  final VoidCallback onCliente;
  final VoidCallback onEmprendedor;

  const _SelectorRegistroAnimado({
    required this.onSecretario,
    required this.onCliente,
    required this.onEmprendedor,
  });

  @override
  State<_SelectorRegistroAnimado> createState() =>
      _SelectorRegistroAnimadoState();
}

class _SelectorRegistroAnimadoState extends State<_SelectorRegistroAnimado> {
  int _indiceSeleccionado = 0; // 0 = Secretario, 1 = Cliente, 2 = Emprendedor

  static const Color violeta = Color(0xFF6C4AB6);

  Widget _buildOpcion({
    required int indice,
    required String texto,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    final seleccionado = _indiceSeleccionado == indice;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _indiceSeleccionado = indice);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          decoration: BoxDecoration(
            color: seleccionado ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: seleccionado
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 16,
                color: seleccionado ? violeta : const Color(0xFF81798D),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: seleccionado ? violeta : const Color(0xFF81798D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildOpcion(
            indice: 0,
            texto: 'Secretario',
            icono: Icons.badge_outlined,
            onTap: widget.onSecretario,
          ),
          _buildOpcion(
            indice: 1,
            texto: 'Cliente',
            icono: Icons.person_outline,
            onTap: widget.onCliente,
          ),
          _buildOpcion(
            indice: 2,
            texto: 'Emprendedor',
            icono: Icons.storefront_outlined,
            onTap: widget.onEmprendedor,
          ),
        ],
      ),
    );
  }
}
