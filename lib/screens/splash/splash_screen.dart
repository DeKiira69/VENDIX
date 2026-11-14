import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/administrador_model.dart';
import '../../widgets/vendix_logo.dart';
import '../admin/admin_home_screen.dart';
import '../auth/login_screen.dart';
import '../client/client_shell.dart';
import '../client/enter_code_screen.dart';
import '../secretary/secretary_shell.dart';

/// Pantalla Splash inicial de VENDIX.
///
/// Ejecuta la secuencia vectorial animada de VENDIX con el CustomPainter nativo
/// mientras verifica de forma asíncrona la sesión de Firebase para enrutar
/// fluidamente al usuario sin parpadeos ni pantallas intermedias.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Widget? _siguientePantalla;
  bool _animacionCompletada = false;
  bool _enrutamientoIniciado = false;

  @override
  void initState() {
    super.initState();
    _resolverDestinoEnSegundoPlano();
  }

  /// Verifica la sesión existente en paralelo a la animación del logo
  Future<void> _resolverDestinoEnSegundoPlano() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) {
        _siguientePantalla = const LoginScreen();
      } else {
        final destino = await _resolverPantallaPorUsuario(usuario);
        _siguientePantalla = destino ?? const LoginScreen();
      }
    } catch (_) {
      _siguientePantalla = const LoginScreen();
    }

    _intentarNavegacion();
  }

  /// Callback cuando el logo termina su animación de entrada (aprox 1.25s)
  void _onAnimacionEntradaTerminada() {
    _animacionCompletada = true;
    _intentarNavegacion();
  }

  /// Navega suavemente si la animación terminó y el destino está listo
  void _intentarNavegacion() {
    if (!mounted || _enrutamientoIniciado) return;
    if (_animacionCompletada && _siguientePantalla != null) {
      _enrutamientoIniciado = true;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (context, animation, secondaryAnimation) => _siguientePantalla!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
        ),
      );
    }
  }

  /// Determina la pantalla adecuada según el rol del usuario utilizando
  /// caché local y respaldo con Firestore.
  Future<Widget?> _resolverPantallaPorUsuario(User usuario) async {
    final uid = usuario.uid;
    final email = usuario.email?.trim().toLowerCase();

    // 1. INTENTO EN CACHÉ LOCAL
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

    // 2. CONSULTA AL SERVIDOR CON TIMEOUT
    try {
      final serverDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get()
          .timeout(const Duration(milliseconds: 2500));

      if (serverDoc.exists && serverDoc.data() != null) {
        final pantalla = _crearPantallaSegunRol(serverDoc.data()!, usuario);
        if (pantalla != null) return pantalla;
      }
    } catch (_) {}

    // 3. RESPALDO EN COLECCIONES ESPECÍFICAS
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('Administradores')
          .doc(uid)
          .get();
      if (adminDoc.exists) {
        return _crearPantallaSegunRol({'rol': 'administrador'}, usuario);
      }

      final clienteDoc = await FirebaseFirestore.instance
          .collection('clientes')
          .doc(uid)
          .get();
      if (clienteDoc.exists) {
        return _crearPantallaSegunRol({'rol': 'cliente', ...?clienteDoc.data()}, usuario);
      }

      if (email != null && email.isNotEmpty) {
        final secSnap = await FirebaseFirestore.instance
            .collection('secretarios')
            .where('correo', isEqualTo: email)
            .limit(1)
            .get();
        if (secSnap.docs.isNotEmpty) {
          final d = secSnap.docs.first.data();
          return _crearPantallaSegunRol({'rol': 'secretario', ...d}, usuario);
        }
      }
    } catch (_) {}

    return null;
  }

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
        return null; // En revisión -> Login para ver mensaje
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: 'vendix_logo_hero',
            child: VendixLogo(
              size: 145,
              showText: true,
              fontSize: 34,
              spacing: 28,
              animateEntrance: true,
              continuousLoop: true,
              onEntranceEnd: _onAnimacionEntradaTerminada,
            ),
          ),
        ),
      ),
    );
  }
}
