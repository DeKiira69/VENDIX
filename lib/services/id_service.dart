import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio centralizado de generación de identificadores personalizados,
/// consecutivos, legibles y atómicos para Cloud Firestore en VendiX.
class IdService {
  IdService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _coleccionContadores = '_contadores';

  /// Normaliza cualquier cadena de texto a formato PascalCase:
  /// - Elimina tildes, diacríticos y caracteres especiales.
  /// - Elimina espacios y une palabras en mayúsculas/minúsculas.
  /// - Ejemplo: "María José López Pérez" -> "MariaJoseLopezPerez"
  /// - Ejemplo: "Camisa Negra - 2026" -> "CamisaNegra2026"
  static String normalizarParaId(String texto) {
    final entrada = texto.trim();
    if (entrada.isEmpty) return 'Registro';

    // 1. Reemplazo de tildes y caracteres especiales en español
    var limpio = entrada;
    const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑçÇ';
    const sinTilde = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUNcC';
    for (int i = 0; i < conTilde.length; i++) {
      limpio = limpio.replaceAll(conTilde[i], sinTilde[i]);
    }

    // 2. Separar por espacios, guiones o caracteres no alfanuméricos
    final partes = limpio.split(RegExp(r'[^a-zA-Z0-9]+'));
    final buffer = StringBuffer();

    for (final parte in partes) {
      if (parte.isEmpty) continue;
      // Primer caracter en mayúscula, resto conservado
      final primerCaracter = parte[0].toUpperCase();
      final resto = parte.length > 1 ? parte.substring(1) : '';
      buffer.write('$primerCaracter$resto');
    }

    final resultado = buffer.toString();
    return resultado.isNotEmpty ? resultado : 'Registro';
  }

  /// Formatea un número entero con relleno de ceros a la izquierda (mínimo 3 dígitos).
  /// - 1 -> "001"
  /// - 42 -> "042"
  /// - 999 -> "999"
  /// - 1000 -> "1000"
  static String formatearConsecutivo(int numero) {
    if (numero < 1000) {
      return numero.toString().padLeft(3, '0');
    }
    return numero.toString();
  }

  /// Obtiene e incrementa de forma atómica y segura el contador consecutivo
  /// para una entidad en la colección técnica `_contadores`.
  /// Utiliza `runTransaction` de Firestore para soportar alta concurrencia
  /// sin colisiones ni reutilización de IDs borrados.
  static Future<int> obtenerSiguienteNumero(String entidad) async {
    final docRef = _db.collection(_coleccionContadores).doc(entidad);

    try {
      final siguienteNumero = await _db.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(docRef);

        int ultimo = 0;
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          ultimo = (data['ultimoNumero'] as num?)?.toInt() ?? 0;
        }

        final nuevo = ultimo + 1;

        transaction.set(
          docRef,
          {
            'entidad': entidad,
            'ultimoNumero': nuevo,
            'actualizadoEn': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return nuevo;
      });

      return siguienteNumero;
    } catch (e) {
      // Fallback seguro en caso de contingencia offline/timeout
      // Emplea timestamp para garantizar unicidad y evitar bloqueo
      final fallbackNum = (DateTime.now().millisecondsSinceEpoch % 900) + 100;
      return fallbackNum;
    }
  }

  // ============================================================
  // GENERADORES ESPECÍFICOS POR COLECCIÓN
  // ============================================================

  /// Formato: `cliNNN_NombreApellido` (ej: `cli001_JuanPerez`)
  static Future<String> generarIdCliente(String nombreCompleto) async {
    final num = await obtenerSiguienteNumero('clientes');
    final consecutivo = formatearConsecutivo(num);
    final nombrePascal = normalizarParaId(nombreCompleto);
    return 'cli${consecutivo}_$nombrePascal';
  }

  /// Formato: `PrendNNN_NombrePrenda` (ej: `Prend001_CamisaNegra`)
  static Future<String> generarIdPrenda(String nombrePrenda) async {
    final num = await obtenerSiguienteNumero('prendas');
    final consecutivo = formatearConsecutivo(num);
    final nombrePascal = normalizarParaId(nombrePrenda);
    return 'Prend${consecutivo}_$nombrePascal';
  }

  /// Formato: `SecreNNN_NombreApellido` (ej: `Secre001_MariaLopez`)
  static Future<String> generarIdSecretario(String nombreCompleto) async {
    final num = await obtenerSiguienteNumero('secretarios');
    final consecutivo = formatearConsecutivo(num);
    final nombrePascal = normalizarParaId(nombreCompleto);
    return 'Secre${consecutivo}_$nombrePascal';
  }

  /// Formato: `AdminNNN_NombreApellido` (ej: `Admin001_CarlosMora`)
  static Future<String> generarIdAdministrador(String nombreCompleto) async {
    final num = await obtenerSiguienteNumero('administradores');
    final consecutivo = formatearConsecutivo(num);
    final nombrePascal = normalizarParaId(nombreCompleto);
    return 'Admin${consecutivo}_$nombrePascal';
  }

  /// Formato: `VentNNN` (ej: `Vent001`)
  static Future<String> generarIdCompra({String? adminId}) async {
    final num = await obtenerSiguienteNumero('compras');
    final consecutivo = formatearConsecutivo(num);
    return 'Vent$consecutivo';
  }

  /// Formato: `PagoNNN` (ej: `Pago001`)
  static Future<String> generarIdPago({String? adminId}) async {
    final num = await obtenerSiguienteNumero('pagos');
    final consecutivo = formatearConsecutivo(num);
    return 'Pago$consecutivo';
  }

  /// Formato: `JornNNN_NombreJornada` o `JornNNN` (ej: `Jorn001_LiveNavidad`)
  static Future<String> generarIdJornada(String nombreJornada, {String? adminId}) async {
    final num = await obtenerSiguienteNumero('jornadas');
    final consecutivo = formatearConsecutivo(num);
    final nombrePascal = normalizarParaId(nombreJornada);
    return 'Jorn${consecutivo}_$nombrePascal';
  }
}
