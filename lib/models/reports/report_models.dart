import 'package:cloud_firestore/cloud_firestore.dart';

/// Rol del usuario que solicita el reporte
enum ReportRole {
  administrador,
  secretario,
}

/// Registro individual de venta / compra en el reporte
class VentaItem {
  final String id;
  final String codigo;
  final DateTime fecha;
  final String clienteId;
  final String clienteNombre;
  final String prendaId;
  final String prendaNombre;
  final double precioUnitario;
  final int cantidad;
  final double subtotal;
  final String estado;
  final String jornadaId;
  final String registradoPorId;
  final String registradoPorNombre;
  final String rolResponsable;

  VentaItem({
    required this.id,
    required this.codigo,
    required this.fecha,
    required this.clienteId,
    required this.clienteNombre,
    required this.prendaId,
    required this.prendaNombre,
    required this.precioUnitario,
    required this.cantidad,
    required this.subtotal,
    required this.estado,
    required this.jornadaId,
    required this.registradoPorId,
    required this.registradoPorNombre,
    required this.rolResponsable,
  });

  factory VentaItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final f = data['fecha'];
    DateTime fechaFinal;
    if (f is Timestamp) {
      fechaFinal = f.toDate();
    } else if (f is DateTime) {
      fechaFinal = f;
    } else {
      fechaFinal = DateTime.now();
    }

    final pUnit = (data['precioUnitario'] ?? data['precio'] as num?)?.toDouble() ?? 0.0;
    final cant = (data['cantidad'] as num?)?.toInt() ?? 1;
    final sub = (data['subtotal'] ?? data['total'] as num?)?.toDouble() ?? (pUnit * cant);

    return VentaItem(
      id: doc.id,
      codigo: data['codigo']?.toString() ?? doc.id,
      fecha: fechaFinal,
      clienteId: data['clienteId']?.toString() ?? '',
      clienteNombre: data['clienteNombre']?.toString() ?? data['nombreCliente']?.toString() ?? 'Cliente',
      prendaId: data['prendaId']?.toString() ?? '',
      prendaNombre: data['prendaNombre']?.toString() ?? data['prenda']?.toString() ?? 'Prenda',
      precioUnitario: pUnit,
      cantidad: cant,
      subtotal: sub,
      estado: data['estado']?.toString() ?? 'confirmada',
      jornadaId: data['jornadaId']?.toString() ?? '',
      registradoPorId: data['registradoPorId']?.toString() ?? 'sin_asignar',
      registradoPorNombre: data['registradoPorNombre']?.toString() ?? 'Operador',
      rolResponsable: data['rolResponsable']?.toString() ?? 'secretario',
    );
  }
}

/// Registro individual de pago / abono en el reporte
class PagoItem {
  final String id;
  final String codigo;
  final DateTime fecha;
  final String clienteId;
  final String clienteNombre;
  final double monto;
  final String formaPago;
  final String observacion;
  final String jornadaId;
  final String recibidoPorId;
  final String recibidoPorNombre;
  final String rolResponsable;

  PagoItem({
    required this.id,
    required this.codigo,
    required this.fecha,
    required this.clienteId,
    required this.clienteNombre,
    required this.monto,
    required this.formaPago,
    required this.observacion,
    required this.jornadaId,
    required this.recibidoPorId,
    required this.recibidoPorNombre,
    required this.rolResponsable,
  });

  factory PagoItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final f = data['fecha'];
    DateTime fechaFinal;
    if (f is Timestamp) {
      fechaFinal = f.toDate();
    } else if (f is DateTime) {
      fechaFinal = f;
    } else {
      fechaFinal = DateTime.now();
    }

    final m = (data['monto'] as num?)?.toDouble() ?? 0.0;

    return PagoItem(
      id: doc.id,
      codigo: data['codigo']?.toString() ?? doc.id,
      fecha: fechaFinal,
      clienteId: data['clienteId']?.toString() ?? '',
      clienteNombre: data['clienteNombre']?.toString() ?? 'Cliente',
      monto: m,
      formaPago: data['formaPago']?.toString() ?? data['metodoPago']?.toString() ?? 'Efectivo',
      observacion: data['observacion']?.toString() ?? '',
      jornadaId: data['jornadaId']?.toString() ?? '',
      recibidoPorId: data['recibidoPorId']?.toString() ?? data['cobradoPorId']?.toString() ?? 'sin_asignar',
      recibidoPorNombre: data['recibidoPorNombre']?.toString() ?? data['cobradoPorNombre']?.toString() ?? 'Responsable',
      rolResponsable: data['rolResponsable']?.toString() ?? 'secretario',
    );
  }
}

