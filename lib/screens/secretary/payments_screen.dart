import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _db = FirebaseFirestore.instance;
  final _montoController = TextEditingController();
  final _observacionController = TextEditingController();

  String? _clienteSeleccionadoId;
  String _clienteSeleccionadoNombre = '';
  String _clienteSeleccionadoTel = '';

  @override
  void dispose() {
    _montoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  double get _montoIngresado {
    return double.tryParse(_montoController.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _registrarPago(double deuda) async {
    if (_clienteSeleccionadoId == null) {
      _mostrarMensaje('Selecciona un cliente.');
      return;
    }
    final monto = _montoIngresado;
    if (monto <= 0) {
      _mostrarMensaje('Ingresa un monto válido mayor que cero.');
      return;
    }
    if (monto > deuda + 0.001) {
      _mostrarMensaje('El abono no puede superar la deuda de \$${deuda.toStringAsFixed(2)}.');
      return;
    }

    final observacion = _observacionController.text.trim();

    await _db.collection('pagos').add({
      'clienteId': _clienteSeleccionadoId,
      'clienteNombre': _clienteSeleccionadoNombre,
      'monto': monto,
      'observacion': observacion,
      'fecha': FieldValue.serverTimestamp(),
    });

    _montoController.clear();
    _observacionController.clear();
    setState(() {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Abono de \$${monto.toStringAsFixed(2)} registrado para $_clienteSeleccionadoNombre.'),
      backgroundColor: AppTheme.green,
    ));
  }

  void _mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pagos y abonos'),
        backgroundColor: AppTheme.background,
        elevation: 0,
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('clientes').orderBy('nombre').snapshots(),
        builder: (context, snapClientes) {
          final clientes = snapClientes.data?.docs ?? [];
          if (clientes.isEmpty) {
            return const Center(child: Text('Todavía no hay clientes registrados.'));
          }

          // Autoseleccionar primero si no hay selección
          if (_clienteSeleccionadoId == null && clientes.isNotEmpty) {
            final d = clientes.first.data() as Map<String, dynamic>;
            _clienteSeleccionadoId = clientes.first.id;
            _clienteSeleccionadoNombre = d['nombre'] ?? '';
            _clienteSeleccionadoTel = d['telefono'] ?? '';
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _db.collection('compras')
                .where('clienteId', isEqualTo: _clienteSeleccionadoId)
                .snapshots(),
            builder: (context, snapCompras) {
              double totalComprado = 0;
              for (final doc in snapCompras.data?.docs ?? []) {
                final d = doc.data() as Map<String, dynamic>;
                totalComprado += (d['total'] ?? d['subtotal'] ?? 0).toDouble();
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _db.collection('pagos')
                    .where('clienteId', isEqualTo: _clienteSeleccionadoId)
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snapPagos) {
                  double totalPagado = 0;
                  for (final doc in snapPagos.data?.docs ?? []) {
                    final d = doc.data() as Map<String, dynamic>;
                    totalPagado += (d['monto'] ?? 0).toDouble();
                  }
                  final deuda = (totalComprado - totalPagado).clamp(0.0, double.infinity);
                  final pagos = snapPagos.data?.docs ?? [];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _encabezado(),
                      const SizedBox(height: 20),

                      // Selector de cliente
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _estiloTarjeta(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Seleccionar cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _clienteSeleccionadoId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.border),
                                ),
                              ),
                              items: clientes.map((doc) {
                                final d = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(d['nombre'] ?? '', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (id) {
                                if (id == null) return;
                                final doc = clientes.firstWhere((d) => d.id == id);
                                final d = doc.data() as Map<String, dynamic>;
                                setState(() {
                                  _clienteSeleccionadoId = id;
                                  _clienteSeleccionadoNombre = d['nombre'] ?? '';
                                  _clienteSeleccionadoTel = d['telefono'] ?? '';
                                  _montoController.clear();
                                  _observacionController.clear();
                                });
                              },
                            ),
                            if (_clienteSeleccionadoTel.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('Teléfono: $_clienteSeleccionadoTel',
                                  style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resumen de deuda
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estado de cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _filaResumen('Total de compras', totalComprado, Icons.shopping_bag_outlined),
                            const SizedBox(height: 12),
                            _filaResumen('Total abonado', totalPagado, Icons.payments_outlined),
                            const SizedBox(height: 12),
                            Divider(color: AppTheme.border),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Saldo pendiente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 5),
                                  Text(deuda > 0 ? 'Tiene un valor por pagar' : 'Cuenta al día',
                                      style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                ],
                              )),
                              Text('\$${deuda.toStringAsFixed(2)}',
                                style: TextStyle(color: deuda > 0 ? AppTheme.orange : AppTheme.green,
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Formulario de pago
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: _estiloTarjeta(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Registrar un abono', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(deuda > 0 ? 'Ingresa el valor que entrega el cliente.'
                                : 'No hay una deuda pendiente para registrar un abono.',
                                style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _montoController,
                              enabled: deuda > 0,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Monto del abono',
                                hintText: 'Ej. 10.00',
                                prefixText: '\$ ',
                                prefixIcon: const Icon(Icons.attach_money),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                            ),
                            if (_montoIngresado > deuda && deuda > 0) ...[
                              const SizedBox(height: 6),
                              const Text('El monto supera el saldo pendiente.', style: TextStyle(color: AppTheme.orange, fontSize: 12)),
                            ],
                            const SizedBox(height: 14),
                            TextField(
                              controller: _observacionController,
                              enabled: deuda > 0,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Observación (opcional)',
                                hintText: 'Ej. Abono en efectivo',
                                prefixIcon: const Icon(Icons.notes),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: deuda > 0 ? () => _registrarPago(deuda) : null,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Guardar abono', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.violet, foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppTheme.border,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Historial de pagos
                      Row(children: [
                        const Expanded(child: Text('Historial de abonos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        Text('${pagos.length} registros', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                      ]),
                      const SizedBox(height: 12),
                      if (pagos.isEmpty)
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(24),
                          decoration: _estiloTarjeta(),
                          child: const Column(children: [
                            Icon(Icons.receipt_long_outlined, size: 36, color: AppTheme.muted),
                            SizedBox(height: 10),
                            Text('Todavía no hay abonos registrados.'),
                          ]),
                        )
                      else
                        ...pagos.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final monto = (d['monto'] ?? 0).toDouble();
                          final obs = (d['observacion'] ?? '').toString();
                          final ts = d['fecha'] as Timestamp?;
                          final fecha = ts?.toDate() ?? DateTime.now();
                          final fechaTexto =
                              '${fecha.day.toString().padLeft(2, '0')}/'
                              '${fecha.month.toString().padLeft(2, '0')}/'
                              '${fecha.year} '
                              '${fecha.hour.toString().padLeft(2, '0')}:'
                              '${fecha.minute.toString().padLeft(2, '0')}';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: _estiloTarjeta(),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.payments_outlined, color: AppTheme.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Abono registrado', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text(fechaTexto, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                  if (obs.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(obs, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                  ],
                                ],
                              )),
                              const SizedBox(width: 8),
                              Text('+\$${monto.toStringAsFixed(2)}',
                                  style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.bold, fontSize: 15)),
                            ]),
                          );
                        }),
                    ],
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(children: [
        Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 42),
        SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Control de pagos', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text('Registra abonos y consulta las deudas de tus clientes.',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        )),
      ]),
    );
  }

  Widget _filaResumen(String titulo, double monto, IconData icono) {
    return Row(children: [
      Icon(icono, color: AppTheme.violet, size: 21),
      const SizedBox(width: 10),
      Expanded(child: Text(titulo, style: const TextStyle(color: AppTheme.muted))),
      Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
    ]);
  }

  BoxDecoration _estiloTarjeta() {
    return BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    );
  }
}
