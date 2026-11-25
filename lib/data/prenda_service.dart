import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prenda_model.dart';
import '../services/client_service.dart';
import '../services/id_service.dart';

class PrendaService {
  final CollectionReference _prendasRef =
      FirebaseFirestore.instance.collection('prendas');

  // Stream en tiempo real de todas las prendas filtrables por negocio
  Stream<List<PrendaModel>> getPrendasStream({String? adminId}) {
    Query query = _prendasRef;
    if (adminId != null && adminId.isNotEmpty) {
      query = query.where('adminId', isEqualTo: adminId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PrendaModel.fromFirestore(doc))
          .toList();
    });
  }

  // Agregar nueva prenda a Firestore con ID consecutivo legible: PrendNNN_NombrePrenda
  Future<String> agregarPrenda({
    required String nombre,
    required double precio,
    int stock = 0,
    String? adminId,
  }) async {
    final idPrenda = await IdService.generarIdPrenda(nombre);

    String adminIdFinal = adminId ?? '';
    if (adminIdFinal.isEmpty) {
      adminIdFinal = ClientService.activeSecretaryAdminId ?? '';
    }
    if (adminIdFinal.isEmpty) {
      adminIdFinal = FirebaseAuth.instance.currentUser?.uid ?? '';
    }

    await _prendasRef.doc(idPrenda).set({
      'id': idPrenda,
      'codigo': idPrenda,
      'adminId': adminIdFinal,
      'nombre': nombre.trim(),
      'precio': precio,
      'activa': true,
      'stock': stock,
      'fecha_creacion': FieldValue.serverTimestamp(),
    });

    return idPrenda;
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
