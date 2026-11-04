import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _initialized = false;

  /// ID de cliente web configurado en Firebase Console (OAuth 2.0 Web Client)
  static const String _webClientId =
      '1072094421175-b9pe80lgr9r5g33oao2jb697po91plbq.apps.googleusercontent.com';

  /// Inicia el flujo de autenticación con Google y devuelve las credenciales de Firebase.
  static Future<UserCredential?> autenticarConGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      return await _auth.signInWithPopup(googleProvider);
    } else {
      if (!_initialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _webClientId,
        );
        _initialized = true;
      }

      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );

      return await _auth.signInWithCredential(credential);
    }
  }

  /// Verifica si el usuario ya tiene un documento en la colección 'usuarios'.
  static Future<DocumentSnapshot<Map<String, dynamic>>> obtenerPerfil(
    String uid,
  ) async {
    return await _db.collection('usuarios').doc(uid).get();
  }

  /// Registra un nuevo usuario con cuenta de Google con el rol especificado.
  /// Si el rol es 'cliente', se aprueba de inmediato y se crea en 'clientes'.
  /// Si el rol es 'secretario', se crea con estado 'pendiente' y aprobado = false.
  static Future<void> registrarUsuarioGoogle({
    required User usuario,
    required String rol,
    String? nombre,
    String? apellido,
    String telefono = '',
    String direccion = '',
  }) async {
    final lote = _db.batch();
    final uid = usuario.uid;
    final email = usuario.email?.trim().toLowerCase() ?? '';
    final fotoUrl = usuario.photoURL ?? '';

    // Si no se pasaron nombre/apellido explícitamente, extraer del displayName de Google
    final nombreGoogle = usuario.displayName ?? 'Usuario';
    final partes = nombreGoogle.trim().split(RegExp(r'\s+'));
    final finalNombre = (nombre != null && nombre.trim().isNotEmpty)
        ? nombre.trim()
        : (partes.isNotEmpty ? partes.first : 'Usuario');
    final finalApellido = (apellido != null && apellido.trim().isNotEmpty)
        ? apellido.trim()
        : (partes.length > 1 ? partes.sublist(1).join(' ') : '');
    final nombreCompleto = '$finalNombre $finalApellido'.trim();

    if (rol == 'cliente') {
      // 1. Guardar en 'usuarios'
      final docUsuario = _db.collection('usuarios').doc(uid);
      lote.set(docUsuario, {
        'nombre': finalNombre,
        'apellido': finalApellido,
        'correo': email,
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
        'rol': 'cliente',
        'estado': true,
        'aprobado': true,
        'fotoUrl': fotoUrl,
        'creadoEn': FieldValue.serverTimestamp(),
        'metodo_registro': 'google',
      }, SetOptions(merge: true));

      // 2. Guardar en 'clientes'
      final docCliente = _db.collection('clientes').doc(uid);
      lote.set(docCliente, {
        'nombre': nombreCompleto,
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
        'correo': email,
        'uid': uid,
        'fotoUrl': fotoUrl,
        'creadoEn': FieldValue.serverTimestamp(),
        'metodo_registro': 'google',
      }, SetOptions(merge: true));

      // 3. Foto de perfil
      if (fotoUrl.isNotEmpty) {
        final docFoto = _db.collection('fotos_perfil').doc(uid);
        lote.set(docFoto, {
          'usuarioId': uid,
          'fotoUrl': fotoUrl,
          'rol': 'cliente',
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else if (rol == 'secretario' || rol == 'secretaria') {
      // 1. Guardar en 'usuarios' como pendiente
      final docUsuario = _db.collection('usuarios').doc(uid);
      lote.set(docUsuario, {
        'nombre': finalNombre,
        'apellido': finalApellido,
        'correo': email,
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
        'rol': 'secretario',
        'estado': false, // Inactivo hasta aprobación
        'aprobado': false,
        'estado_solicitud': 'pendiente',
        'fotoUrl': fotoUrl,
        'creadoEn': FieldValue.serverTimestamp(),
        'metodo_registro': 'google',
      }, SetOptions(merge: true));

      // 2. Guardar en 'secretarios'
      final docSecretario = _db.collection('secretarios').doc(uid);
      lote.set(docSecretario, {
        'nombre': finalNombre,
        'apellido': finalApellido,
        'correo': email,
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
        'estado': false,
        'aprobado': false,
        'estado_solicitud': 'pendiente',
        'fecha_registro': FieldValue.serverTimestamp(),
        'fotoUrl': fotoUrl,
        'metodo_registro': 'google',
      }, SetOptions(merge: true));

      // 3. Foto de perfil
      if (fotoUrl.isNotEmpty) {
        final docFoto = _db.collection('fotos_perfil').doc(uid);
        lote.set(docFoto, {
          'usuarioId': uid,
          'fotoUrl': fotoUrl,
          'rol': 'secretario',
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await lote.commit();
  }
}
