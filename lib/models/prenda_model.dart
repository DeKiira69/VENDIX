import 'package:cloud_firestore/cloud_firestore.dart';

class PrendaModel {
  final String id;
  final String nombre;
  final double precio;
  final bool activa;
  final int stock;
  final DateTime? fechaCreacion;

  PrendaModel({
    required this.id,
    required this.nombre,
    required this.precio,
    this.activa = true,
    this.stock = 0,
    this.fechaCreacion,
  });

  factory PrendaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PrendaModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      precio: (data['precio'] is num) ? (data['precio'] as num).toDouble() : 0.0,
      activa: data['activa'] ?? true,
      stock: (data['stock'] is num) ? (data['stock'] as num).toInt() : 0,
      fechaCreacion: (data['fecha_creacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'precio': precio,
      'activa': activa,
      'stock': stock,
      'fecha_creacion': fechaCreacion != null
          ? Timestamp.fromDate(fechaCreacion!)
          : FieldValue.serverTimestamp(),
    };
  }
}
