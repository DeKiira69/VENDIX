import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/reports/report_models.dart';

class ReportPermissionResult {
  final bool autorizado;
  final String mensajeError;
  final ReportRole? rol;
  final String adminId;
  final String nombreEmprendimiento;
  final String nombreUsuario;

  ReportPermissionResult({
    required this.autorizado,
    this.mensajeError = '',
    this.rol,
    this.adminId = '',
    this.nombreEmprendimiento = '',
    this.nombreUsuario = '',
  });

  factory ReportPermissionResult.denegado(String motivo) {
    return ReportPermissionResult(
      autorizado: false,
      mensajeError: motivo,
    );
  }
}

/// Servicio encargado de validar el acceso y alcance de exportación según el rol del usuario
class ReportPermissionService {
  ReportPermissionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Valida si el usuario actual tiene permisos para exportar reportes comerciales
  /// y determina el rol operativo y el identificador de la tienda a reportar.
  static Future<ReportPermissionResult> validarPermiso({
    String? adminIdManual,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ReportPermissionResult.denegado('No hay una sesión activa en VendiX.');
    }

    final uid = user.uid;

    try {
      final userDoc = await _db.collection('usuarios').doc(uid).get();
      if (!userDoc.exists) {
        return ReportPermissionResult.denegado('No se encontró el perfil del usuario en el sistema.');
      }

      final data = userDoc.data() ?? {};
      final rawRol = data['rol']?.toString().toLowerCase() ?? '';
      final nombre = data['nombre']?.toString() ?? '';
      final apellido = data['apellido']?.toString() ?? '';
      final nombreCompleto = [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
      final nombreUsuario = nombreCompleto.isNotEmpty ? nombreCompleto : (user.displayName ?? 'Usuario');

      // 1. Caso Administrador
      if (rawRol == 'administrador' || rawRol == 'admin') {
        String adminId = data['adminId']?.toString() ?? adminIdManual ?? '';
        if (adminId.isEmpty) {
          // Intentar resolver desde Administradores
          final adminSnap = await _db
              .collection('Administradores')
              .where('uid', isEqualTo: uid)
              .limit(1)
              .get();
          if (adminSnap.docs.isNotEmpty) {
            adminId = adminSnap.docs.first.id;
          } else {
            adminId = uid;
          }
        }

        String nombreEmp = data['nombreEmprendimiento']?.toString() ?? '';
        if (nombreEmp.isEmpty) {
          final adminDoc = await _db.collection('Administradores').doc(adminId).get();
          if (adminDoc.exists) {
            nombreEmp = adminDoc.data()?['nombreEmprendimiento']?.toString() ?? 'Mi Emprendimiento';
          } else {
            nombreEmp = 'Mi Emprendimiento';
          }
        }

        return ReportPermissionResult(
          autorizado: true,
          rol: ReportRole.administrador,
          adminId: adminId,
          nombreEmprendimiento: nombreEmp,
          nombreUsuario: nombreUsuario,
        );
      }

      // 2. Caso Secretario
      if (rawRol == 'secretario' || rawRol == 'secretaria') {
        String adminId = adminIdManual ?? data['adminId']?.toString() ?? '';

        // Si no está directamente en el documento de usuario, buscar en secretarios
        if (adminId.isEmpty) {
          final secSnap = await _db
              .collection('secretarios')
              .where('uid', isEqualTo: uid)
              .get();
          for (final doc in secSnap.docs) {
            final secData = doc.data();
            final a = secData['adminId']?.toString() ?? '';
            final activo = secData['estado'] == true || secData['aprobado'] == true;
            if (a.isNotEmpty && activo) {
              adminId = a;
              break;
            }
          }
        }

        if (adminId.isEmpty) {
          return ReportPermissionResult.denegado(
            'No tienes un emprendimiento activo asignado para generar reportes operativos.',
          );
        }

        // Obtener nombre del negocio
        String nombreEmp = data['nombreEmprendimiento']?.toString() ?? '';
        if (nombreEmp.isEmpty) {
          final adminDoc = await _db.collection('Administradores').doc(adminId).get();
          if (adminDoc.exists) {
            nombreEmp = adminDoc.data()?['nombreEmprendimiento']?.toString() ?? 'Emprendimiento';
          } else {
            nombreEmp = 'Emprendimiento';
          }
        }

        return ReportPermissionResult(
          autorizado: true,
          rol: ReportRole.secretario,
          adminId: adminId,
          nombreEmprendimiento: nombreEmp,
          nombreUsuario: nombreUsuario,
        );
      }

      // 3. Caso Cliente: Acceso estrictamente denegado
      return ReportPermissionResult.denegado(
        'El rol de cliente no tiene autorización para acceder a reportes comerciales.',
      );
    } catch (e) {
      return ReportPermissionResult.denegado('Error al verificar permisos: $e');
    }
  }
}
