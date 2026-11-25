import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'id_service.dart';

class ClientService {
  ClientService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Estado de la sesión activa del secretario (soporte multi-emprendimiento)
  static String? activeSecretaryAdminId;
  static String? activeSecretaryNombreEmprendimiento;
  static String? activeSecretaryAdminNombre;

  static void setActiveSecretarySession({
    required String adminId,
    String? nombreEmprendimiento,
    String? adminNombre,
  }) {
    activeSecretaryAdminId = adminId;
    if (nombreEmprendimiento != null) {
      activeSecretaryNombreEmprendimiento = nombreEmprendimiento;
    }
    if (adminNombre != null) {
      activeSecretaryAdminNombre = adminNombre;
    }
  }

  /// Limpia la sesión y estado al cerrar sesión.
  static void limpiarCache() {
    activeSecretaryAdminId = null;
    activeSecretaryNombreEmprendimiento = null;
    activeSecretaryAdminNombre = null;
  }

  // Identificador del usuario que inició sesión.
  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================
  // CLIENTES
  // ============================================================

  // Busca la ficha del cliente vinculado a la cuenta actual en tiempo real.
  static Stream<Map<String, dynamic>?> clienteActual() {
    final usuarioId = uid;

    if (usuarioId == null || usuarioId.isEmpty) {
      return Stream.value(null);
    }

    return _db
        .collection('clientes')
        .where('uid', isEqualTo: usuarioId)
        .limit(1)
        .snapshots()
        .map((resultado) {
          if (resultado.docs.isEmpty) return null;

          final documento = resultado.docs.first;
          return {...documento.data(), 'id': documento.id};
        });
  }

  // Obtiene todos los clientes para el módulo de secretaria.
  static Stream<List<Map<String, dynamic>>> todosLosClientes() {
    return _db.collection('clientes').snapshots().map((resultado) {
      return resultado.docs.map((documento) {
        return {...documento.data(), 'id': documento.id};
      }).toList();
    });
  }

