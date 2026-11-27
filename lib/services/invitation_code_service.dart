import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio centralizado para consultar y generar códigos de invitación (Live)
/// y construir las URLs de códigos QR mediante la API gratuita de QuickChart.
///
/// Regla de negocio:
/// - Únicamente el Administrador / Emprendedor puede generar o actualizar
///   el código de invitación de su emprendimiento.
/// - El Secretario solo puede consultar y copiar el código asignado.
class InvitationCodeService {
  InvitationCodeService._();

  /// Genera un código con el formato estándar de VendiX (`XXX-999`).
  static String generarFormatoCodigo() {
    const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const numeros = '23456789';
    final rnd = Random();
    final prefijo = String.fromCharCodes(
      Iterable.generate(3, (_) => letras.codeUnitAt(rnd.nextInt(letras.length))),
    );
    final sufijo = String.fromCharCodes(
      Iterable.generate(3, (_) => numeros.codeUnitAt(rnd.nextInt(numeros.length))),
    );
    return '$prefijo-$sufijo';
  }

  /// Extrae un código de invitación limpio desde texto plano o URI/parámetro.
  static String extraerCodigoDeEntrada(String raw) {
    final limpio = raw.trim();
    if (limpio.isEmpty) return '';

    final uri = Uri.tryParse(limpio);
    if (uri != null && uri.queryParameters.containsKey('codigo')) {
      final param = uri.queryParameters['codigo']?.trim().toUpperCase() ?? '';
      if (param.isNotEmpty) return param;
    }

    return limpio.toUpperCase();
  }

  /// Consulta el código de invitación existente de un administrador sin crear uno nuevo.
  ///
  /// Busca primero en `Administradores/{adminId}` y, si aún no está allí,
  /// revisa si ya existía un código previo en algún documento de `secretarios`
  /// vinculado al mismo `adminId` para no duplicar ni reemplazar códigos activos.
  static Future<String> obtenerCodigoAdmin(String adminId) async {
    if (adminId.isEmpty) return '';
    final db = FirebaseFirestore.instance;

    final adminDoc = await db.collection('Administradores').doc(adminId).get();
    final codigoAdmin =
        adminDoc.data()?['codigoLive']?.toString().trim().toUpperCase() ?? '';
    if (codigoAdmin.isNotEmpty) {
      return codigoAdmin;
    }

    // Compatibilidad con códigos creados previamente en la colección secretarios
    final secQuery = await db
        .collection('secretarios')
        .where('adminId', isEqualTo: adminId)
        .get();

    for (final doc in secQuery.docs) {
      final codigoSec =
          doc.data()['codigoLive']?.toString().trim().toUpperCase() ?? '';
      if (codigoSec.isNotEmpty) {
        await db.collection('Administradores').doc(adminId).set({
          'codigoLive': codigoSec,
        }, SetOptions(merge: true));
        return codigoSec;
      }
    }

    return '';
  }

  /// Obtiene el código existente del administrador o genera uno nuevo si todavía no tiene.
  ///
  /// Nunca sobreescribe un código existente y sincroniza el código en
  /// `Administradores`, `usuarios` y los `secretarios` vinculados al `adminId`.
  static Future<String> obtenerOGenerarCodigoAdmin(String adminId) async {
    if (adminId.isEmpty) {
      throw ArgumentError('adminId no puede estar vacío');
    }

    final existente = await obtenerCodigoAdmin(adminId);
    if (existente.isNotEmpty) {
      return existente;
    }

    final db = FirebaseFirestore.instance;
    String nuevoCodigo = generarFormatoCodigo();

    // Verificar que el código no colisione con otro emprendimiento
    for (int intento = 0; intento < 5; intento++) {
      final colAdmin = await db
          .collection('Administradores')
          .where('codigoLive', isEqualTo: nuevoCodigo)
          .limit(1)
          .get();
      final colSec = await db
          .collection('secretarios')
          .where('codigoLive', isEqualTo: nuevoCodigo)
          .limit(1)
          .get();
      if (colAdmin.docs.isEmpty && colSec.docs.isEmpty) break;
      nuevoCodigo = generarFormatoCodigo();
    }

    final batch = db.batch();
    batch.set(db.collection('Administradores').doc(adminId), {
      'codigoLive': nuevoCodigo,
      'codigoActualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(db.collection('usuarios').doc(adminId), {
      'codigoLive': nuevoCodigo,
    }, SetOptions(merge: true));

    final secDocs = await db
        .collection('secretarios')
        .where('adminId', isEqualTo: adminId)
        .get();
    for (final doc in secDocs.docs) {
      batch.set(doc.reference, {
        'codigoLive': nuevoCodigo,
        'codigoActualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    return nuevoCodigo;
  }

  /// Construye la URL de la API REST gratuita de QuickChart QR (`https://quickchart.io/qr`).
  ///
  /// Utiliza nivel de corrección de errores alto (`ecLevel=H`, ~30%) para
  /// permitir la superposición del logo central de VendiX sin afectar la lectura.
  static String construirUrlQrQuickChart(
    String contenido, {
    int size = 500,
  }) {
    final uri = Uri.https('quickchart.io', '/qr', {
      'text': contenido,
      'size': size.toString(),
      'ecLevel': 'H',
      'margin': '2',
      'dark': '241B35',
      'light': 'FFFFFF',
      'format': 'png',
    });
    return uri.toString();
  }
}
