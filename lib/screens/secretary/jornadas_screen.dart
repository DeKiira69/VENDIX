import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class JornadasScreen extends StatefulWidget {
  const JornadasScreen({super.key});

  @override
  State<JornadasScreen> createState() => _JornadasScreenState();
}

class _JornadasScreenState extends State<JornadasScreen> {
  final _db = FirebaseFirestore.instance;

  Future<void> _crearJornada() async {
    final nombreController = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nuevo Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Cómo quieres llamar a esta sesión de ventas?',
                style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: nombreController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ej: Live Viernes de Ofertas',
                prefixIcon: Icon(Icons.live_tv_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
            onPressed: () {
              final texto = nombreController.text.trim();
              if (texto.isEmpty) return;
              Navigator.pop(ctx, texto);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    nombreController.dispose();
    if (nombre == null || !mounted) return;

    await _db.collection('jornadas').add({
      'nombre': nombre,
      'fecha': FieldValue.serverTimestamp(),
      'estado': 'pendiente',
      'horaInicio': null,
      'horaFin': null,
    });
    _mostrarMensaje('Jornada "$nombre" creada. ¡Iníciala cuando estés lista!');
  }

  Future<void> _iniciarJornada(String docId, String nombre) async {
    // Verificar que no haya otra activa
    final activas = await _db.collection('jornadas').where('estado', isEqualTo: 'activa').get();
    if (activas.docs.isNotEmpty) {
      _mostrarMensaje('Ya hay un live en curso: "${activas.docs.first['nombre']}". Ciérralo primero.');
      return;
    }
    await _db.collection('jornadas').doc(docId).update({
      'estado': 'activa',
      'horaInicio': FieldValue.serverTimestamp(),
    });
    _mostrarMensaje('🔴 ¡Live "$nombre" iniciado!');
  }

  Future<void> _cerrarJornada(String docId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Segura que quieres cerrar "$nombre"?', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('No podrás registrar más ventas en esta jornada después de cerrarla.',
                      style: TextStyle(fontSize: 11, color: AppTheme.dark))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Live'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _db.collection('jornadas').doc(docId).update({
      'estado': 'cerrada',
      'horaFin': FieldValue.serverTimestamp(),
    });
    _mostrarMensaje('Live "$nombre" cerrado.');
  }

  Future<void> _eliminarJornada(String docId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar jornada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _db.collection('jornadas').doc(docId).delete();
    _mostrarMensaje('Jornada eliminada.');
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return '';
    final fecha = ts.toDate();
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final diaFecha = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = hoy.difference(diaFecha).inDays;
    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';
    if (diferencia < 7) return 'Hace $diferencia días';
    const meses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month]} ${fecha.year}';
  }

  String _formatearHora(Timestamp? ts) {
    if (ts == null) return '';
    final hora = ts.toDate();
    return '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
  }

  String _duracion(Timestamp? inicio, Timestamp? fin) {
    if (inicio == null) return 'Sin iniciar';
    final desde = inicio.toDate();
    final hasta = fin?.toDate() ?? DateTime.now();
    final diff = hasta.difference(desde);
    return '${diff.inHours}h ${diff.inMinutes % 60}m${fin == null ? ' en curso' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E9FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: AppTheme.violet,
                      ),
                    ),
                  ),
                ),
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GESTIÓN', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppTheme.violet, fontWeight: FontWeight.bold)),
            SizedBox(height: 3),
            Text('Jornadas de venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21, color: AppTheme.dark)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearJornada,
        backgroundColor: AppTheme.violet,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Live', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('jornadas').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final activas = docs.where((d) => d['estado'] == 'activa').toList();
          final pendientes = docs.where((d) => d['estado'] == 'pendiente').toList();
          final cerradas = docs.where((d) => d['estado'] == 'cerrada').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              if (activas.isNotEmpty) ...[
                const _SeccionTitulo(titulo: '🔴 EN VIVO AHORA'),
                const SizedBox(height: 8),
                ...activas.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return _TarjetaActiva(
                    nombre: d['nombre'] ?? '',
                    duracion: _duracion(d['horaInicio'], null),
                    horaInicio: _formatearHora(d['horaInicio']),
                    onCerrar: () => _cerrarJornada(doc.id, d['nombre'] ?? ''),
                  );
                }),
                const SizedBox(height: 20),
              ],
              if (pendientes.isNotEmpty) ...[
                const _SeccionTitulo(titulo: 'LISTAS PARA INICIAR'),
                const SizedBox(height: 8),
                ...pendientes.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return _TarjetaPendiente(
                    nombre: d['nombre'] ?? '',
                    fechaTexto: _formatearFecha(d['fecha']),
                    onIniciar: () => _iniciarJornada(doc.id, d['nombre'] ?? ''),
                    onEliminar: () => _eliminarJornada(doc.id, d['nombre'] ?? ''),
                  );
                }),
                const SizedBox(height: 20),
              ],
              if (activas.isEmpty && pendientes.isEmpty) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.live_tv_outlined, size: 60, color: AppTheme.muted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text('No hay lives programados', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.muted)),
                      const SizedBox(height: 4),
                      const Text('Toca "Nuevo Live" para crear uno', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
              if (cerradas.isNotEmpty) ...[
                const _SeccionTitulo(titulo: 'HISTORIAL'),
                const SizedBox(height: 8),
                ...cerradas.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return _TarjetaCerrada(
                    nombre: d['nombre'] ?? '',
                    fechaTexto: _formatearFecha(d['fecha']),
                    horaInicio: _formatearHora(d['horaInicio']),
                    horaFin: _formatearHora(d['horaFin']),
                    duracion: _duracion(d['horaInicio'], d['horaFin']),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  const _SeccionTitulo({required this.titulo});
  @override
  Widget build(BuildContext context) {
    return Text(titulo, style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: AppTheme.muted, fontWeight: FontWeight.bold));
  }
}

class _TarjetaActiva extends StatelessWidget {
  final String nombre, duracion, horaInicio;
  final VoidCallback onCerrar;
  const _TarjetaActiva({required this.nombre, required this.duracion, required this.horaInicio, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF50308F), Color(0xFF7850B9), Color(0xFFA568B5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFFF6B9A), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('EN VIVO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(duracion, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),
          Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
          if (horaInicio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Iniciado a las $horaInicio', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCerrar,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Cerrar Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPendiente extends StatelessWidget {
  final String nombre, fechaTexto;
  final VoidCallback onIniciar, onEliminar;
  const _TarjetaPendiente({required this.nombre, required this.fechaTexto, required this.onIniciar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFFF0E9FC), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.live_tv_outlined, color: AppTheme.violet, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.dark)),
            const SizedBox(height: 3),
            Text('Creada $fechaTexto', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        )),
        IconButton(onPressed: onEliminar, icon: const Icon(Icons.delete_outline, size: 19), color: AppTheme.muted),
        const SizedBox(width: 2),
        FilledButton(
          onPressed: onIniciar,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.green, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_arrow, size: 16), SizedBox(width: 4),
            Text('Iniciar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _TarjetaCerrada extends StatelessWidget {
  final String nombre, fechaTexto, horaInicio, horaFin, duracion;
  const _TarjetaCerrada({required this.nombre, required this.fechaTexto, required this.horaInicio, required this.horaFin, required this.duracion});

  @override
  Widget build(BuildContext context) {
    final horaTexto = [if (horaInicio.isNotEmpty) horaInicio, if (horaFin.isNotEmpty) horaFin].join(' – ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFFF5F3F7), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.check_circle_outline, color: AppTheme.muted, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.dark)),
            const SizedBox(height: 3),
            Text('$fechaTexto${horaTexto.isNotEmpty ? ' · $horaTexto' : ''}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF5F3F7), borderRadius: BorderRadius.circular(8)),
          child: Text(duracion, style: const TextStyle(fontSize: 10, color: AppTheme.muted, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