  // Registra una nueva ficha comercial con identificador consecutivo cliNNN_NombreApellido.
  static Future<String> registrarCliente({
    required String nombre,
    required String telefono,
    String direccion = '',
    String? uidCliente,
    String correo = '',
    String? adminId,
  }) async {
    final nombreLimpio = nombre.trim();
    final telefonoLimpio = telefono.trim();

    if (nombreLimpio.isEmpty || telefonoLimpio.isEmpty) {
      throw ArgumentError(
        'El nombre y el teléfono del cliente son obligatorios.',
      );
    }

    final idCliente = await IdService.generarIdCliente(nombreLimpio);

    String adminIdFinal = adminId ?? activeSecretaryAdminId ?? '';
    if (adminIdFinal.isEmpty) {
      adminIdFinal = uid ?? '';
    }

    final referencia = _db.collection('clientes').doc(idCliente);

    await referencia.set({
      'id': idCliente,
      'codigo': idCliente,
      'nombre': nombreLimpio,
      'telefono': telefonoLimpio,
      'direccion': direccion.trim(),
      'correo': correo.trim(),
      'uid': uidCliente ?? '',
      'firebaseUid': uidCliente ?? '',
      'adminId': adminIdFinal,
      'saldoPendiente': 0.0,
      'totalCompras': 0.0,
      'totalPagado': 0.0,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    return idCliente;
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

  // Obtiene las compras de un cliente específico en tiempo real directamente de Firestore.
  static Stream<List<Map<String, dynamic>>> compras(String clienteId) {
    if (clienteId.trim().isEmpty) return Stream.value(const []);

    return _db
        .collection('compras')
        .where('clienteId', isEqualTo: clienteId.trim())
        .snapshots()
        .map((resultado) {
          final lista = resultado.docs.map((documento) {
            return {...documento.data(), 'id': documento.id};
          }).toList();

          lista.sort((a, b) => fecha(b['fecha']).compareTo(fecha(a['fecha'])));

          return lista;
        });
  }

  // Registra una compra para un cliente con ID consecutivo VentNNN y trazabilidad completa.
  static Future<String> registrarCompra({
    required String clienteId,
    required String prendaNombre,
    required double precioUnitario,
    required int cantidad,
    String? prendaId,
    String? jornadaId,
  }) async {
    if (clienteId.trim().isEmpty ||
        prendaNombre.trim().isEmpty ||
        precioUnitario <= 0 ||
        cantidad <= 0) {
      throw ArgumentError(
        'Revisa el cliente, la prenda, el precio y la cantidad.',
      );
    }

    final meta = await obtenerMetadatosVenta(clienteId);
    final adminId = meta['adminId']?.toString() ?? '';
    final idVenta = await IdService.generarIdCompra(adminId: adminId);
    final referencia = _db.collection('compras').doc(idVenta);

    final jornadaFinal = jornadaId ?? meta['jornadaId'];

    await referencia.set({
      'id': idVenta,
      'codigo': idVenta,
      'clienteId': clienteId,
      'prendaId': prendaId,
      'prendaNombre': prendaNombre.trim(),
      'prenda': prendaNombre.trim(),
      'precioUnitario': precioUnitario,
      'precio': precioUnitario,
      'cantidad': cantidad,
      'subtotal': precioUnitario * cantidad,
      'total': precioUnitario * cantidad,
      'jornadaId': jornadaFinal,
      'fecha': FieldValue.serverTimestamp(),
      ...meta,
    });

    return idVenta;
  }

  // ============================================================
  // PAGOS
  // ============================================================

  // Obtiene los pagos de un cliente específico en tiempo real directamente de Firestore.
  static Stream<List<Map<String, dynamic>>> pagos(String clienteId) {
    if (clienteId.trim().isEmpty) return Stream.value(const []);

    return _db
        .collection('pagos')
        .where('clienteId', isEqualTo: clienteId.trim())
        .snapshots()
        .map((resultado) {
          final lista = resultado.docs.map((documento) {
            return {...documento.data(), 'id': documento.id};
          }).toList();

          lista.sort((a, b) => fecha(b['fecha']).compareTo(fecha(a['fecha'])));

          return lista;
        });
  }

  // Registra un abono para un cliente con ID consecutivo PagoNNN y trazabilidad de recaudación.
  static Future<String> registrarPago({
    required String clienteId,
    required double monto,
    String observacion = '',
    String formaPago = 'Efectivo',
    String? jornadaId,
  }) async {
    if (clienteId.trim().isEmpty || monto <= 0) {
      throw ArgumentError(
        'Selecciona un cliente e introduce un monto positivo.',
      );
    }

    final meta = await obtenerMetadatosPago(clienteId);
    final adminId = meta['adminId']?.toString() ?? '';
    final idPago = await IdService.generarIdPago(adminId: adminId);
    final referencia = _db.collection('pagos').doc(idPago);

    final jornadaFinal = jornadaId ?? meta['jornadaId'];

    await referencia.set({
      'id': idPago,
      'codigo': idPago,
      'clienteId': clienteId,
      'monto': monto,
      'formaPago': formaPago,
      'metodoPago': formaPago,
      'observacion': observacion.trim(),
      'jornadaId': jornadaFinal,
      'fecha': FieldValue.serverTimestamp(),
      ...meta,
    });

    return idPago;
  }

  // ============================================================
  // CÁLCULOS Y METADATOS DE TRAZABILIDAD
  // ============================================================

  /// Resuelve los metadatos de autoría, tienda (adminId) y jornada activa para vincular cada venta.
  static Future<Map<String, dynamic>> obtenerMetadatosVenta(String clienteId) async {
    final user = FirebaseAuth.instance.currentUser;
    final userUid = user?.uid ?? '';
    String adminId = activeSecretaryAdminId ?? '';
    String rolResponsable = 'secretario';
    String registradoPorNombre = user?.displayName ?? '';

    if (userUid.isNotEmpty) {
      try {
        final uDoc = await _db.collection('usuarios').doc(userUid).get();
        final uData = uDoc.data() ?? {};
        final rol = uData['rol']?.toString().toLowerCase() ?? '';
        final nom = uData['nombre']?.toString() ?? '';
        final ape = uData['apellido']?.toString() ?? '';
        final nComp = [nom, ape].where((s) => s.isNotEmpty).join(' ');
        if (nComp.isNotEmpty) registradoPorNombre = nComp;

        if (rol == 'administrador' || rol == 'admin') {
          rolResponsable = 'administrador';
          if (adminId.isEmpty) {
            adminId = uData['adminId']?.toString() ?? userUid;
          }
        } else {
          if (adminId.isEmpty) {
            adminId = uData['adminId']?.toString() ?? '';
          }
        }
      } catch (_) {}
    }

    if (adminId.isEmpty && clienteId.isNotEmpty) {
      try {
        final cDoc = await _db.collection('clientes').doc(clienteId).get();
        adminId = cDoc.data()?['adminId']?.toString() ?? '';
      } catch (_) {}
    }

    // Vincular jornada activa si existe para este emprendimiento
    String? jornadaId;
    if (adminId.isNotEmpty) {
      try {
        final jSnap = await _db
            .collection('jornadas')
            .where('adminId', isEqualTo: adminId)
            .where('estado', isEqualTo: 'activa')
            .limit(1)
            .get();
        if (jSnap.docs.isNotEmpty) {
          jornadaId = jSnap.docs.first.id;
        }
      } catch (_) {}
    }

    return {
      'adminId': adminId,
      'registradoPorId': userUid,
      'registradoPorNombre': registradoPorNombre.isNotEmpty
          ? registradoPorNombre
          : (rolResponsable == 'administrador' ? 'Emprendedor' : 'Secretario'),
      'rolResponsable': rolResponsable,
      'estado': 'confirmada',
      'jornadaId': jornadaId,
    };
  }

  /// Resuelve los metadatos de autoría y tienda para registrar pagos.
  static Future<Map<String, dynamic>> obtenerMetadatosPago(String clienteId) async {
    final user = FirebaseAuth.instance.currentUser;
    final userUid = user?.uid ?? '';
    String adminId = activeSecretaryAdminId ?? '';
    String rolResponsable = 'secretario';
    String recibidoPorNombre = user?.displayName ?? '';

    if (userUid.isNotEmpty) {
      try {
        final uDoc = await _db.collection('usuarios').doc(userUid).get();
        final uData = uDoc.data() ?? {};
        final rol = uData['rol']?.toString().toLowerCase() ?? '';
        final nom = uData['nombre']?.toString() ?? '';
        final ape = uData['apellido']?.toString() ?? '';
        final nComp = [nom, ape].where((s) => s.isNotEmpty).join(' ');
        if (nComp.isNotEmpty) recibidoPorNombre = nComp;

        if (rol == 'administrador' || rol == 'admin') {
          rolResponsable = 'administrador';
          if (adminId.isEmpty) {
            adminId = uData['adminId']?.toString() ?? userUid;
          }
        } else {
          if (adminId.isEmpty) {
            adminId = uData['adminId']?.toString() ?? '';
          }
        }
      } catch (_) {}
    }

    if (adminId.isEmpty && clienteId.isNotEmpty) {
      try {
        final cDoc = await _db.collection('clientes').doc(clienteId).get();
        adminId = cDoc.data()?['adminId']?.toString() ?? '';
      } catch (_) {}
    }

    // Vincular jornada activa si existe para este emprendimiento
    String? jornadaId;
    if (adminId.isNotEmpty) {
      try {
        final jSnap = await _db
            .collection('jornadas')
            .where('adminId', isEqualTo: adminId)
            .where('estado', isEqualTo: 'activa')
            .limit(1)
            .get();
        if (jSnap.docs.isNotEmpty) {
          jornadaId = jSnap.docs.first.id;
        }
      } catch (_) {}
    }

    return {
      'adminId': adminId,
      'recibidoPorId': userUid,
      'recibidoPorNombre': recibidoPorNombre.isNotEmpty
          ? recibidoPorNombre
          : (rolResponsable == 'administrador' ? 'Emprendedor' : 'Secretario'),
      'cobradoPorId': userUid,
      'cobradoPorNombre': recibidoPorNombre.isNotEmpty
          ? recibidoPorNombre
          : (rolResponsable == 'administrador' ? 'Emprendedor' : 'Secretario'),
      'rolResponsable': rolResponsable,
      'jornadaId': jornadaId,
    };
  }

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
