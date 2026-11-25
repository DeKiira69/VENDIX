import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/reports/report_models.dart';
import 'report_permission_service.dart';

/// Servicio responsable de consultar Cloud Firestore, filtrar con base en permisos
/// y estructurar los datos listos para el generador de reportes Excel.
class ReportDataService {
  ReportDataService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Recopila de forma exhaustiva los datos comerciales autorizados
  static Future<ReportData> recopilarDatos({
    required ReportPermissionResult permiso,
  }) async {
    final targetAdminId = permiso.adminId;
    final rol = permiso.rol ?? ReportRole.secretario;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // 1. Clientes asociados al emprendimiento
    final clientesSnap = await _db.collection('clientes').get();
    final clientesFiltrados = clientesSnap.docs.where((d) {
      final aId = d.data()['adminId']?.toString() ?? '';
      return aId == targetAdminId;
    }).map((d) => ClienteItem.fromFirestore(d)).toList();

    // Set de IDs para soporte de clientes vinculados
    final misClientesIds = clientesFiltrados.map((c) => c.id).toSet();

    // 2. Historial de Ventas / Compras del emprendimiento
    final comprasSnap = await _db.collection('compras').get();
    final List<VentaItem> ventasFiltradas = [];

    for (final doc in comprasSnap.docs) {
      final data = doc.data();
      final aId = data['adminId']?.toString() ?? '';
      final cId = data['clienteId']?.toString() ?? '';

      // Pertenece a este negocio si coincide el adminId o el clienteId de la tienda
      if (aId == targetAdminId || misClientesIds.contains(cId)) {
        ventasFiltradas.add(VentaItem.fromFirestore(doc));
      }
    }

    // Ordenar ventas por fecha descendente
    ventasFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));

    // 3. Historial de Pagos y Abonos
    // Regla de Permisos:
    // - Administrador: Ve todos los cobros de su emprendimiento.
    // - Secretario: Únicamente ve los cobros recaudados por él mismo (recibidoPorId == currentUid).
    final pagosSnap = await _db.collection('pagos').get();
    final List<PagoItem> pagosFiltrados = [];

    for (final doc in pagosSnap.docs) {
      final data = doc.data();
      final aId = data['adminId']?.toString() ?? '';
      final cId = data['clienteId']?.toString() ?? '';

      if (aId == targetAdminId || misClientesIds.contains(cId)) {
        final pagoItem = PagoItem.fromFirestore(doc);

        if (rol == ReportRole.administrador) {
          pagosFiltrados.add(pagoItem);
        } else {
          // El secretario solo ve los cobros que él mismo registró
          if (pagoItem.recibidoPorId == currentUid) {
            pagosFiltrados.add(pagoItem);
          }
        }
      }
    }

    // Ordenar pagos por fecha descendente
    pagosFiltrados.sort((a, b) => b.fecha.compareTo(a.fecha));

    // 4. Catálogo de Prendas e Inventario
    final prendasSnap = await _db.collection('prendas').get();
    final prendasFiltradas = prendasSnap.docs.where((d) {
      final aId = d.data()['adminId']?.toString() ?? '';
      return aId.isEmpty || aId == targetAdminId;
    }).map((d) => PrendaItem.fromFirestore(d)).toList();

    // 5. Historial de Jornadas Live
    final jornadasSnap = await _db.collection('jornadas').get();
    final jornadasFiltradas = jornadasSnap.docs.where((d) {
      final aId = d.data()['adminId']?.toString() ?? '';
      return aId == targetAdminId;
    }).map((d) => JornadaItem.fromFirestore(d)).toList();

    jornadasFiltradas.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));

    // 6. Totales y Métricas Globales
    double totalVendido = 0.0;
    int totalPrendasVendidas = 0;
    for (final v in ventasFiltradas) {
      totalVendido += v.subtotal;
      totalPrendasVendidas += v.cantidad;
    }

    double totalCobrado = 0.0;
    for (final p in pagosFiltrados) {
      totalCobrado += p.monto;
    }

    double saldoPendienteGlobal = 0.0;
    for (final c in clientesFiltrados) {
      saldoPendienteGlobal += c.saldoPendiente;
    }

    // 7. Ranking de Vendedores (Exclusivo de Administrador)
    List<RendimientoVendedor>? ranking;

    if (rol == ReportRole.administrador) {
      final mapaRendimiento = <String, Map<String, dynamic>>{};

      for (final venta in ventasFiltradas) {
        final rId = venta.registradoPorId;
        final rNom = venta.registradoPorNombre;
        final rRol = venta.rolResponsable;

        if (!mapaRendimiento.containsKey(rId)) {
          mapaRendimiento[rId] = {
            'id': rId,
            'nombre': rNom,
            'rol': rRol,
            'ventas': 0,
            'prendas': 0,
            'total': 0.0,
            'cobros': 0.0,
          };
        }

        mapaRendimiento[rId]!['ventas'] = (mapaRendimiento[rId]!['ventas'] as int) + 1;
        mapaRendimiento[rId]!['prendas'] = (mapaRendimiento[rId]!['prendas'] as int) + venta.cantidad;
        mapaRendimiento[rId]!['total'] = (mapaRendimiento[rId]!['total'] as double) + venta.subtotal;
      }

      // Añadir cobros por responsable
      for (final pago in pagosFiltrados) {
        final rId = pago.recibidoPorId;
        final rNom = pago.recibidoPorNombre;
        final rRol = pago.rolResponsable;

        if (!mapaRendimiento.containsKey(rId)) {
          mapaRendimiento[rId] = {
            'id': rId,
            'nombre': rNom,
            'rol': rRol,
            'ventas': 0,
            'prendas': 0,
            'total': 0.0,
            'cobros': 0.0,
          };
        }

        mapaRendimiento[rId]!['cobros'] = (mapaRendimiento[rId]!['cobros'] as double) + pago.monto;
      }

      ranking = mapaRendimiento.values.map((v) {
        final tot = v['total'] as double;
        final nV = v['ventas'] as int;
        final ticket = nV > 0 ? (tot / nV) : 0.0;
        final participacion = totalVendido > 0 ? ((tot / totalVendido) * 100) : 0.0;

        return RendimientoVendedor(
          responsableId: v['id'] as String,
          nombre: v['nombre'] as String,
          rol: v['rol'] as String,
          numeroVentas: nV,
          unidadesVendidas: v['prendas'] as int,
          totalVendido: tot,
          ticketPromedio: ticket,
          porcentajeParticipacion: participacion,
          cobrosRegistrados: v['cobros'] as double,
        );
      }).toList();

      ranking.sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
    }

    return ReportData(
      adminId: targetAdminId,
      nombreEmprendimiento: permiso.nombreEmprendimiento,
      generadoPorNombre: permiso.nombreUsuario,
      generadoPorRol: rol,
      fechaGeneracion: DateTime.now(),
      ventas: ventasFiltradas,
      pagos: pagosFiltrados,
      clientes: clientesFiltrados,
      prendas: prendasFiltradas,
      jornadas: jornadasFiltradas,
      ranking: ranking,
      totalVendido: totalVendido,
      totalPrendasVendidas: totalPrendasVendidas,
      totalCobrado: totalCobrado,
      saldoPendienteGlobal: saldoPendienteGlobal,
    );
  }
}