/// Registro de cliente y saldo de cartera
class ClienteItem {
  final String id;
  final String codigo;
  final String nombre;
  final String telefono;
  final String correo;
  final String direccion;
  final double totalCompras;
  final double totalPagado;
  final double saldoPendiente;

  ClienteItem({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.telefono,
    required this.correo,
    required this.direccion,
    required this.totalCompras,
    required this.totalPagado,
    required this.saldoPendiente,
  });

  factory ClienteItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final comp = (data['totalCompras'] as num?)?.toDouble() ?? 0.0;
    final pag = (data['totalPagado'] as num?)?.toDouble() ?? 0.0;
    final saldo = data['saldoPendiente'] != null
        ? (data['saldoPendiente'] as num).toDouble()
        : (comp - pag).clamp(0.0, double.infinity);

    return ClienteItem(
      id: doc.id,
      codigo: data['codigo']?.toString() ?? doc.id,
      nombre: data['nombre']?.toString() ?? 'Sin Nombre',
      telefono: data['telefono']?.toString() ?? '',
      correo: data['correo']?.toString() ?? '',
      direccion: data['direccion']?.toString() ?? '',
      totalCompras: comp,
      totalPagado: pag,
      saldoPendiente: saldo,
    );
  }
}

/// Registro de prenda en catálogo e inventario
class PrendaItem {
  final String id;
  final String codigo;
  final String nombre;
  final double precio;
  final int stock;
  final bool activa;

  PrendaItem({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.precio,
    required this.stock,
    required this.activa,
  });

  factory PrendaItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return PrendaItem(
      id: doc.id,
      codigo: data['codigo']?.toString() ?? doc.id,
      nombre: data['nombre']?.toString() ?? 'Sin Nombre',
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      activa: data['activa'] == true,
    );
  }
}

/// Registro de jornada de venta en vivo
class JornadaItem {
  final String id;
  final String codigo;
  final String nombre;
  final DateTime fechaInicio;
  final bool activa;
  final double totalVendido;
  final double totalCobrado;

  JornadaItem({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.fechaInicio,
    required this.activa,
    required this.totalVendido,
    required this.totalCobrado,
  });

  factory JornadaItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final f = data['fechaInicio'] ?? data['fecha'];
    DateTime fInicio;
    if (f is Timestamp) {
      fInicio = f.toDate();
    } else if (f is DateTime) {
      fInicio = f;
    } else {
      fInicio = DateTime.now();
    }

    return JornadaItem(
      id: doc.id,
      codigo: data['codigo']?.toString() ?? doc.id,
      nombre: data['nombre']?.toString() ?? 'Jornada Live',
      fechaInicio: fInicio,
      activa: data['activa'] == true,
      totalVendido: (data['totalVendido'] as num?)?.toDouble() ?? 0.0,
      totalCobrado: (data['totalCobrado'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Rendimiento y ranking individual de un vendedor (Solo para Administrador)
class RendimientoVendedor {
  final String responsableId;
  final String nombre;
  final String rol;
  final int numeroVentas;
  final int unidadesVendidas;
  final double totalVendido;
  final double ticketPromedio;
  final double porcentajeParticipacion;
  final double cobrosRegistrados;

  RendimientoVendedor({
    required this.responsableId,
    required this.nombre,
    required this.rol,
    required this.numeroVentas,
    required this.unidadesVendidas,
    required this.totalVendido,
    required this.ticketPromedio,
    required this.porcentajeParticipacion,
    required this.cobrosRegistrados,
  });
}

/// Contenedor completo de datos consolidados listos para exportar
class ReportData {
  final String adminId;
  final String nombreEmprendimiento;
  final String generadoPorNombre;
  final ReportRole generadoPorRol;
  final DateTime fechaGeneracion;

  final List<VentaItem> ventas;
  final List<PagoItem> pagos;
  final List<ClienteItem> clientes;
  final List<PrendaItem> prendas;
  final List<JornadaItem> jornadas;
  final List<RendimientoVendedor>? ranking; // Exclusivo de Administrador

  final double totalVendido;
  final int totalPrendasVendidas;
  final double totalCobrado;
  final double saldoPendienteGlobal;

  ReportData({
    required this.adminId,
    required this.nombreEmprendimiento,
    required this.generadoPorNombre,
    required this.generadoPorRol,
    required this.fechaGeneracion,
    required this.ventas,
    required this.pagos,
    required this.clientes,
    required this.prendas,
    required this.jornadas,
    this.ranking,
    required this.totalVendido,
    required this.totalPrendasVendidas,
    required this.totalCobrado,
    required this.saldoPendienteGlobal,
  });
}
