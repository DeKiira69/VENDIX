import 'package:flutter/material.dart';

import '../../data/datos_prueba.dart';
import '../../theme/app_theme.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  ClienteDemo? _clienteSeleccionado;
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (clientesDemo.isNotEmpty) {
      _clienteSeleccionado = clientesDemo.first;
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  double get _montoIngresado {
    final texto = _montoController.text.trim().replaceAll(',', '.');
    return double.tryParse(texto) ?? 0;
  }

  void _registrarPago() {
    final cliente = _clienteSeleccionado;

    if (cliente == null) {
      _mostrarMensaje('Selecciona un cliente.');
      return;
    }

    final monto = _montoIngresado;

    if (monto <= 0) {
      _mostrarMensaje('Ingresa un monto válido mayor que cero.');
      return;
    }

    if (cliente.deuda <= 0) {
      _mostrarMensaje('Este cliente no tiene deudas pendientes.');
      return;
    }

    if (monto > cliente.deuda + 0.001) {
      _mostrarMensaje(
        'El abono no puede superar la deuda de '
        '\$${cliente.deuda.toStringAsFixed(2)}.',
      );
      return;
    }

    final observacion = _observacionController.text.trim();

    final registrado = cliente.registrarPago(monto);

    if (!registrado) {
      _mostrarMensaje('No se pudo registrar el pago.');
      return;
    }

    // Si se escribió una observación, se actualiza el último
    // registro para conservarla en el historial.
    if (observacion.isNotEmpty && cliente.pagos.isNotEmpty) {
      final ultimoPago = cliente.pagos.last;
      cliente.pagos[cliente.pagos.length - 1] = PagoDemo(
        monto: ultimoPago.monto,
        fecha: ultimoPago.fecha,
        observacion: observacion,
      );
    }

    _montoController.clear();
    _observacionController.clear();

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Abono de \$${monto.toStringAsFixed(2)} registrado '
          'para ${cliente.nombre}.',
        ),
        backgroundColor: AppTheme.green,
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pagos y abonos'),
        backgroundColor: AppTheme.background,
      ),
      body: clientesDemo.isEmpty
          ? const Center(child: Text('Todavía no hay clientes registrados.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _crearEncabezado(),
                const SizedBox(height: 20),
                _crearSelectorCliente(),
                const SizedBox(height: 16),
                if (_clienteSeleccionado != null) ...[
                  _crearResumenDeuda(_clienteSeleccionado!),
                  const SizedBox(height: 20),
                  _crearFormularioPago(_clienteSeleccionado!),
                  const SizedBox(height: 24),
                  _crearHistorial(_clienteSeleccionado!),
                ],
              ],
            ),
    );
  }

  Widget _crearEncabezado() {
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
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control de pagos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Registra abonos y consulta las deudas de tus clientes.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearSelectorCliente() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _estiloTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seleccionar cliente',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<ClienteDemo>(
            initialValue: _clienteSeleccionado,
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
            items: clientesDemo.map((cliente) {
              return DropdownMenuItem<ClienteDemo>(
                value: cliente,
                child: Text(cliente.nombre, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (cliente) {
              setState(() {
                _clienteSeleccionado = cliente;
                _montoController.clear();
                _observacionController.clear();
              });
            },
          ),
          if (_clienteSeleccionado != null) ...[
            const SizedBox(height: 12),
            Text(
              'Teléfono: ${_clienteSeleccionado!.telefono}',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _crearResumenDeuda(ClienteDemo cliente) {
    final tieneDeuda = cliente.deuda > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de cuenta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _crearFilaResumen(
            'Total de compras',
            cliente.totalComprado,
            Icons.shopping_bag_outlined,
          ),
          const SizedBox(height: 12),
          _crearFilaResumen(
            'Total abonado',
            cliente.totalPagado,
            Icons.payments_outlined,
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.border),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo pendiente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tieneDeuda ? 'Tiene un valor por pagar' : 'Cuenta al día',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${cliente.deuda.toStringAsFixed(2)}',
                style: TextStyle(
                  color: tieneDeuda ? AppTheme.orange : AppTheme.green,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crearFilaResumen(String titulo, double monto, IconData icono) {
    return Row(
      children: [
        Icon(icono, color: AppTheme.violet, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(titulo, style: TextStyle(color: AppTheme.muted)),
        ),
        Text(
          '\$${monto.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _crearFormularioPago(ClienteDemo cliente) {
    final puedePagar = cliente.deuda > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _estiloTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Registrar un abono',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            puedePagar
                ? 'Ingresa el valor que entrega el cliente.'
                : 'No hay una deuda pendiente para registrar un abono.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _montoController,
            enabled: puedePagar,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Monto del abono',
              hintText: 'Ej. 10.00',
              prefixText: '\$ ',
              prefixIcon: const Icon(Icons.attach_money),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          if (_montoIngresado > cliente.deuda) ...[
            const SizedBox(height: 6),
            Text(
              'El monto supera el saldo pendiente.',
              style: TextStyle(color: AppTheme.orange, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _observacionController,
            enabled: puedePagar,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Observación (opcional)',
              hintText: 'Ej. Abono en efectivo',
              prefixIcon: const Icon(Icons.notes),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: puedePagar ? _registrarPago : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Guardar abono',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearHistorial(ClienteDemo cliente) {
    final pagos = cliente.pagos.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial de abonos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${pagos.length} registros',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pagos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _estiloTarjeta(),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: AppTheme.muted,
                ),
                const SizedBox(height: 10),
                const Text('Todavía no hay abonos registrados.'),
              ],
            ),
          )
        else
          ...pagos.map((pago) {
            final fecha = pago.fecha;
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payments_outlined, color: AppTheme.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Abono registrado',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          fechaTexto,
                          style: TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                        if (pago.observacion != null &&
                            pago.observacion!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            pago.observacion!,
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+\$${pago.monto.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppTheme.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  BoxDecoration _estiloTarjeta() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    );
  }
}
