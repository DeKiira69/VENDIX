import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  final VoidCallback? onVolver;

  const StatisticsScreen({super.key, this.onVolver});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Modo de filtro: 'todo', 'dia', 'mes'
  String _modoFiltro = 'todo';
  DateTime? _fechaSeleccionada;
  bool _vistaLimpia = false; // Si true, no se muestran los datos en pantalla

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: (widget.onVolver != null || Navigator.canPop(context))
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: InkWell(
                    onTap: () {
                      if (widget.onVolver != null) {
                        widget.onVolver!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.maybePop(context);
                      }
                    },
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
        actions: [
          // Botón para limpiar la vista (no borra datos de Firestore)
          if (!_vistaLimpia)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined, color: AppTheme.muted),
              tooltip: 'Limpiar vista',
              onPressed: () {
                setState(() {
                  _vistaLimpia = true;
                  _modoFiltro = 'todo';
                  _fechaSeleccionada = null;
                });
              },
            ),
          if (_vistaLimpia)
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Restaurar'),
              onPressed: () {
                setState(() {
                  _vistaLimpia = false;
                });
              },
            ),
        ],
      ),
      body: _vistaLimpia ? _buildVistaLimpia() : _buildContenidoFiltrado(),
    );
  }

  Widget _buildVistaLimpia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: AppTheme.muted.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            const Text(
              'Vista limpiada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.dark),
            ),
            const SizedBox(height: 10),
            const Text(
              'Los datos en Firestore no se eliminaron. Pulsa "Restaurar" para elegir una fecha o ver todas las estadísticas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => setState(() => _vistaLimpia = false),
              icon: const Icon(Icons.bar_chart_outlined),
              label: const Text('Ver estadísticas'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.violet,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenidoFiltrado() {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('clientes').snapshots(),
      builder: (context, snapClientes) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('compras').snapshots(),
          builder: (context, snapCompras) {
            return StreamBuilder<QuerySnapshot>(
              stream: db.collection('pagos').snapshots(),
              builder: (context, snapPagos) {
                final clientes = snapClientes.data?.docs ?? [];
                final todasCompras = snapCompras.data?.docs ?? [];
                final todosPagos = snapPagos.data?.docs ?? [];

                // Filtrar por fecha si está seleccionada
                final compras = _filtrarDocs(todasCompras);
                final pagos = _filtrarDocs(todosPagos);

                double totalVentas = 0;
                double totalCobrado = 0;
                int totalPrendas = 0;
                final Map<String, int> ventasPorPrenda = {};
                final Map<String, double> comprasPorCliente = {};
                final Map<int, int> ventasPorHora = {};
                int totalTransacciones = 0;

                for (final doc in compras) {
                  final d = doc.data() as Map<String, dynamic>;
                  final monto = (d['total'] ?? d['subtotal'] ?? 0).toDouble();
                  final cantPrendas = (d['cantidad'] is num)
                      ? (d['cantidad'] as num).toInt()
                      : 1;
                  final prendaNombre =
                      (d['prenda'] ?? d['prendaNombre'] ?? d['nombre_prenda'] ?? 'Otra')
                          .toString();
                  final clienteId = (d['clienteId'] ?? '').toString();

                  totalVentas += monto;
                  totalPrendas += cantPrendas;
                  totalTransacciones++;

                  ventasPorPrenda.update(
                    prendaNombre,
                    (v) => v + cantPrendas,
                    ifAbsent: () => cantPrendas,
                  );
                  comprasPorCliente.update(
                    clienteId,
                    (v) => v + monto,
                    ifAbsent: () => monto,
                  );

                  // Estadísticas por hora del día
                  final ts = d['fecha'];
                  if (ts is Timestamp) {
                    final hora = ts.toDate().hour;
                    ventasPorHora.update(hora, (v) => v + 1, ifAbsent: () => 1);
                  }
                }

                for (final doc in pagos) {
                  final d = doc.data() as Map<String, dynamic>;
                  totalCobrado += (d['monto'] ?? 0).toDouble();
                }

                final totalPendiente =
                    (totalVentas - totalCobrado).clamp(0.0, double.infinity);
                final porcentajeCobrado = totalVentas > 0
                    ? (totalCobrado / totalVentas).clamp(0.0, 1.0)
                    : 0.0;

                final clientesConCompras = clientes
                    .where((doc) => (comprasPorCliente[doc.id] ?? 0) > 0)
                    .length;

                final prendasOrdenadas = ventasPorPrenda.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final topClientes = clientes
                    .map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return {
                        'nombre': (d['nombre'] ?? 'Sin nombre').toString(),
                        'total': comprasPorCliente[doc.id] ?? 0.0,
                      };
                    })
                    .toList()
                  ..sort((a, b) =>
                      (b['total'] as double).compareTo(a['total'] as double));

                // Hora pico (más ventas)
                int? horaPico;
                int maxVentasHora = 0;
                ventasPorHora.forEach((h, v) {
                  if (v > maxVentasHora) {
                    maxVentasHora = v;
                    horaPico = h;
                  }
                });

                return RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Encabezado ──
                      _buildEncabezado(),
                      const SizedBox(height: 16),

                      // ── Filtros de fecha ──
                      _buildFiltrosFecha(context),
                      const SizedBox(height: 20),

                      // ── Etiqueta de rango activo ──
                      if (_modoFiltro != 'todo' && _fechaSeleccionada != null)
                        _buildEtiquetaFiltro(),

                      // ── KPIs principales ──
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                        children: [
                          _tarjetaIndicador(
                            titulo: 'Total vendido',
                            valor: totalVentas,
                            icono: Icons.shopping_bag_outlined,
                            color: AppTheme.violet,
                          ),
                          _tarjetaIndicador(
                            titulo: 'Total abonado',
                            valor: totalCobrado,
                            icono: Icons.payments_outlined,
                            color: AppTheme.green,
                          ),
                          _tarjetaIndicador(
                            titulo: 'Por cobrar',
                            valor: totalPendiente,
                            icono: Icons.account_balance_wallet_outlined,
                            color: AppTheme.orange,
                          ),
                          _tarjetaCantidad(
                            titulo: 'Prendas vendidas',
                            valor: totalPrendas,
                            icono: Icons.checkroom_outlined,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Métricas adicionales ──
                      Row(
                        children: [
                          Expanded(
                            child: _miniIndicador(
                              titulo: 'Transacciones',
                              valor: '$totalTransacciones',
                              icono: Icons.receipt_long_outlined,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniIndicador(
                              titulo: 'Clientas activas',
                              valor: '$clientesConCompras / ${clientes.length}',
                              icono: Icons.people_outline,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),

                      if (horaPico != null) ...[
                        const SizedBox(height: 12),
                        _miniIndicador(
                          titulo: 'Hora pico de ventas',
                          valor:
                              '${horaPico.toString().padLeft(2, '0')}:00 — ${(horaPico! + 1).toString().padLeft(2, '0')}:00',
                          icono: Icons.access_time,
                          color: Colors.orange.shade700,
                          ancho: double.infinity,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Resumen de cobros ──
                      _tituloSeccion('Resumen de cobros'),
                      const SizedBox(height: 12),
                      _tarjetaBlanca(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Porcentaje cobrado de las ventas',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '${(porcentajeCobrado * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AppTheme.violet,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: porcentajeCobrado,
                                minHeight: 12,
                                backgroundColor: AppTheme.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.violet),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Faltan por cobrar: \$${totalPendiente.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppTheme.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Prendas más vendidas ──
                      _tituloSeccion('Prendas más vendidas'),
                      const SizedBox(height: 12),
                      if (prendasOrdenadas.isEmpty)
                        _mensajeVacio('No hay ventas en el período seleccionado.')
                      else
                        _tarjetaBlanca(
                          child: Column(
                            children: prendasOrdenadas.take(6).map((prenda) {
                              final maximo = prendasOrdenadas.first.value;
                              final progreso =
                                  maximo > 0 ? prenda.value / maximo : 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            prenda.key,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          '${prenda.value} uds.',
                                          style: const TextStyle(
                                              color: AppTheme.muted,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 9),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progreso,
                                        minHeight: 9,
                                        backgroundColor: AppTheme.border,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                AppTheme.violet),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // ── Top clientes ──
                      _tituloSeccion('Clientas con más compras'),
                      const SizedBox(height: 12),
                      if (topClientes.isEmpty ||
                          (topClientes.first['total'] as double) == 0)
                        _mensajeVacio('No hay clientes registrados para este período.')
                      else
                        _tarjetaBlanca(
                          child: Column(
                            children:
                                topClientes.take(5).map((cliente) {
                              final nombre = cliente['nombre'] as String;
                              final total = cliente['total'] as double;
                              if (total == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.violet
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        nombre.isNotEmpty
                                            ? nombre[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: AppTheme.violet,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      '\$${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppTheme.violet,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 20),
                      Text(
                        _notaFiltro(),
                        style:
                            const TextStyle(color: AppTheme.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Filtra documentos de Firestore según el modo activo
  List<QueryDocumentSnapshot> _filtrarDocs(List<QueryDocumentSnapshot> docs) {
    if (_modoFiltro == 'todo' || _fechaSeleccionada == null) return docs;

    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = d['fecha'];
      if (ts is! Timestamp) return false;
      final fecha = ts.toDate();

      if (_modoFiltro == 'dia') {
        return fecha.year == _fechaSeleccionada!.year &&
            fecha.month == _fechaSeleccionada!.month &&
            fecha.day == _fechaSeleccionada!.day;
      } else {
        // mes
        return fecha.year == _fechaSeleccionada!.year &&
            fecha.month == _fechaSeleccionada!.month;
      }
    }).toList();
  }

  Widget _buildEncabezado() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.violet, AppTheme.violet.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.bar_chart_rounded, color: Colors.white, size: 42),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estadísticas Vendix',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  'Ventas, cobros, prendas y clientas en tiempo real.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosFecha(BuildContext context) {
    return Row(
      children: [
        // Botón "Todo"
        _chipFiltro(
          label: 'Todo',
          activo: _modoFiltro == 'todo',
          onTap: () => setState(() {
            _modoFiltro = 'todo';
            _fechaSeleccionada = null;
          }),
        ),
        const SizedBox(width: 8),
        // Botón "Por día"
        _chipFiltro(
          label: 'Por día',
          activo: _modoFiltro == 'dia',
          icono: Icons.calendar_today_outlined,
          onTap: () async {
            final fecha = await showDatePicker(
              context: context,
              initialDate: _fechaSeleccionada ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              helpText: 'Selecciona el día',
            );
            if (fecha != null) {
              setState(() {
                _modoFiltro = 'dia';
                _fechaSeleccionada = fecha;
              });
            }
          },
        ),
        const SizedBox(width: 8),
        // Botón "Por mes"
        _chipFiltro(
          label: 'Por mes',
          activo: _modoFiltro == 'mes',
          icono: Icons.date_range_outlined,
          onTap: () async {
            final fecha = await showDatePicker(
              context: context,
              initialDate: _fechaSeleccionada ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              helpText: 'Selecciona cualquier día del mes',
            );
            if (fecha != null) {
              setState(() {
                _modoFiltro = 'mes';
                _fechaSeleccionada = DateTime(fecha.year, fecha.month);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _chipFiltro({
    required String label,
    required bool activo,
    IconData? icono,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? AppTheme.violet : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? AppTheme.violet : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono,
                  size: 14, color: activo ? Colors.white : AppTheme.muted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: activo ? Colors.white : AppTheme.dark,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtiquetaFiltro() {
    final f = _fechaSeleccionada!;
    final meses = [
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    final texto = _modoFiltro == 'dia'
        ? '${f.day} de ${meses[f.month]} de ${f.year}'
        : '${meses[f.month].toUpperCase()} ${f.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.violet.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.violet.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 16, color: AppTheme.violet),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mostrando: $texto',
                style: const TextStyle(
                    color: AppTheme.violet,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _modoFiltro = 'todo';
                _fechaSeleccionada = null;
              }),
              child: const Icon(Icons.close, size: 16, color: AppTheme.violet),
            ),
          ],
        ),
      ),
    );
  }

  String _notaFiltro() {
    if (_modoFiltro == 'todo') {
      return 'Mostrando datos acumulados en Firestore en tiempo real.';
    }
    if (_modoFiltro == 'dia' && _fechaSeleccionada != null) {
      return 'Datos filtrados del día ${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}.';
    }
    if (_modoFiltro == 'mes' && _fechaSeleccionada != null) {
      return 'Datos filtrados del mes ${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}.';
    }
    return '';
  }

  Widget _tarjetaIndicador({
    required String titulo,
    required double valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 27),
          Text(titulo, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\$${valor.toStringAsFixed(2)}',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCantidad({
    required String titulo,
    required int valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 27),
          Text(titulo, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          Text(
            '$valor',
            style: TextStyle(
                color: color, fontSize: 25, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _miniIndicador({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    double? ancho,
  }) {
    return Container(
      width: ancho,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style:
                        const TextStyle(color: AppTheme.muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo) => Text(
        titulo,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );

  Widget _tarjetaBlanca({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _mensajeVacio(String mensaje) {
    return _tarjetaBlanca(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.muted),
          ),
        ),
      ),
    );
  }
}
