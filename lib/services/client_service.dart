import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientService {
  ClientService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream caché para evitar abrir múltiples conexiones simultáneas
  static Stream<Map<String, dynamic>?>? _clienteActualStream;
  static String? _clienteActualUid;
  static final Map<String, Stream<List<Map<String, dynamic>>>> _comprasStreamCache = {};
  static final Map<String, Stream<List<Map<String, dynamic>>>> _pagosStreamCache = {};

  /// Limpia los streams cacheados al cerrar sesión.
  static void limpiarCache() {
    _clienteActualStream = null;
    _clienteActualUid = null;
    _comprasStreamCache.clear();
    _pagosStreamCache.clear();
  }

  // Identificador del usuario que inició sesión.
  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================
  // CLIENTES
  // ============================================================

  // Busca la ficha del cliente vinculado a la cuenta actual con stream compartido.
  static Stream<Map<String, dynamic>?> clienteActual() {
    final usuarioId = uid;

    if (usuarioId == null) {
      return Stream.value(null);
    }

    if (_clienteActualStream != null && _clienteActualUid == usuarioId) {
      return _clienteActualStream!;
    }

    _clienteActualUid = usuarioId;
    _clienteActualStream = _db
        .collection('clientes')
        .where('uid', isEqualTo: usuarioId)
        .limit(1)
        .snapshots()
        .map((resultado) {
          if (resultado.docs.isEmpty) return null;

          final documento = resultado.docs.first;
          return {...documento.data(), 'id': documento.id};
        })
        .asBroadcastStream();

    return _clienteActualStream!;
  }

  // Obtiene todos los clientes para el módulo de secretaria.
  static Stream<List<Map<String, dynamic>>> todosLosClientes() {
    return _db.collection('clientes').snapshots().map((resultado) {
      return resultado.docs.map((documento) {
        return {...documento.data(), 'id': documento.id};
      }).toList();
    });
  }

  // Registra una nueva ficha comercial.
  static Future<String> registrarCliente({
    required String nombre,
    required String telefono,
    String direccion = '',
    String? uidCliente,
    String correo = '',
  }) async {
    final nombreLimpio = nombre.trim();
    final telefonoLimpio = telefono.trim();

    if (nombreLimpio.isEmpty || telefonoLimpio.isEmpty) {
      throw ArgumentError(
        'El nombre y el teléfono del cliente son obligatorios.',
      );
    }

    final referencia = _db.collection('clientes').doc();

    await referencia.set({
      'nombre': nombreLimpio,
      'telefono': telefonoLimpio,
      'direccion': direccion.trim(),
      'correo': correo.trim(),
      'uid': uidCliente,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    return referencia.id;
  }

  // Actualiza los datos personales de un cliente en Firestore y Firebase Auth.
  static Future<void> actualizarCliente({
    required String clienteId,
    required String nombre,
    required String telefono,
    required String direccion,
  }) async {
    final nombreLimpio = nombre.trim();
    final telefonoLimpio = telefono.trim();
    final direccionLimpia = direccion.trim();

    if (nombreLimpio.isEmpty || telefonoLimpio.isEmpty) {
      throw ArgumentError(
        'El nombre y el teléfono son obligatorios.',
      );
    }

    // 1. Actualizar documento en la colección 'clientes'
    await _db.collection('clientes').doc(clienteId).update({
      'nombre': nombreLimpio,
      'telefono': telefonoLimpio,
      'direccion': direccionLimpia,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    // 2. Sincronizar también en la colección 'usuarios' si existe UID
    final usuarioId = uid;
    if (usuarioId != null) {
      try {
        await _db.collection('usuarios').doc(usuarioId).set({
          'nombre': nombreLimpio,
          'telefono': telefonoLimpio,
          'direccion': direccionLimpia,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // 3. Actualizar el displayName en Firebase Auth
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(nombreLimpio);
      } catch (_) {}
    }
  }

  // ============================================================
  // COMPRAS
  // ============================================================

  // Obtiene las compras de un cliente específico con broadcast stream.
  static Stream<List<Map<String, dynamic>>> compras(String clienteId) {
    if (_comprasStreamCache.containsKey(clienteId)) {
      return _comprasStreamCache[clienteId]!;
    }

    final stream = _db
        .collection('compras')
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((resultado) {
          final lista = resultado.docs.map((documento) {
            return {...documento.data(), 'id': documento.id};
          }).toList();

          lista.sort((a, b) => fecha(b['fecha']).compareTo(fecha(a['fecha'])));

          return lista;
        })
        .asBroadcastStream();

    _comprasStreamCache[clienteId] = stream;
    return stream;
  }

  // Registra una compra para un cliente.
  static Future<String> registrarCompra({
    required String clienteId,
    required String prendaNombre,
    required double precioUnitario,
    required int cantidad,
  }) async {
    if (clienteId.trim().isEmpty ||
        prendaNombre.trim().isEmpty ||
        precioUnitario <= 0 ||
        cantidad <= 0) {
      throw ArgumentError(
        'Revisa el cliente, la prenda, el precio y la cantidad.',
      );
    }

    final referencia = _db.collection('compras').doc();

    await referencia.set({
      'clienteId': clienteId,
      'prendaNombre': prendaNombre.trim(),
      'precioUnitario': precioUnitario,
      'cantidad': cantidad,
      'subtotal': precioUnitario * cantidad,
      'fecha': FieldValue.serverTimestamp(),
    });

    return referencia.id;
  }

  // ============================================================
  // PAGOS
  // ============================================================

  // Obtiene los pagos de un cliente específico con broadcast stream.
  static Stream<List<Map<String, dynamic>>> pagos(String clienteId) {
    if (_pagosStreamCache.containsKey(clienteId)) {
      return _pagosStreamCache[clienteId]!;
    }

    final stream = _db
        .collection('pagos')
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((resultado) {
          final lista = resultado.docs.map((documento) {
            return {...documento.data(), 'id': documento.id};
          }).toList();

          lista.sort((a, b) => fecha(b['fecha']).compareTo(fecha(a['fecha'])));

          return lista;
        })
        .asBroadcastStream();

    _pagosStreamCache[clienteId] = stream;
    return stream;
  }

  // Registra un abono para un cliente.
  static Future<String> registrarPago({
    required String clienteId,
    required double monto,
    String observacion = '',
  }) async {
    if (clienteId.trim().isEmpty || monto <= 0) {
      throw ArgumentError(
        'Selecciona un cliente e introduce un monto positivo.',
      );
    }

    final referencia = _db.collection('pagos').doc();

    await referencia.set({
      'clienteId': clienteId,
      'monto': monto,
      'observacion': observacion.trim(),
      'fecha': FieldValue.serverTimestamp(),
    });

    return referencia.id;
  }

  // ============================================================
  // CÁLCULOS Y UTILIDADES
  // ============================================================

  // Convierte los valores numéricos que devuelve Firestore.
  static double numero(dynamic valor) {
    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Formatea un valor monetario.
  static String dinero(dynamic valor) {
    return '\$${numero(valor).toStringAsFixed(2)}';
  }

  // Convierte fechas de Firestore a DateTime.
  static DateTime fecha(dynamic valor) {
    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    return DateTime(2000);
  }

  // Calcula el total comprado a partir de una lista de compras.
  static double calcularTotalComprado(List<Map<String, dynamic>> listaCompras) {
    return listaCompras.fold<double>(0, (total, compra) {
      final subtotal = compra['subtotal'] is num
          ? numero(compra['subtotal'])
          : numero(compra['precioUnitario']) * numero(compra['cantidad']);

      return total + subtotal;
    });
  }

  // Calcula el total pagado.
  static double calcularTotalPagado(List<Map<String, dynamic>> listaPagos) {
    return listaPagos.fold<double>(
      0,
      (total, pago) => total + numero(pago['monto']),
    );
  }

  // Calcula el saldo pendiente sin mostrar valores negativos.
  static double calcularSaldo({
    required double totalComprado,
    required double totalPagado,
  }) {
    final saldo = totalComprado - totalPagado;
    return saldo > 0 ? saldo : 0;
  }
}
