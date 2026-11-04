import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prenda_model.dart';

class PrendaService {
  final CollectionReference _prendasRef =
      FirebaseFirestore.instance.collection('prendas');

  // Stream en tiempo real de todas las prendas ordenadas por nombre
  Stream<List<PrendaModel>> getPrendasStream() {
    return _prendasRef.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PrendaModel.fromFirestore(doc))
          .toList();
    });
  }

  // Agregar nueva prenda a Firestore
  Future<void> agregarPrenda({
    required String nombre,
    required double precio,
    int stock = 0,
  }) async {
    await _prendasRef.add({
      'nombre': nombre.trim(),
      'precio': precio,
      'activa': true,
      'stock': stock,
      'fecha_creacion': FieldValue.serverTimestamp(),
    });
  }

  // Editar prenda existente
  Future<void> actualizarPrenda({
    required String id,
    required String nombre,
    required double precio,
    bool? activa,
    int? stock,
  }) async {
    final Map<String, dynamic> datos = {
      'nombre': nombre.trim(),
      'precio': precio,
    };
    if (activa != null) datos['activa'] = activa;
    if (stock != null) datos['stock'] = stock;

    await _prendasRef.doc(id).update(datos);
  }

  // Cambiar estado activa/inactiva
  Future<void> toggleActiva(String id, bool valorActual) async {
    await _prendasRef.doc(id).update({'activa': !valorActual});
  }

  // Eliminar prenda
  Future<void> eliminarPrenda(String id) async {
    await _prendasRef.doc(id).delete();
  }
}
