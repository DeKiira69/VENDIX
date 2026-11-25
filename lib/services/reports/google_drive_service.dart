import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Resultado devuelto tras la subida y conversión exitosa en Google Drive API v3
class GoogleDriveUploadResult {
  final String id;
  final String name;
  final String webViewLink;

  GoogleDriveUploadResult({
    required this.id,
    required this.name,
    required this.webViewLink,
  });
}

/// Servicio encargado de la comunicación HTTP REST con Google Drive API v3.
///
/// Implementa la subida en modalidad multipart/related que simultáneamente
/// envía el archivo binario XLSX y solicita a Google Drive su conversión
/// automática a una hoja de cálculo nativa de Google Sheets (`application/vnd.google-apps.spreadsheet`).
class GoogleDriveService {
  GoogleDriveService._();

  static const String _uploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,webViewLink';

  /// Sube los bytes del archivo XLSX y solicita a Google Drive su conversión a Google Sheets
  static Future<GoogleDriveUploadResult> subirYConvertirAGoogleSheets({
    required String accessToken,
    required Uint8List archivoBytes,
    required String nombreDocumento,
  }) async {
    final boundary = '----VendiXBoundary${DateTime.now().millisecondsSinceEpoch}';
    final nombreLimpio = nombreDocumento.replaceAll('.xlsx', '');

    // 1. Metadata del archivo (indicando la conversión a Google Sheets)
    final metadata = {
      'name': nombreLimpio,
      'mimeType': 'application/vnd.google-apps.spreadsheet',
    };

    final metadataJson = jsonEncode(metadata);

    // 2. Construcción manual del cuerpo multipart/related
    final delimiter = '--$boundary\r\n';
    final closeDelimiter = '\r\n--$boundary--';

    final part1Headers =
        'Content-Type: application/json; charset=UTF-8\r\n\r\n$metadataJson\r\n';
    final part2Headers =
        'Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n';

    final part1Bytes = utf8.encode('$delimiter$part1Headers');
    final part2HeaderBytes = utf8.encode('$delimiter$part2Headers');
    final closeBytes = utf8.encode(closeDelimiter);

    // Concatenación de bytes en memoria
    final bodyBytes = <int>[
      ...part1Bytes,
      ...part2HeaderBytes,
      ...archivoBytes,
      ...closeBytes,
    ];

    // 3. Envío de petición HTTP POST a Google Drive API v3
    final response = await http.post(
      Uri.parse(_uploadEndpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
        'Content-Length': bodyBytes.length.toString(),
      },
      body: bodyBytes,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final id = jsonResponse['id']?.toString() ?? '';
      final name = jsonResponse['name']?.toString() ?? nombreLimpio;
      final webViewLink = jsonResponse['webViewLink']?.toString() ??
          'https://docs.google.com/spreadsheets/d/$id/edit';

      return GoogleDriveUploadResult(
        id: id,
        name: name,
        webViewLink: webViewLink,
      );
    } else if (response.statusCode == 401) {
      throw Exception(
        'La autorización de Google ha expirado o no es válida. Por favor, reintenta la autorización.',
      );
    } else if (response.statusCode == 403) {
      throw Exception(
        'Permiso denegado en Google Drive. Verifica que la API de Google Drive esté habilitada en Google Cloud Console y que tu cuenta tenga permisos.',
      );
    } else {
      throw Exception(
        'Error al subir a Google Drive (HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Abre el enlace del documento generado en el navegador o en la app de Google Sheets
  static Future<bool> abrirDocumento(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
