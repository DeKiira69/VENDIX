import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback alAbrirVentas;
  final VoidCallback alAbrirClientes;
  final VoidCallback alAbrirEstadisticas;
  final VoidCallback alAbrirMas;

  const HomeScreen({
    super.key,
    required this.alAbrirVentas,
    required this.alAbrirClientes,
    required this.alAbrirEstadisticas,
    required this.alAbrirMas,
  });

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _saludo(),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const Text(
              'Tu negocio está listo para vender.',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: AppTheme.violet,
              child: const Icon(Icons.person_outline, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: db.collection('clientes').snapshots(),
          builder: (context, snapClientes) {
            final clientes = snapClientes.data?.docs ?? [];
            final totalClientes = clientes.length;

            return StreamBuilder<QuerySnapshot>(
              stream: db.collection('compras').snapshots(),
              builder: (context, snapCompras) {
                final compras = snapCompras.data?.docs ?? [];

                double totalVentas = 0;
                double dineroHoy = 0;
                int prendasVendidas = 0;

                for (final doc in compras) {
                  final d = doc.data() as Map<String, dynamic>;
                  final monto = (d['total'] ?? d['subtotal'] ?? 0).toDouble();
                  final prendas = (d['cantidad'] ?? 0) as int;
                  totalVentas += monto;
                  prendasVendidas += prendas;

                  final ts = d['fecha'];
                  if (ts is Timestamp) {
                    final fecha = ts.toDate();
                    if (fecha.isAfter(inicioHoy) && fecha.isBefore(finHoy)) {
                      dineroHoy += monto;
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: db.collection('pagos').snapshots(),
                  builder: (context, snapPagos) {
                    double totalCobrado = 0;
                    for (final doc in snapPagos.data?.docs ?? []) {
                      final d = doc.data() as Map<String, dynamic>;
                      totalCobrado += (d['monto'] ?? 0).toDouble();
                    }
                    final totalPendiente = (totalVentas - totalCobrado).clamp(0.0, double.infinity);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tarjeta live
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(21),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF50308F),
                                  Color(0xFF7850B9),
                                  Color(0xFFA568B5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -30,
                                  top: -35,
                                  child: Container(
                                    width: 125,
                                    height: 125,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.09),
                                        width: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
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
                                          'LIVE EN CURSO',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Registra cada venta\nsin perder el ritmo.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 23,
                                        height: 1.2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      onPressed: alAbrirVentas,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF50308F),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add, size: 19),
                                      label: const Text(
                                        'Registrar venta',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Resumen de hoy',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                'En tiempo real',
                                style: TextStyle(fontSize: 10, color: AppTheme.muted),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.45,
                            children: [
                              _Indicador(titulo: 'Ventas de hoy', valor: '\$${dineroHoy.toStringAsFixed(2)}'),
                              _Indicador(titulo: 'Clientas', valor: '$totalClientes'),
                              _Indicador(titulo: 'Prendas vendidas', valor: '$prendasVendidas'),
                              _Indicador(
                                titulo: 'Por cobrar',
                                valor: '\$${totalPendiente.toStringAsFixed(2)}',
                                colorValor: AppTheme.orange,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Accesos rápidos',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.dark,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _Acceso(
                            icono: Icons.people_outline,
                            titulo: 'Clientas',
                            descripcion: 'Consulta compras y saldos',
                            onTap: alAbrirClientes,
                          ),
                          _Acceso(
                            icono: Icons.bar_chart_outlined,
                            titulo: 'Estadísticas',
                            descripcion: 'Revisa el rendimiento',
                            onTap: alAbrirEstadisticas,
                          ),
                          _Acceso(
                            icono: Icons.checkroom_outlined,
                            titulo: 'Prendas y precios',
                            descripcion: 'Administra el catálogo y los precios',
                            onTap: alAbrirMas,
                          ),

                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: _MiniIndicador(
                                  titulo: 'Total vendido',
                                  valor: '\$${totalVentas.toStringAsFixed(2)}',
                                  icono: Icons.shopping_bag_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MiniIndicador(
                                  titulo: 'Dinero cobrado',
                                  valor: '\$${totalCobrado.toStringAsFixed(2)}',
                                  icono: Icons.account_balance_wallet_outlined,
                                ),
                              ),
                            ],
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
    );
  }
}

class _Indicador extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color? colorValor;

  const _Indicador({required this.titulo, required this.valor, this.colorValor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          const SizedBox(height: 8),
          Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: colorValor ?? AppTheme.dark),
          ),
        ],
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  const _Acceso({required this.icono, required this.titulo, required this.descripcion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: const Color(0xFFF0E9FC), borderRadius: BorderRadius.circular(12)),
          child: Icon(icono, color: AppTheme.violet, size: 22),
        ),
        title: Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.dark)),
        subtitle: Text(descripcion, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.dark, size: 20),
      ),
    );
  }
}

class _MiniIndicador extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;

  const _MiniIndicador({required this.titulo, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppTheme.violet, size: 20),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dark)),
        ],
      ),
    );
  }
}
