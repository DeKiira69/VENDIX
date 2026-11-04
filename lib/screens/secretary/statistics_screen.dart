import 'package:flutter/material.dart';

import '../../data/datos_prueba.dart';
import '../../theme/app_theme.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalVentas = clientesDemo.fold<double>(
      0,
      (total, cliente) => total + cliente.totalComprado,
    );

    final totalCobrado = clientesDemo.fold<double>(
      0,
      (total, cliente) => total + cliente.totalPagado,
    );

    final totalPendiente = clientesDemo.fold<double>(
      0,
      (total, cliente) => total + cliente.deuda,
    );

    final totalPrendas = clientesDemo.fold<int>(
      0,
      (total, cliente) => total + cliente.prendas,
    );

    final clientesConDeuda = clientesDemo
        .where((cliente) => cliente.deuda > 0)
        .length;

    final ventasPorPrenda = <String, int>{};

    for (final cliente in clientesDemo) {
      for (final compra in cliente.compras) {
        ventasPorPrenda.update(
          compra.prendaNombre,
          (cantidad) => cantidad + compra.cantidad,
          ifAbsent: () => compra.cantidad,
        );
      }
    }

    final prendasOrdenadas = ventasPorPrenda.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final clientesOrdenados = List<ClienteDemo>.from(clientesDemo)
      ..sort((a, b) => b.totalComprado.compareTo(a.totalComprado));

    final porcentajeCobrado = totalVentas > 0
        ? (totalCobrado / totalVentas).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: AppTheme.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Al volver a dibujar la pantalla se recalculan los datos.
        },
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
                  color: Colors.blue,
                ),
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
                      const Expanded(
                        child: Text(
                          'Porcentaje cobrado de las ventas',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(porcentajeCobrado * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.violet,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hay $clientesConDeuda clientes con saldo pendiente.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
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
                              Expanded(
                                child: Text(
                                  prenda.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${prenda.value} unidades',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.violet,
                              ),
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

            if (clientesOrdenados.isEmpty)
              _mensajeVacio('Todavía no hay clientes registrados.')
            else
              _tarjetaBlanca(
                child: Column(
                  children: clientesOrdenados.take(5).map((cliente) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.violet.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              cliente.nombre.isNotEmpty
                                  ? cliente.nombre[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppTheme.violet,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cliente.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${cliente.prendas} prendas',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${cliente.totalComprado.toStringAsFixed(2)}',
                            style: TextStyle(
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

            const SizedBox(height: 16),
            Text(
              'Las estadísticas muestran los datos acumulados disponibles '
              'en la aplicación; no representan necesariamente las ventas '
              'de un día o mes específico.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
                Text(
                  'Resumen de Vendix',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Consulta tus ventas, cobros y prendas favoritas.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
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
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

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
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      ),
    );
  }
}
