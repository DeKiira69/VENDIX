import 'package:flutter/material.dart';

import '../../services/client_service.dart';

class ClientBalanceScreen extends StatelessWidget {
  const ClientBalanceScreen({super.key});

  static const Color violeta = Color(0xFF7950C2);
  static const Color naranja = Color(0xFFD65C3B);
  static const Color verde = Color(0xFF15956B);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: ClientService.clienteActual(),
        builder: (context, clienteSnapshot) {
          if (clienteSnapshot.hasError) {
            return const Center(child: Text('Error al cargar tu perfil.'));
          }

          if (!clienteSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cliente = clienteSnapshot.data;
          if (cliente == null) {
            return const Center(
              child: Text('Tu cuenta todavía no está vinculada a un cliente.'),
            );
          }

          final id = cliente['id'] as String;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: ClientService.compras(id),
            builder: (context, comprasSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: ClientService.pagos(id),
                builder: (context, pagosSnapshot) {
                  if (comprasSnapshot.hasError || pagosSnapshot.hasError) {
                    return const Center(
                      child: Text('No se pudo cargar tu estado de cuenta.'),
                    );
                  }

                  if (!comprasSnapshot.hasData || !pagosSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final compras = comprasSnapshot.data!;
                  final pagos = pagosSnapshot.data!;

                  final totalComprado = compras.fold<double>(0, (
                    total,
                    compra,
                  ) {
                    final subtotal = compra['subtotal'] is num
                        ? ClientService.numero(compra['subtotal'])
                        : ClientService.numero(compra['precioUnitario']) *
                              ClientService.numero(compra['cantidad']);
                    return total + subtotal;
                  });

                  final totalPagado = pagos.fold<double>(
                    0,
                    (total, pago) =>
                        total + ClientService.numero(pago['monto']),
                  );

                  final saldo = (totalComprado - totalPagado)
                      .clamp(0.0, double.infinity)
                      .toDouble();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      const Text(
                        'ESTADO DE CUENTA',
                        style: TextStyle(
                          color: violeta,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mi saldo',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Saldo pendiente',
                              style: TextStyle(color: naranja),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ClientService.dinero(saldo),
                              style: const TextStyle(
                                color: naranja,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              saldo == 0
                                  ? 'Tu cuenta está al día'
                                  : 'Consulta con la tienda si tienes dudas',
                              style: const TextStyle(
                                color: naranja,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: _tarjeta(),
                        child: Column(
                          children: [
                            _fila('Total de compras', totalComprado),
                            const Divider(height: 25),
                            _fila('Total pagado', totalPagado, color: verde),
                            const Divider(height: 25),
                            _fila('Saldo pendiente', saldo, color: naranja),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E8FC),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: violeta),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tus pagos se reflejarán aquí cuando la tienda los registre.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Pagos recientes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (pagos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Todavía no tienes pagos registrados.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...pagos.map((pago) {
                          final fecha = ClientService.fecha(pago['fecha']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: _tarjeta(),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFE6F6EE),
                                  child: Icon(
                                    Icons.check,
                                    color: verde,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Pago registrado',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${fecha.day}/${fecha.month}/${fecha.year}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if ((pago['observacion'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                          pago['observacion'].toString(),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '+${ClientService.dinero(pago['monto'])}',
                                  style: const TextStyle(
                                    color: verde,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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

  static Widget _fila(String titulo, double monto, {Color? color}) {
    return Row(
      children: [
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12))),
        Text(
          ClientService.dinero(monto),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFF241B35),
          ),
        ),
      ],
    );
  }

  static BoxDecoration _tarjeta() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: const Color(0xFFECE6F0)),
  );
}
