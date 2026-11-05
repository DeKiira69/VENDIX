import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class StatisticsScreen extends StatelessWidget {
  final VoidCallback? onVolver;

  const StatisticsScreen({super.key, this.onVolver});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: (onVolver != null || Navigator.canPop(context))
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: InkWell(
                    onTap: () {
                      if (onVolver != null) {
                        onVolver!();
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('clientes').snapshots(),
        builder: (context, snapClientes) {
          return StreamBuilder<QuerySnapshot>(
            stream: db.collection('compras').snapshots(),
            builder: (context, snapCompras) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('pagos').snapshots(),
                builder: (context, snapPagos) {
                  final clientes = snapClientes.data?.docs ?? [];
                  final compras = snapCompras.data?.docs ?? [];
                  final pagos = snapPagos.data?.docs ?? [];

                  double totalVentas = 0;
                  double totalCobrado = 0;
                  int totalPrendas = 0;
                  final Map<String, int> ventasPorPrenda = {};
                  final Map<String, double> comprasPorCliente = {};

                  for (final doc in compras) {
                    final d = doc.data() as Map<String, dynamic>;
                    final monto = (d['total'] ?? d['subtotal'] ?? 0).toDouble();
                    final prendas = (d['cantidad'] ?? 0) as int;
                    final prendaNombre = (d['prenda'] ?? d['nombre_prenda'] ?? 'Otra').toString();
                    final clienteId = (d['clienteId'] ?? '').toString();

                    totalVentas += monto;
                    totalPrendas += prendas;
                    ventasPorPrenda.update(prendaNombre, (v) => v + prendas, ifAbsent: () => prendas);
                    comprasPorCliente.update(clienteId, (v) => v + monto, ifAbsent: () => monto);
                  }

                  for (final doc in pagos) {
                    final d = doc.data() as Map<String, dynamic>;
                    totalCobrado += (d['monto'] ?? 0).toDouble();
                  }

                  final totalPendiente = (totalVentas - totalCobrado).clamp(0.0, double.infinity);
                  final clientesConDeuda = clientes.where((doc) {
                    final id = doc.id;
                    final comprado = comprasPorCliente[id] ?? 0;
                    return comprado > 0;
                  }).length;

                  final porcentajeCobrado = totalVentas > 0
                      ? (totalCobrado / totalVentas).clamp(0.0, 1.0)
                      : 0.0;

                  final prendasOrdenadas = ventasPorPrenda.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  // Top clientes por monto comprado
                  final topClientes = clientes.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return {
                      'nombre': (d['nombre'] ?? 'Sin nombre').toString(),
                      'total': comprasPorCliente[doc.id] ?? 0.0,
                    };
                  }).toList()
                    ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

                  return RefreshIndicator(
                    onRefresh: () async {},
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _encabezado(),
                        const SizedBox(height: 20),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                          children: [
                            _tarjetaIndicador(titulo: 'Total vendido', valor: totalVentas, icono: Icons.shopping_bag_outlined, color: AppTheme.violet),
                            _tarjetaIndicador(titulo: 'Total abonado', valor: totalCobrado, icono: Icons.payments_outlined, color: AppTheme.green),
                            _tarjetaIndicador(titulo: 'Por cobrar', valor: totalPendiente, icono: Icons.account_balance_wallet_outlined, color: AppTheme.orange),
                            _tarjetaCantidad(titulo: 'Prendas vendidas', valor: totalPrendas, icono: Icons.checkroom_outlined, color: Colors.blue),
                          ],
                        ),

                        const SizedBox(height: 24),

                        _tituloSeccion('Resumen de cobros'),
                        const SizedBox(height: 12),
                        _tarjetaBlanca(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(child: Text('Porcentaje cobrado de las ventas', style: TextStyle(fontWeight: FontWeight.w600))),
                                  Text('${(porcentajeCobrado * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold, fontSize: 17)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: porcentajeCobrado,
                                  minHeight: 12,
                                  backgroundColor: AppTheme.border,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.violet),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('Hay $clientesConDeuda clientes con compras registradas.',
                                style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        _tituloSeccion('Prendas más vendidas'),
                        const SizedBox(height: 12),

                        if (prendasOrdenadas.isEmpty)
                          _mensajeVacio('Todavía no hay ventas registradas.')
                        else
                          _tarjetaBlanca(
                            child: Column(
                              children: prendasOrdenadas.take(5).map((prenda) {
                                final maximo = prendasOrdenadas.first.value;
                                final progreso = maximo > 0 ? prenda.value / maximo : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(prenda.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                                          Text('${prenda.value} unidades', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 9),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: progreso,
                                          minHeight: 9,
                                          backgroundColor: AppTheme.border,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.violet),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 24),

                        _tituloSeccion('Clientes con más compras'),
                        const SizedBox(height: 12),

                        if (topClientes.isEmpty)
                          _mensajeVacio('Todavía no hay clientes registrados.')
                        else
                          _tarjetaBlanca(
                            child: Column(
                              children: topClientes.take(5).map((cliente) {
                                final nombre = cliente['nombre'] as String;
                                final total = cliente['total'] as double;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
                                        child: Text(
                                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                                          style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                      Text('\$${total.toStringAsFixed(2)}',
                                        style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 16),
                        const Text(
                          'Las estadísticas muestran los datos acumulados en Firestore en tiempo real.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 12),
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
      ),
    );
  }

  Widget _encabezado() {
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
                Text('Resumen de Vendix', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text('Consulta tus ventas, cobros y prendas favoritas.', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaIndicador({required String titulo, required double valor, required IconData icono, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 27),
          Text(titulo, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('\$${valor.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCantidad({required String titulo, required int valor, required IconData icono, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 27),
          Text(titulo, style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          Text('$valor', style: TextStyle(color: color, fontSize: 25, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo) => Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _tarjetaBlanca({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
      child: child,
    );
  }

  Widget _mensajeVacio(String mensaje) {
    return _tarjetaBlanca(
      child: Center(child: Padding(padding: const EdgeInsets.all(16),
        child: Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)))),
    );
  }
}
