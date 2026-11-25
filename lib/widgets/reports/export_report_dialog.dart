import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/reports/report_models.dart';
import '../../services/reports/drive_authorization_service.dart';
import '../../services/reports/excel_report_service.dart';
import '../../services/reports/google_drive_service.dart';
import '../../services/reports/report_data_service.dart';
import '../../services/reports/report_permission_service.dart';
import '../../theme/app_theme.dart';

/// Diálogo modal interactivo para exportar reportes en VendiX
class ExportReportDialog {
  ExportReportDialog._();

  /// Despliega el modal de exportación validando permisos y ofreciendo
  /// las opciones de Descarga Local Excel o Subida a Google Sheets vía Drive API v3.
  static Future<void> mostrar(
    BuildContext context, {
    String? adminIdManual,
  }) async {
    // 1. Validar permisos antes de abrir
    final permiso = await ReportPermissionService.validarPermiso(adminIdManual: adminIdManual);

    if (!context.mounted) return;

    if (!permiso.autorizado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(permiso.mensajeError),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _ExportReportSheet(permiso: permiso),
    );
  }
}

class _ExportReportSheet extends StatefulWidget {
  final ReportPermissionResult permiso;

  const _ExportReportSheet({required this.permiso});

  @override
  State<_ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<_ExportReportSheet> {
  bool _procesando = false;
  String _mensajeProgreso = '';

  String _generarNombreArchivo() {
    final now = DateTime.now();
    final fechaStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final empLimpio = widget.permiso.nombreEmprendimiento
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .trim();
    final rolStr = widget.permiso.rol == ReportRole.administrador ? 'Admin' : 'Secretario';
    return 'VendiX_${empLimpio}_${rolStr}_$fechaStr.xlsx';
  }

  // ─── ACCIÓN 1: DESCARGAR EXCEL (LOCAL) ───
  Future<void> _descargarExcelLocal() async {
    setState(() {
      _procesando = true;
      _mensajeProgreso = 'Consultando base de datos Firestore...';
    });

    try {
      final reportData = await ReportDataService.recopilarDatos(permiso: widget.permiso);

      setState(() {
        _mensajeProgreso = 'Generando archivo Excel (.XLSX)...';
      });

      final bytes = await ExcelReportService.generarArchivoExcel(reportData);
      final nombreArchivo = _generarNombreArchivo();

      setState(() {
        _mensajeProgreso = 'Preparando archivo para compartir...';
      });

      await ExcelReportService.guardarYCompartirLocalmente(
        bytes: bytes,
        nombreArchivo: nombreArchivo,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporte Excel generado con éxito: $nombreArchivo'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarError('Error al generar Excel: $e');
      }
    }
  }

  // ─── ACCIÓN 2: EXPORTAR A GOOGLE SHEETS VÍA DRIVE API V3 ───
  Future<void> _exportarAGoogleDrive() async {
    setState(() {
      _procesando = true;
      _mensajeProgreso = 'Solicitando autorización de Google Drive...';
    });

    try {
      final token = await DriveAuthorizationService.obtenerAccessToken();

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Autorización cancelada. Puedes descargar el archivo Excel directamente.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _mensajeProgreso = 'Consultando datos comerciales...';
      });

      final reportData = await ReportDataService.recopilarDatos(permiso: widget.permiso);

      setState(() {
        _mensajeProgreso = 'Generando archivo Excel...';
      });

      final Uint8List bytes = await ExcelReportService.generarArchivoExcel(reportData);
      final nombreArchivo = _generarNombreArchivo();

      setState(() {
        _mensajeProgreso = 'Subiendo a Google Drive y convirtiendo a Google Sheets...';
      });

      final resultado = await GoogleDriveService.subirYConvertirAGoogleSheets(
        accessToken: token,
        archivoBytes: bytes,
        nombreDocumento: nombreArchivo,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar hoja inferior

      // Mostrar diálogo de éxito con enlace
      _mostrarDialogoExitoDrive(resultado);
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarError('Error en Google Drive: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Error de exportación'),
          ],
        ),
        content: Text(mensaje, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoExitoDrive(GoogleDriveUploadResult resultado) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 10),
            Flexible(child: Text('¡Reporte en Google Drive!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se creó exitosamente el documento nativo en tu cuenta de Google Drive:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_rounded, color: Color(0xFF2E7D32), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      resultado.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'El archivo se convirtió a Google Sheets y permanece 100% privado en tu almacenamiento.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              GoogleDriveService.abrirDocumento(resultado.webViewLink);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir Hoja de Cálculo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = widget.permiso.rol == ReportRole.administrador;
    final rolTexto = esAdmin ? 'Administrador' : 'Secretario';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tirador superior
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título y rol
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded, color: AppTheme.violet, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exportar reportes comerciales',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.permiso.nombreEmprendimiento} • Rol: $rolTexto',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_procesando) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppTheme.violet),
                  const SizedBox(height: 16),
                  Text(
                    _mensajeProgreso,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.dark, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Selecciona el formato y destino del reporte:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Opción A: Descargar Excel
            _buildOpcionCard(
              icono: Icons.download_rounded,
              colorIcono: const Color(0xFF1E88E5),
              colorFondo: const Color(0xFFE3F2FD),
              titulo: 'Descargar archivo Excel (.XLSX)',
              subtitulo: 'Genera el archivo localmente para compartirlo por WhatsApp, correo o guardarlo en tu teléfono. No requiere cuenta Google.',
              onTap: _descargarExcelLocal,
            ),
            const SizedBox(height: 10),

            // Opción B: Exportar a Google Sheets
            _buildOpcionCard(
              icono: Icons.cloud_upload_rounded,
              colorIcono: const Color(0xFF2E7D32),
              colorFondo: const Color(0xFFE8F5E9),
              titulo: 'Exportar a Google Sheets (Drive)',
              subtitulo: 'Sube una copia a tu Google Drive personal mediante Google Drive API v3 y conviértela en una hoja de cálculo nativa.',
              onTap: _exportarAGoogleDrive,
            ),
            const SizedBox(height: 14),

            Text(
              esAdmin
                  ? '• El reporte incluirá ventas, cobros, clientes, inventario y ranking comercial.'
                  : '• El reporte incluirá ventas, catálogo de prendas y tus cobros registrados.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpcionCard({
    required IconData icono,
    required Color colorIcono,
    required Color colorFondo,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE6F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorFondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono, color: colorIcono, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.dark),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitulo,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
