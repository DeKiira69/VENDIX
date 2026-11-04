import 'package:flutter/material.dart';

import '../../services/client_service.dart';

class ClientPurchasesScreen extends StatelessWidget {
  const ClientPurchasesScreen({super.key});

  static const Color violeta = Color(0xFF7950C2);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: ClientService.clienteActual(),
        builder: (context, clienteSnapshot) {
          if (clienteSnapshot.hasError) {
            return const Center(child: Text('Error al consultar el perfil.'));
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

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: ClientService.compras(cliente['id'] as String),
            builder: (context, comprasSnapshot) {
              if (comprasSnapshot.hasError) {
                return const Center(
                  child: Text('No se pudieron cargar las compras.'),
                );
              }

              if (!comprasSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final compras = comprasSnapshot.data!;
              final prendas = compras.fold<int>(
                0,
                (total, compra) =>
                    total + ClientService.numero(compra['cantidad']).toInt(),
              );

              final cantidades = <String, int>{};
              for (final compra in compras) {
                final nombre =
                    (compra['prendaNombre'] ??
                            compra['nombrePrenda'] ??
                            compra['descripcion'] ??
                            'Prenda')
                        .toString();
                cantidades[nombre] =
                    (cantidades[nombre] ?? 0) +
                    ClientService.numero(compra['cantidad']).toInt();
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  const Text(
                    'TU HISTORIAL',
                    style: TextStyle(
                      color: violeta,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mis compras',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: violeta,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Lo que has comprado',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        Text(
                          '$prendas prendas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (cantidades.isNotEmpty)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.65,
                      children: cantidades.entries.map((entrada) {
                        return Container(
                          padding: const EdgeInsets.all(13),
                          decoration: _tarjeta(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.checkroom_outlined,
                                color: violeta,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${entrada.value} ${entrada.value == 1 ? 'unidad' : 'unidades'}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                entrada.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'Historial',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  if (compras.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no tienes compras registradas.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...compras.map((compra) {
                      final fecha = ClientService.fecha(compra['fecha']);
                      final cantidad = ClientService.numero(compra['cantidad'])
                          .toInt();
                      final precio = ClientService.numero(
                        compra['precioUnitario'],
                      );
                      final subtotal = compra['subtotal'] is num
                          ? ClientService.numero(compra['subtotal'])
                          : precio * cantidad;
                      final nombre =
                          (compra['prendaNombre'] ??
                                  compra['nombrePrenda'] ??
                                  compra['descripcion'] ??
                                  'Compra registrada')
                              .toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: _tarjeta(),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEF6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: violeta,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$cantidad prendas · '
                                    '${fecha.day.toString().padLeft(2, '0')}/'
                                    '${fecha.month.toString().padLeft(2, '0')}/'
                                    '${fecha.year}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    'Precio unitario: ${ClientService.dinero(precio)}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ClientService.dinero(subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
      ),
    );
  }

  static BoxDecoration _tarjeta() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFECE6F0)),
  );
}
