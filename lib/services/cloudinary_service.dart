import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'kjpffs0b';
  static const String uploadPreset = 'vendix_mobile';

  static Future<String> subirImagen(
    Uint8List bytes, {
    required String archivoNombre,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = 'vendix/perfiles'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: archivoNombre),
      );

    final response = await request.send();

    final body = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(body);
      final url = json['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary no devolvió una URL válida.');
      }
      return url;
    }

    throw Exception(
      'Error al subir a Cloudinary: ${response.statusCode} - $body',
    );
  }
}
