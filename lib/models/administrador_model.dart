class AdministradorModel {
  final String id;
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final bool estado;

  AdministradorModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    this.estado = true,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  String get iniciales {
    final n = nombre.isNotEmpty ? nombre[0].toUpperCase() : '';
    final a = apellido.isNotEmpty ? apellido[0].toUpperCase() : '';
    return '$n$a'.isNotEmpty ? '$n$a' : 'AD';
  }

  factory AdministradorModel.fromMap(String id, Map<String, dynamic> data) {
    return AdministradorModel(
      id: id,
      nombre: data['nombre'] ?? '',
      apellido: data['apellido'] ?? '',
      correo: data['correo'] ?? '',
      telefono: data['telefono'] ?? '',
      estado: data['estado'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
      'telefono': telefono,
      'estado': estado,
      'rol': 'admin',
    };
  }
}
