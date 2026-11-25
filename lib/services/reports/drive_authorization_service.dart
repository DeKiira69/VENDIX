import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio encargado exclusivamente de gestionar la autorización OAuth para Google Drive.
///
/// PRINCIPIO ARQUITECTÓNICO CRÍTICO:
/// Este servicio es 100% independiente de Firebase Authentication.
/// Un usuario puede haber iniciado sesión en VendiX con Hotmail, Outlook o un correo
/// institucional, y autorizar aquí una cuenta de Google diferente para guardar sus reportes.
/// Jamás altera, reemplaza ni cierra la sesión de Firebase ni modifica el UID en Firestore.
class DriveAuthorizationService {
  DriveAuthorizationService._();

  static const String scopeDriveFile = 'https://www.googleapis.com/auth/drive.file';
  static const String _webClientId =
      '1072094421175-b9pe80lgr9r5g33oao2jb697po91plbq.apps.googleusercontent.com';

  static bool _initialized = false;
  static String? _cachedAccessToken;
  static String? _authorizedEmail;

  /// Inicializa GoogleSignIn si es necesario
  static Future<void> _asegurarInicializacion() async {
    if (!_initialized && !kIsWeb) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _webClientId,
      );
      _initialized = true;
    }
  }

  /// Retorna el correo de la cuenta de Google actualmente autorizada para Drive (si existe)
  static String? get correoAutorizado => _authorizedEmail;

  /// Obtiene un Access Token válido con el scope `https://www.googleapis.com/auth/drive.file`.
  /// Si el usuario aún no ha autorizado su cuenta de Google, despliega el selector
  /// nativo de cuentas. Si cancela, devuelve null sin afectar la sesión de VendiX.
  static Future<String?> obtenerAccessToken({bool forzarNuevaSeleccion = false}) async {
    await _asegurarInicializacion();

    if (!forzarNuevaSeleccion && _cachedAccessToken != null) {
      return _cachedAccessToken;
    }

    try {
      // 1. Solicitar autorización con prompt si es necesario
      final headers = await GoogleSignIn.instance.authorizationClient.authorizationHeaders(
        [scopeDriveFile],
        promptIfNecessary: true,
      );

      if (headers == null || !headers.containsKey('Authorization')) {
        return null;
      }

      final authHeader = headers['Authorization']!;
      final token = authHeader.replaceFirst('Bearer ', '').trim();
      _cachedAccessToken = token;

      return token;
    } catch (e) {
      // Si ocurre un error o cancelación, no propagar excepción destructiva
      debugPrint('[DriveAuthorizationService] Error o cancelación OAuth: $e');
      return null;
    }
  }

  /// Desvincula la autorización de Drive en la memoria de la aplicación
  /// (sin cerrar la sesión de VendiX en Firebase)
  static void limpiarAutorizacionLocal() {
    _cachedAccessToken = null;
    _authorizedEmail = null;
  }
}
