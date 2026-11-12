import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SolicitudEmpleoScreen extends StatefulWidget {
  const SolicitudEmpleoScreen({super.key});

  @override
  State<SolicitudEmpleoScreen> createState() => _SolicitudEmpleoScreenState();
}

class _SolicitudEmpleoScreenState extends State<SolicitudEmpleoScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud({
    required BuildContext context,
    required String adminId,
    required String adminNombre,
    required String nombreEmprendimiento,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    final db = FirebaseFirestore.instance;

    // Obtener datos del cliente actual
    final userDoc = await db.collection('usuarios').doc(usuario.uid).get();
    final dataUser = userDoc.data() ?? {};
    final nombreCliente = dataUser['nombre']?.toString() ?? usuario.displayName ?? 'Cliente';
    final apellidoCliente = dataUser['apellido']?.toString() ?? '';
    final telefonoCliente = dataUser['telefono']?.toString() ?? '';

    // Guardar solicitud en la colección de secretarios/solicitudes
    // Documento ID compuesto para evitar duplicados por emprendedor
    final solicitudId = '${usuario.uid}_$adminId';

    await db.collection('secretarios').doc(solicitudId).set({
      'solicitudId': solicitudId,
      'clienteId': usuario.uid,
      'uid': usuario.uid,
      'nombre': '$nombreCliente $apellidoCliente'.trim(),
      'correo': usuario.email ?? '',
      'telefono': telefonoCliente,
      'adminId': adminId,
      'adminNombre': adminNombre,
      'nombreEmprendimiento': nombreEmprendimiento,
      'aprobado': false,
      'estado': false,
      'estado_solicitud': 'pendiente',
      'fecha_solicitud': FieldValue.serverTimestamp(),
      'fecha_registro': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // También registrar en subcolección del usuario para seguimiento
    await db
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('mis_empleos')
        .doc(adminId)
        .set({
      'adminId': adminId,
      'adminNombre': adminNombre,
      'nombreEmprendimiento': nombreEmprendimiento,
      'estado': 'pendiente',
      'aprobado': false,
      'fecha_solicitud': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Solicitud enviada a $nombreEmprendimiento con éxito!'),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final usuarioId = usuario?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FB),
      appBar: AppBar(
        title: const Text(
          'Solicitar Empleo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF221B2D),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Cabecera explicativa
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elige un emprendedor para ser su secretario(a)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Puedes enviar solicitudes a varios emprendimientos y gestionar sus lives cuando te aprueben.',
                  style: TextStyle(color: Color(0xFF81798D), fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _busquedaCtrl,
                  onChanged: (val) => setState(() => _filtro = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por tienda o emprendedor...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.violet),
                    filled: true,
                    fillColor: const Color(0xFFF2EDF8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Emprendedores disponibles
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('Administradores').snapshots(),
              builder: (context, snapAdmins) {
                if (snapAdmins.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapAdmins.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No hay emprendedores registrados en este momento.'),
                  );
                }

                // Obtener las solicitudes que ya envió este usuario
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('secretarios')
                      .where('clienteId', isEqualTo: usuarioId)
                      .snapshots(),
                  builder: (context, snapMisSolicitudes) {
                    final misDocs = snapMisSolicitudes.data?.docs ?? [];
                    final mapaEstados = <String, String>{}; // adminId -> estado

                    for (final doc in misDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final aId = data['adminId']?.toString() ?? '';
                      final est = data['estado_solicitud']?.toString() ??
                          (data['aprobado'] == true ? 'aprobado' : 'pendiente');
                      mapaEstados[aId] = est;
                    }

                    final filtrados = docs.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final emp = (d['nombreEmprendimiento'] ?? '').toString().toLowerCase();
                      final nom = '${d['nombre'] ?? ""} ${d['apellido'] ?? ""}'.toLowerCase();
                      return emp.contains(_filtro) || nom.contains(_filtro);
                    }).toList();

                    if (filtrados.isEmpty) {
                      return const Center(child: Text('No se encontraron resultados.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final doc = filtrados[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final adminId = doc.id;
                        final nombreAdmin = '${d['nombre'] ?? ""} ${d['apellido'] ?? ""}'.trim();
                        final emp = (d['nombreEmprendimiento'] ?? '').toString().trim();
                        final nombreMostrar = emp.isNotEmpty ? emp : (nombreAdmin.isNotEmpty ? nombreAdmin : 'Emprendimiento');
                        final estadoActual = mapaEstados[adminId];

                        return Container(
                          padding: const EdgeInsets.all(14),
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
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFF0E8FC),
                                child: const Icon(Icons.storefront_outlined, color: AppTheme.violet),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombreMostrar,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (emp.isNotEmpty && nombreAdmin.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Titular: $nombreAdmin',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF81798D)),
                                      ),
                                    ],
                                    if ((d['correo'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        d['correo'].toString(),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF81798D)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Estado / Botón
                              if (estadoActual == 'aprobado')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Aprobado ✓',
                                    style: TextStyle(
                                      color: Color(0xFF27AE60),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              else if (estadoActual == 'pendiente')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7E6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Enviada',
                                    style: TextStyle(
                                      color: Color(0xFFE67E22),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _enviarSolicitud(
                                    context: context,
                                    adminId: adminId,
                                    adminNombre: nombreAdmin,
                                    nombreEmprendimiento: nombreMostrar,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.violet,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.send_outlined, size: 14),
                                  label: const Text('Postular', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
