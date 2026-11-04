import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendix/services/cloudinary_service.dart';

import '../theme/app_theme.dart';

class PerfilFotoService {
  PerfilFotoService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final ImagePicker _picker = ImagePicker();

  /// ColecciÃ³n en Firestore dedicada exclusivamente a almacenar fotos de perfil.
  static const String coleccion = 'fotos_perfil';

  /// Obtiene en tiempo real la foto de perfil (Base64 o URL) de un usuario.
  static Stream<String?> fotoStream(String? usuarioId) {
    if (usuarioId == null || usuarioId.isEmpty) {
      return Stream.value(null);
    }

    return _db.collection(coleccion).doc(usuarioId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      final url = data['fotoUrl']?.toString();
      if (url != null && url.isNotEmpty) return url;

      final base64 = data['fotoBase64']?.toString();
      if (base64 != null && base64.isNotEmpty) return base64;

      return null;
    });

  }

  /// Guarda la foto de perfil en la colecciÃ³n `fotos_perfil` y sincroniza las demÃ¡s tablas.
  static Future<void> guardarFoto({
    required String usuarioId,
    required String fotoUrl,
    String? rol,
  }) async {
    final batch = _db.batch();

    // 1. Guardar en la colección exclusiva 'fotos_perfil'
    final docFoto = _db.collection(coleccion).doc(usuarioId);
    batch.set(docFoto, {
      'usuarioId': usuarioId,
      'fotoUrl': fotoUrl,
      'rol': rol ?? 'usuario',
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Sincronizar en 'usuarios'
    final docUsuario = _db.collection('usuarios').doc(usuarioId);
    batch.set(docUsuario, {
      'fotoUrl': fotoUrl,
      'fotoActualizadaEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Sincronizar ÚNICAMENTE en la colección correspondiente al rol
    final rolNormalizado = rol?.trim().toLowerCase();
    if (rolNormalizado == 'cliente') {
      final docCliente = _db.collection('clientes').doc(usuarioId);
      batch.set(docCliente, {
        'fotoUrl': fotoUrl,
      }, SetOptions(merge: true));
    } else if (rolNormalizado == 'administrador' || rolNormalizado == 'admin') {
      final docAdmin = _db.collection('Administradores').doc(usuarioId);
      batch.set(docAdmin, {
        'fotoUrl': fotoUrl,
      }, SetOptions(merge: true));
    } else if (rolNormalizado == 'secretaria' || rolNormalizado == 'secretario') {
      final docSec = _db.collection('secretarios').doc(usuarioId);
      batch.set(docSec, {
        'fotoUrl': fotoUrl,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Elimina la foto de perfil del usuario.
  static Future<void> eliminarFoto(String usuarioId) async {
    final batch = _db.batch();

    final docFoto = _db.collection(coleccion).doc(usuarioId);
    batch.delete(docFoto);

    final docUsuario = _db.collection('usuarios').doc(usuarioId);
    batch.set(docUsuario, {'fotoUrl': null}, SetOptions(merge: true));

    final docCliente = _db.collection('clientes').doc(usuarioId);
    batch.set(docCliente, {'fotoUrl': null}, SetOptions(merge: true));

    final docAdmin = _db.collection('Administradores').doc(usuarioId);
    batch.set(docAdmin, {'fotoUrl': null}, SetOptions(merge: true));

    await batch.commit();
  }

  /// Muestra el menÃº inferior estilo WhatsApp para cambiar o eliminar la foto.
  static Future<void> mostrarOpcionesFotoWhatsApp({
    required BuildContext context,
    required String usuarioId,
    String? fotoActual,
    String? rol,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Foto del perfil',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dark,
                    ),
                  ),
                  if (fotoActual != null && fotoActual.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar foto',
                      onPressed: () async {
                        Navigator.pop(bottomSheetContext);
                        await eliminarFoto(usuarioId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Foto de perfil eliminada'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Opciones estilo WhatsApp (CÃ¡mara, GalerÃ­a, Enlace)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _opcionBoton(
                    icono: Icons.camera_alt,
                    color: const Color(0xFF15966B),
                    etiqueta: 'Camara',
                    onTap: () async {
                      Navigator.pop(bottomSheetContext);
                      await _seleccionarYGuardar(
                        context: context,
                        source: ImageSource.camera,
                        usuarioId: usuarioId,
                        rol: rol,
                      );
                    },
                  ),
                  _opcionBoton(
                    icono: Icons.photo_library,
                    color: AppTheme.violet,
                    etiqueta: 'Galeria',
                    onTap: () async {
                      Navigator.pop(bottomSheetContext);
                      await _seleccionarYGuardar(
                        context: context,
                        source: ImageSource.gallery,
                        usuarioId: usuarioId,
                        rol: rol,
                      );
                    },
                  ),
                  _opcionBoton(
                    icono: Icons.link,
                    color: AppTheme.orange,
                    etiqueta: 'Enlace web',
                    onTap: () async {
                      Navigator.pop(bottomSheetContext);
                      await _pedirEnlaceWeb(
                        context: context,
                        usuarioId: usuarioId,
                        rol: rol,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static Widget _opcionBoton({
    required IconData icono,
    required Color color,
    required String etiqueta,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _seleccionarYGuardar({
    required BuildContext context,
    required ImageSource source,
    required String usuarioId,
    String? rol,
  }) async {
    try {
      final XFile? archivo = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (archivo == null) return;

      ///se encarga de subir una imagen de perfil del usuario a Cloudinary y guardar la URL de esa imagen en tu base de datos.
      final bytes = await archivo.readAsBytes();
      final url = await CloudinaryService.subirImagen(
        bytes,
        archivoNombre:
            'perfil_${usuarioId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await guardarFoto(usuarioId: usuarioId, fotoUrl: url, rol: rol);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada correctamente'),
            backgroundColor: Color(0xFF15966B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar foto: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> _pedirEnlaceWeb({
    required BuildContext context,
    required String usuarioId,
    String? rol,
  }) async {
    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enlace de imagen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://ejemplo.com/foto.jpg',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      await guardarFoto(usuarioId: usuarioId, fotoUrl: url, rol: rol);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada'),
            backgroundColor: Color(0xFF15966B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Construye el Avatar circular que muestra la foto de perfil en Base64 o URL,
  /// o las iniciales si no tiene foto, junto a la insignia de la cÃ¡mara estilo WhatsApp.
  static Widget avatarConInsignia({
    required String? fotoData,
    required String iniciales,
    required double radio,
    required VoidCallback onTap,
  }) {
    ImageProvider? imageProvider;
    if (fotoData != null && fotoData.isNotEmpty) {
      if (fotoData.startsWith('http://') || fotoData.startsWith('https://')) {
        imageProvider = NetworkImage(fotoData);
      } else {
        try {
          final cleanBase64 = fotoData.contains(',')
              ? fotoData.split(',').last
              : fotoData;
          imageProvider = MemoryImage(base64Decode(cleanBase64));
        } catch (_) {}
      }
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radio + 4),
            child: CircleAvatar(
              radius: radio,
              backgroundColor: const Color(0xFFD9B9E8),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      iniciales.isEmpty ? '?' : iniciales,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: radio * 0.6,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.violet,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}