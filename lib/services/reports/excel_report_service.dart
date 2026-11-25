import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reports/report_models.dart';

/// Servicio responsable de generar el archivo XLSX (Excel) a partir de la plantilla
/// local o construir la estructura tabular limpia si la plantilla aún no fue suministrada.
class ExcelReportService {
  ExcelReportService._();

  /// Genera los bytes del archivo XLSX formateado con los datos comerciales autorizados
  static Future<Uint8List> generarArchivoExcel(ReportData data) async {
    final esAdmin = data.generadoPorRol == ReportRole.administrador;
    final rutaPlantilla = esAdmin
        ? 'assets/templates/VendiX_Admin.xlsx'
        : 'assets/templates/VendiX_Secretario.xlsx';

    Excel excel;

    // 1. Intentar cargar la plantilla maestra si existe en assets
    try {
      final ByteData raw = await rootBundle.load(rutaPlantilla);
      final bytes = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      // Si la plantilla aún no fue agregada por el desarrollador a assets,
      // creamos un libro de trabajo Excel profesional desde cero
      excel = Excel.createExcel();
    }

    if (esAdmin) {
      _llenarLibroAdministrador(excel, data);
    } else {
      _llenarLibroSecretario(excel, data);
    }

    // Si existe la hoja por defecto "Sheet1" y se han creado otras, eliminarla
    if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
      excel.delete('Sheet1');
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Error al codificar el archivo Excel.');
    }

