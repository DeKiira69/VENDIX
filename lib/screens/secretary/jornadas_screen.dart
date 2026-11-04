import 'package:flutter/material.dart';

import '../../data/datos_prueba.dart';
import '../../theme/app_theme.dart';

class JornadasScreen extends StatefulWidget {
  const JornadasScreen({super.key});

  @override
  State<JornadasScreen> createState() => _JornadasScreenState();
}

class _JornadasScreenState extends State<JornadasScreen> {
  // ──────────────── Crear nueva jornada ────────────────

  Future<void> _crearJornada() async {
    final nombreController = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Nuevo Live',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Cómo quieres llamar a esta sesión de ventas?',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
              onPressed: () {
                final texto = nombreController.text.trim();
                if (texto.isEmpty) return;
                Navigator.pop(dialogContext, texto);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    nombreController.dispose();

    if (nombre == null || !mounted) return;

    setState(() {
      jornadasDemo.insert(
        0,
        JornadaDemo(nombre: nombre, fecha: DateTime.now()),
      );
    });

    _mostrarMensaje('Jornada "$nombre" creada. ¡Iníciala cuando estés lista!');
  }

  // ──────────────── Iniciar jornada ────────────────

  void _iniciarJornada(JornadaDemo jornada) {
    // Verificar que no haya otra jornada activa
    final activa = jornadasDemo.where((j) => j.estaActiva).toList();

    if (activa.isNotEmpty) {
      _mostrarMensaje(
        'Ya hay un live en curso: "${activa.first.nombre}". Ciérralo primero.',
      );
      return;
    }

    setState(() {
      jornada.horaInicio = DateTime.now();
      jornada.estado = 'activa';
    });

    _mostrarMensaje('🔴 ¡Live "${jornada.nombre}" iniciado!');
  }

  // ──────────────── Cerrar jornada ────────────────

  Future<void> _cerrarJornada(JornadaDemo jornada) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cerrar Live',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Segura que quieres cerrar "${jornada.nombre}"?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No podrás registrar más ventas en esta jornada después de cerrarla.',
                        style: TextStyle(fontSize: 11, color: AppTheme.dark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.orange),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cerrar Live'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      jornada.horaFin = DateTime.now();
      jornada.estado = 'cerrada';
    });

    _mostrarMensaje('Live "${jornada.nombre}" cerrado.');
  }

  // ──────────────── Eliminar jornada pendiente ────────────────

  Future<void> _eliminarJornada(JornadaDemo jornada) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Eliminar jornada',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Text(
            '¿Eliminar "${jornada.nombre}"? Esta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      jornadasDemo.remove(jornada);
    });

    _mostrarMensaje('Jornada eliminada.');
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  // ──────────────── Formatear fecha ────────────────

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final diaFecha = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = hoy.difference(diaFecha).inDays;

    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';
    if (diferencia < 7) return 'Hace $diferencia días';

    final meses = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${fecha.day} ${meses[fecha.month]} ${fecha.year}';
  }

  String _formatearHora(DateTime hora) {
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ──────────────── BUILD ────────────────

  @override
  Widget build(BuildContext context) {
    final activas = jornadasDemo.where((j) => j.estaActiva).toList();
    final pendientes = jornadasDemo.where((j) => j.estaPendiente).toList();
    final cerradas = jornadasDemo.where((j) => j.estaCerrada).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GESTIÓN',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: AppTheme.violet,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Jornadas de venta',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 21,
                color: AppTheme.dark,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearJornada,
        backgroundColor: AppTheme.violet,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo Live',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          // ── Jornada activa (si existe) ──
          if (activas.isNotEmpty) ...[
            const _SeccionTitulo(titulo: '🔴 EN VIVO AHORA'),
            const SizedBox(height: 8),
            ...activas.map(
              (jornada) => _TarjetaJornadaActiva(
                jornada: jornada,
                onCerrar: () => _cerrarJornada(jornada),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Jornadas pendientes ──
          if (pendientes.isNotEmpty) ...[
            const _SeccionTitulo(titulo: 'LISTAS PARA INICIAR'),
            const SizedBox(height: 8),
            ...pendientes.map(
              (jornada) => _TarjetaJornadaPendiente(
                jornada: jornada,
                formatearFecha: _formatearFecha,
                onIniciar: () => _iniciarJornada(jornada),
                onEliminar: () => _eliminarJornada(jornada),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Mensaje si no hay nada ──
          if (activas.isEmpty && pendientes.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.live_tv_outlined,
                    size: 60,
                    color: AppTheme.muted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay lives programados',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca "Nuevo Live" para crear uno',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],

          // ── Historial de jornadas cerradas ──
          if (cerradas.isNotEmpty) ...[
            const _SeccionTitulo(titulo: 'HISTORIAL'),
            const SizedBox(height: 8),
            ...cerradas.map(
              (jornada) => _TarjetaJornadaCerrada(
                jornada: jornada,
                formatearFecha: _formatearFecha,
                formatearHora: _formatearHora,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  WIDGETS PRIVADOS
// ═══════════════════════════════════════════════════════

class _SeccionTitulo extends StatelessWidget {
  final String titulo;

  const _SeccionTitulo({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.1,
        color: AppTheme.muted,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// ── Tarjeta de jornada ACTIVA (estilo destacado) ──

class _TarjetaJornadaActiva extends StatelessWidget {
  final JornadaDemo jornada;
  final VoidCallback onCerrar;

  const _TarjetaJornadaActiva({
    required this.jornada,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF50308F), Color(0xFF7850B9), Color(0xFFA568B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B9A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'EN VIVO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  jornada.duracionTexto,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            jornada.nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (jornada.horaInicio != null) ...[
            const SizedBox(height: 6),
            Text(
              'Iniciado a las ${jornada.horaInicio!.hour.toString().padLeft(2, '0')}:${jornada.horaInicio!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCerrar,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text(
                'Cerrar Live',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de jornada PENDIENTE ──

class _TarjetaJornadaPendiente extends StatelessWidget {
  final JornadaDemo jornada;
  final String Function(DateTime) formatearFecha;
  final VoidCallback onIniciar;
  final VoidCallback onEliminar;

  const _TarjetaJornadaPendiente({
    required this.jornada,
    required this.formatearFecha,
    required this.onIniciar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E9FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.live_tv_outlined,
              color: AppTheme.violet,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jornada.nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Creada ${formatearFecha(jornada.fecha)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEliminar,
            icon: const Icon(Icons.delete_outline, size: 19),
            color: AppTheme.muted,
            tooltip: 'Eliminar',
          ),
          const SizedBox(width: 2),
          FilledButton(
            onPressed: onIniciar,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 16),
                SizedBox(width: 4),
                Text(
                  'Iniciar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de jornada CERRADA ──

class _TarjetaJornadaCerrada extends StatelessWidget {
  final JornadaDemo jornada;
  final String Function(DateTime) formatearFecha;
  final String Function(DateTime) formatearHora;

  const _TarjetaJornadaCerrada({
    required this.jornada,
    required this.formatearFecha,
    required this.formatearHora,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppTheme.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jornada.nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatearFecha(jornada.fecha)}'
                  '${jornada.horaInicio != null ? ' · ${formatearHora(jornada.horaInicio!)}' : ''}'
                  '${jornada.horaFin != null ? ' – ${formatearHora(jornada.horaFin!)}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              jornada.duracionTexto,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.muted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