    return Uint8List.fromList(encoded);
  }

  /// Estructura completa de hojas para el rol Administrador
  static void _llenarLibroAdministrador(Excel excel, ReportData data) {
    _llenarHojaResumenAdmin(excel, data);
    _llenarHojaVentas(excel, data);
    _llenarHojaCobros(excel, data, esAdmin: true);
    _llenarHojaClientes(excel, data);
    _llenarHojaInventario(excel, data);
    _llenarHojaJornadas(excel, data);
    if (data.ranking != null) {
      _llenarHojaRanking(excel, data);
    }
  }

  /// Estructura de hojas autorizadas para el rol Secretario
  static void _llenarLibroSecretario(Excel excel, ReportData data) {
    _llenarHojaResumenSecretario(excel, data);
    _llenarHojaVentas(excel, data);
    _llenarHojaCobros(excel, data, esAdmin: false); // Solo sus cobros
    _llenarHojaClientes(excel, data);
    _llenarHojaInventario(excel, data);
    _llenarHojaJornadas(excel, data);
    // IMPORTANTE: Jamás se crea la hoja de Ranking ni comparativas para el secretario
  }

  // ─── HOJAS DE RESUMEN ───

  static void _llenarHojaResumenAdmin(Excel excel, ReportData data) {
    final sheet = excel['Resumen General'];
    sheet.isRTL = false;

    sheet.appendRow([TextCellValue('VENDIX — REPORTE COMERCIAL CONSOLIDADO')]);
    sheet.appendRow([TextCellValue('Emprendimiento:'), TextCellValue(data.nombreEmprendimiento)]);
    sheet.appendRow([TextCellValue('Generado por:'), TextCellValue('${data.generadoPorNombre} (Administrador)')]);
    sheet.appendRow([TextCellValue('Fecha y Hora (Ecuador):'), TextCellValue(_formatearFecha(data.fechaGeneracion))]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([TextCellValue('MÉTRICA COMERCIAL'), TextCellValue('VALOR CONSOLIDADO')]);
    sheet.appendRow([TextCellValue('Total Facturado / Vendido:'), TextCellValue('\$ ${data.totalVendido.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Total Recaudado / Cobrado:'), TextCellValue('\$ ${data.totalCobrado.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Saldo Pendiente en Cartera:'), TextCellValue('\$ ${data.saldoPendienteGlobal.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Prendas Vendidas:'), IntCellValue(data.totalPrendasVendidas)]);
    sheet.appendRow([TextCellValue('Número de Ventas Registradas:'), IntCellValue(data.ventas.length)]);
    sheet.appendRow([TextCellValue('Total de Clientes en Cartera:'), IntCellValue(data.clientes.length)]);
    sheet.appendRow([TextCellValue('Total de Artículos en Catálogo:'), IntCellValue(data.prendas.length)]);
    sheet.appendRow([TextCellValue('Total de Jornadas Live:'), IntCellValue(data.jornadas.length)]);
  }

  static void _llenarHojaResumenSecretario(Excel excel, ReportData data) {
    final sheet = excel['Resumen Operativo'];
    sheet.isRTL = false;

    sheet.appendRow([TextCellValue('VENDIX — REPORTE OPERATIVO DE APOYO')]);
    sheet.appendRow([TextCellValue('Emprendimiento:'), TextCellValue(data.nombreEmprendimiento)]);
    sheet.appendRow([TextCellValue('Secretario responsable:'), TextCellValue(data.generadoPorNombre)]);
    sheet.appendRow([TextCellValue('Fecha y Hora (Ecuador):'), TextCellValue(_formatearFecha(data.fechaGeneracion))]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([TextCellValue('INDICADOR OPERATIVO'), TextCellValue('VALOR REGISTRADO')]);
    sheet.appendRow([TextCellValue('Ventas Totales en Tienda:'), IntCellValue(data.ventas.length)]);
    sheet.appendRow([TextCellValue('Prendas Totales Asignadas:'), IntCellValue(data.totalPrendasVendidas)]);
    sheet.appendRow([TextCellValue('Cobros Registrados por Mí:'), TextCellValue('\$ ${data.totalCobrado.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Número de Cobros Realizados:'), IntCellValue(data.pagos.length)]);
    sheet.appendRow([TextCellValue('Prendas Activas en Catálogo:'), IntCellValue(data.prendas.length)]);
  }

  // ─── HOJAS DE DATOS COMERCIALES ───

  static void _llenarHojaVentas(Excel excel, ReportData data) {
    final sheet = excel['Historial Ventas'];
    sheet.isRTL = false;

    sheet.appendRow([
      TextCellValue('Código Venta'),
      TextCellValue('Fecha y Hora'),
      TextCellValue('Cliente'),
      TextCellValue('Código Cliente'),
      TextCellValue('Prenda'),
      TextCellValue('Código Prenda'),
      TextCellValue('Precio Unitario'),
      TextCellValue('Cantidad'),
      TextCellValue('Subtotal (\$)'),
      TextCellValue('Estado'),
      TextCellValue('Jornada Live'),
      TextCellValue('Registrado Por'),
      TextCellValue('Rol Responsable'),
    ]);

    for (final v in data.ventas) {
      sheet.appendRow([
        TextCellValue(v.codigo),
        TextCellValue(_formatearFecha(v.fecha)),
        TextCellValue(v.clienteNombre),
        TextCellValue(v.clienteId),
        TextCellValue(v.prendaNombre),
        TextCellValue(v.prendaId),
        DoubleCellValue(v.precioUnitario),
        IntCellValue(v.cantidad),
        DoubleCellValue(v.subtotal),
        TextCellValue(v.estado),
        TextCellValue(v.jornadaId),
        TextCellValue(v.registradoPorNombre),
        TextCellValue(v.rolResponsable),
      ]);
    }
  }

  static void _llenarHojaCobros(Excel excel, ReportData data, {required bool esAdmin}) {
    final nombreHoja = esAdmin ? 'Historial Cobros' : 'Mis Cobros Registrados';
    final sheet = excel[nombreHoja];
    sheet.isRTL = false;

    sheet.appendRow([
      TextCellValue('Código Pago'),
      TextCellValue('Fecha y Hora'),
      TextCellValue('Cliente'),
      TextCellValue('Código Cliente'),
      TextCellValue('Monto (\$)'),
      TextCellValue('Forma de Pago'),
      TextCellValue('Observación / Comprobante'),
      TextCellValue('Jornada Live'),
      TextCellValue('Recibido Por'),
      TextCellValue('Rol Responsable'),
    ]);

    for (final p in data.pagos) {
      sheet.appendRow([
        TextCellValue(p.codigo),
        TextCellValue(_formatearFecha(p.fecha)),
        TextCellValue(p.clienteNombre),
        TextCellValue(p.clienteId),
        DoubleCellValue(p.monto),
        TextCellValue(p.formaPago),
        TextCellValue(p.observacion),
        TextCellValue(p.jornadaId),
        TextCellValue(p.recibidoPorNombre),
        TextCellValue(p.rolResponsable),
      ]);
    }
  }

  static void _llenarHojaClientes(Excel excel, ReportData data) {
    final sheet = excel['Cartera Clientes'];
    sheet.isRTL = false;

    sheet.appendRow([
      TextCellValue('Código Cliente'),
      TextCellValue('Nombre Completo'),
      TextCellValue('Teléfono'),
      TextCellValue('Correo'),
      TextCellValue('Dirección'),
      TextCellValue('Total Compras (\$)'),
      TextCellValue('Total Pagado (\$)'),
      TextCellValue('Saldo Pendiente (\$)'),
    ]);

    for (final c in data.clientes) {
      sheet.appendRow([
        TextCellValue(c.codigo),
        TextCellValue(c.nombre),
        TextCellValue(c.telefono),
        TextCellValue(c.correo),
        TextCellValue(c.direccion),
        DoubleCellValue(c.totalCompras),
        DoubleCellValue(c.totalPagado),
        DoubleCellValue(c.saldoPendiente),
      ]);
    }
  }

  static void _llenarHojaInventario(Excel excel, ReportData data) {
    final sheet = excel['Inventario Prendas'];
    sheet.isRTL = false;

    sheet.appendRow([
      TextCellValue('Código Prenda'),
      TextCellValue('Nombre de la Prenda'),
      TextCellValue('Precio de Venta (\$)'),
      TextCellValue('Stock Disponible'),
      TextCellValue('Estado en Catálogo'),
    ]);

    for (final p in data.prendas) {
      sheet.appendRow([
        TextCellValue(p.codigo),
        TextCellValue(p.nombre),
        DoubleCellValue(p.precio),
        IntCellValue(p.stock),
        TextCellValue(p.activa ? 'Activa' : 'Inactiva'),
      ]);
    }
  }

  static void _llenarHojaJornadas(Excel excel, ReportData data) {
    final sheet = excel['Jornadas Live'];
    sheet.isRTL = false;

    sheet.appendRow([
      TextCellValue('Código Jornada'),
      TextCellValue('Nombre de la Transmisión'),
      TextCellValue('Fecha de Inicio'),
      TextCellValue('Estado'),
      TextCellValue('Total Vendido (\$)'),
      TextCellValue('Total Cobrado (\$)'),
    ]);

    for (final j in data.jornadas) {
      sheet.appendRow([
        TextCellValue(j.codigo),
        TextCellValue(j.nombre),
        TextCellValue(_formatearFecha(j.fechaInicio)),
        TextCellValue(j.activa ? 'En Vivo (Activa)' : 'Finalizada'),
        DoubleCellValue(j.totalVendido),
        DoubleCellValue(j.totalCobrado),
      ]);
    }
  }

  static void _llenarHojaRanking(Excel excel, ReportData data) {
    final sheet = excel['Ranking Vendedores'];
    sheet.isRTL = false;

    sheet.appendRow([
      TextCellValue('Posición'),
      TextCellValue('Responsable'),
      TextCellValue('Rol Comercial'),
      TextCellValue('N° de Ventas'),
      TextCellValue('Prendas Vendidas'),
      TextCellValue('Total Vendido (\$)'),
      TextCellValue('Ticket Promedio (\$)'),
      TextCellValue('% Participación'),
      TextCellValue('Total Cobrado (\$)'),
    ]);

    final ranking = data.ranking ?? [];
    for (int i = 0; i < ranking.length; i++) {
      final r = ranking[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(r.nombre),
        TextCellValue(r.rol.toUpperCase()),
        IntCellValue(r.numeroVentas),
        IntCellValue(r.unidadesVendidas),
        DoubleCellValue(r.totalVendido),
        DoubleCellValue(r.ticketPromedio),
        TextCellValue('${r.porcentajeParticipacion.toStringAsFixed(1)} %'),
        DoubleCellValue(r.cobrosRegistrados),
      ]);
    }
  }

  // ─── GUARDADO Y COMPARTICIÓN LOCAL ───

  /// Guarda el archivo en almacenamiento local del dispositivo y abre el diálogo nativo
  /// de compartir (WhatsApp, Correo, Guardar en Archivos, Drive, etc.)
  static Future<File> guardarYCompartirLocalmente({
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$nombreArchivo');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: 'Reporte comercial de VendiX: $nombreArchivo',
        subject: 'Reporte VendiX',
      ),
    );

    return file;
  }

  static String _formatearFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
