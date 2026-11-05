import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../data/datos_prueba.dart';
import '../../services/client_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _buscarController = TextEditingController();
  String _filtro = 'Todas';

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busqueda = _buscarController.text.toLowerCase().trim();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: ClientService.todosLosClientes(),
                        builder: (context, snapshot) {
                          final total = snapshot.data?.length ?? 0;
                          return Text(
                            '$total REGISTRADOS',
                            style: const TextStyle(
                              color: AppTheme.violet,
                              fontSize: 10,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Clientes',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dark,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _nuevoCliente,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _buscarController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, teléfono o dirección',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: ['Todas', 'Con saldo', 'Al día'].map((filtro) {
                final activo = filtro == _filtro;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(filtro),
                    selected: activo,
                    onSelected: (_) => setState(() => _filtro = filtro),
                    selectedColor: AppTheme.violet,
                    labelStyle: TextStyle(
                      color: activo ? Colors.white : AppTheme.dark,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ClientService.todosLosClientes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar los clientes. '
                        'Revisa la conexión con Firebase y sus permisos.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clientes = snapshot.data ?? [];

                final filtrados = clientes.where((cliente) {
                  final nombre = (cliente['nombre'] ?? '')
                      .toString()
                      .toLowerCase();
                  final telefono = (cliente['telefono'] ?? '')
                      .toString()
                      .toLowerCase();
                  final direccion = (cliente['direccion'] ?? '')
                      .toString()
                      .toLowerCase();

                  return nombre.contains(busqueda) ||
                      telefono.contains(busqueda) ||
                      direccion.contains(busqueda);
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Text(
                      clientes.isEmpty
                          ? 'Todavía no hay clientes registrados'
                          : 'No se encontraron clientes',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    return _tarjetaCliente(filtrados[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCliente(Map<String, dynamic> cliente) {
    final clienteId = (cliente['id'] ?? '').toString();
    final nombre = (cliente['nombre'] ?? 'Sin nombre').toString();
    final telefono = (cliente['telefono'] ?? '').toString();

    final iniciales = nombre.trim().isEmpty
        ? '?'
        : nombre
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p[0])
              .join()
              .toUpperCase();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ClientService.compras(clienteId),
      builder: (context, comprasSnapshot) {
        final compras = comprasSnapshot.data ?? [];
        final totalComprado = ClientService.calcularTotalComprado(compras);

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: ClientService.pagos(clienteId),
          builder: (context, pagosSnapshot) {
            final pagos = pagosSnapshot.data ?? [];
            final totalPagado = ClientService.calcularTotalPagado(pagos);
            final deuda = ClientService.calcularSaldo(
              totalComprado: totalComprado,
              totalPagado: totalPagado,
            );

            if (_filtro == 'Con saldo' && deuda <= 0) {
              return const SizedBox.shrink();
            }

            if (_filtro == 'Al día' && deuda > 0) {
              return const SizedBox.shrink();
            }

            final prendas = compras.fold<int>(
              0,
              (total, compra) =>
                  total + ClientService.numero(compra['cantidad']).toInt(),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFEEF6),
                  child: Text(
                    iniciales,
                    style: const TextStyle(
                      color: AppTheme.violet,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '$telefono\n$prendas prendas registradas',
                  style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          deuda <= 0 ? 'AL DÍA' : 'DEBE',
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppTheme.muted,
                          ),
                        ),
                        Text(
                          '\$${deuda.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: deuda <= 0
                                ? AppTheme.green
                                : AppTheme.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.chevron_right, size: 19),
                  ],
                ),
                onTap: () => _resumenCliente(cliente),
              ),
            );
          },
        );
      },
    );
  }

  void _nuevoCliente() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final direccionController = TextEditingController();
    final correoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool guardando = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizarDialogo) => AlertDialog(
          title: const Text('Nueva clienta'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ingresa el nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ingresa el teléfono'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico (opcional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: direccionController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Dirección de casa',
                      hintText: 'Barrio, calle, número o referencia',
                      prefixIcon: Icon(Icons.home_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      actualizarDialogo(() => guardando = true);

                      try {
                        await ClientService.registrarCliente(
                          nombre: nombreController.text.trim(),
                          telefono: telefonoController.text.trim(),
                          direccion: direccionController.text.trim(),
                          correo: correoController.text.trim(),
                        );

                        // Comprobar por separado que la pantalla y el diálogo
                        // sigan activos después de la operación asíncrona.
                        if (!mounted || !dialogContext.mounted) return;

                        Navigator.pop(dialogContext);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Clienta agregada correctamente'),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;

                        actualizarDialogo(() => guardando = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('No se pudo guardar: $error')),
                        );
                      }
                    },
              child: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nombreController.dispose();
      telefonoController.dispose();
      direccionController.dispose();
      correoController.dispose();
    });
  }

  void _resumenCliente(Map<String, dynamic> cliente) {
    final clienteId = (cliente['id'] ?? '').toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: ClientService.compras(clienteId),
                builder: (context, comprasSnapshot) {
                  final compras = comprasSnapshot.data ?? [];
                  final totalComprado = ClientService.calcularTotalComprado(
                    compras,
                  );

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ClientService.pagos(clienteId),
                    builder: (context, pagosSnapshot) {
                      final pagos = pagosSnapshot.data ?? [];
                      final totalPagado = ClientService.calcularTotalPagado(
                        pagos,
                      );
                      final deuda = ClientService.calcularSaldo(
                        totalComprado: totalComprado,
                        totalPagado: totalPagado,
                      );

                      final nombre = (cliente['nombre'] ?? 'Sin nombre')
                          .toString();
                      final telefono = (cliente['telefono'] ?? '').toString();
                      final direccion = (cliente['direccion'] ?? '').toString();

                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDD6E3),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: const Color(0xFFFFEEF6),
                                child: Text(
                                  _iniciales(nombre),
                                  style: const TextStyle(
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
                                    const Text(
                                      'RESUMEN DE CLIENTA',
                                      style: TextStyle(
                                        color: AppTheme.violet,
                                        fontSize: 10,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      nombre,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.dark,
                                      ),
                                    ),
                                    Text(
                                      telefono,
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.home_outlined,
                                size: 17,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  direccion.isEmpty
                                      ? 'Dirección no registrada'
                                      : direccion,
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          if (comprasSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !comprasSnapshot.hasData)
                            const Center(child: CircularProgressIndicator())
                          else if (compras.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: Text(
                                  'Todavía no tiene prendas registradas',
                                ),
                              ),
                            )
                          else
                            ...compras.map((compra) {
                              final cantidad = ClientService.numero(
                                compra['cantidad'],
                              ).toInt();
                              final precio = ClientService.numero(
                                compra['precioUnitario'],
                              );
                              final subtotal = compra['subtotal'] is num
                                  ? ClientService.numero(compra['subtotal'])
                                  : precio * cantidad;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        (compra['prendaNombre'] ?? 'Prenda')
                                            .toString(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        '$cantidad × '
                                        '\$${precio.toStringAsFixed(2)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '\$${subtotal.toStringAsFixed(2)}',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 28),
                          _filaTotal('Total comprado', totalComprado),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Pagado',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                '\$${totalPagado.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0E9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Saldo pendiente',
                                    style: TextStyle(
                                      color: Color(0xFFD65C3B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '\$${deuda.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFFD65C3B),
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _agregarPrenda(cliente);
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar prenda'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.violet,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _registrarPago(cliente);
                                  },
                                  icon: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  label: const Text('Registrar pago'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.violet,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _verHistorial(cliente);
                            },
                            icon: const Icon(Icons.history),
                            label: const Text('Ver historial'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _filaTotal(String titulo, double monto) {
    return Row(
      children: [
        Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12))),
        Text(
          '\$${monto.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _agregarPrenda(Map<String, dynamic> cliente) {
    final disponibles = prendasDemo.where((p) => p.activa).toList();

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay prendas activas en el catálogo')),
      );
      return;
    }

    PrendaDemo seleccionada = disponibles.first;
    final cantidadController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizarDialogo) => AlertDialog(
          title: const Text('Agregar prenda'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PrendaDemo>(
                  value: seleccionada,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Prenda'),
                  items: disponibles.map((prenda) {
                    return DropdownMenuItem(
                      value: prenda,
                      child: Text(
                        '${prenda.nombre} — '
                        '\$${prenda.precio.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (prenda) {
                    if (prenda != null) {
                      actualizarDialogo(() => seleccionada = prenda);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (value) {
                    final cantidad = int.tryParse(value ?? '');
                    if (cantidad == null || cantidad < 1) {
                      return 'Ingresa una cantidad válida';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      final clienteId = (cliente['id'] ?? '').toString();
                      if (clienteId.isEmpty) {
                        _mensaje('No se encontró el identificador del cliente');
                        return;
                      }

                      actualizarDialogo(() => guardando = true);

                      try {
                        await ClientService.registrarCompra(
                          clienteId: clienteId,
                          prendaNombre: seleccionada.nombre,
                          precioUnitario: seleccionada.precio,
                          cantidad: int.parse(cantidadController.text),
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _mensaje('Prenda agregada correctamente');
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        actualizarDialogo(() => guardando = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'No se pudo registrar la compra: $error',
                            ),
                          ),
                        );
                      }
                    },
              child: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Agregar'),
            ),
          ],
        ),
      ),
    ).whenComplete(cantidadController.dispose);
  }

  void _registrarPago(Map<String, dynamic> cliente) {
    final clienteId = (cliente['id'] ?? '').toString();

    if (clienteId.isEmpty) {
      _mensaje('No se encontró el identificador del cliente');
      return;
    }

    final montoController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: ClientService.compras(clienteId),
          builder: (context, comprasSnapshot) {
            final totalComprado = ClientService.calcularTotalComprado(
              comprasSnapshot.data ?? [],
            );

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: ClientService.pagos(clienteId),
              builder: (context, pagosSnapshot) {
                final totalPagado = ClientService.calcularTotalPagado(
                  pagosSnapshot.data ?? [],
                );
                final deuda = ClientService.calcularSaldo(
                  totalComprado: totalComprado,
                  totalPagado: totalPagado,
                );

                return StatefulBuilder(
                  builder: (context, actualizarDialogo) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(26),
                          ),
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'REGISTRAR PAGO',
                                style: TextStyle(
                                  color: AppTheme.violet,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pago de ${cliente['nombre'] ?? 'cliente'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.dark,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0E9),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Saldo pendiente',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFD65C3B),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${deuda.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD65C3B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Monto del pago',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: montoController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  prefixText: '\$ ',
                                  hintText: '0.00',
                                ),
                                validator: (value) {
                                  final monto = double.tryParse(
                                    (value ?? '').replaceAll(',', '.'),
                                  );
                                  if (monto == null || monto <= 0) {
                                    return 'Ingresa un monto válido';
                                  }
                                  if (monto > deuda + 0.001) {
                                    return 'El pago supera el saldo pendiente';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final monto in [
                                    10.0,
                                    20.0,
                                    deuda,
                                  ].where((m) => m > 0).toSet())
                                    OutlinedButton(
                                      onPressed: () {
                                        actualizarDialogo(() {
                                          montoController.text = monto
                                              .toStringAsFixed(2);
                                        });
                                      },
                                      child: Text(
                                        monto == deuda
                                            ? 'Saldo total'
                                            : '\$${monto.toStringAsFixed(0)}',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: guardando
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!
                                              .validate()) {
                                            return;
                                          }

                                          final monto = double.parse(
                                            montoController.text.replaceAll(
                                              ',',
                                              '.',
                                            ),
                                          );

                                          actualizarDialogo(
                                            () => guardando = true,
                                          );

                                          try {
                                            await ClientService.registrarPago(
                                              clienteId: clienteId,
                                              monto: monto,
                                            );

                                            if (!sheetContext.mounted) return;

                                            Navigator.pop(sheetContext);
                                            _mensaje(
                                              'Pago registrado correctamente',
                                            );
                                          } catch (error) {
                                            if (!sheetContext.mounted) return;

                                            actualizarDialogo(
                                              () => guardando = false,
                                            );
                                            ScaffoldMessenger.of(
                                              sheetContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'No se pudo registrar el pago: $error',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.check),
                                  label: guardando
                                      ? const Text('Guardando...')
                                      : const Text('Confirmar pago'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.violet,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    ).whenComplete(montoController.dispose);
  }

  void _verHistorial(Map<String, dynamic> cliente) {
    final clienteId = (cliente['id'] ?? '').toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ClientService.compras(clienteId),
            builder: (context, comprasSnapshot) {
              final compras = comprasSnapshot.data ?? [];

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: ClientService.pagos(clienteId),
                builder: (context, pagosSnapshot) {
                  final pagos = pagosSnapshot.data ?? [];

                  return ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        'Historial de ${cliente['nombre'] ?? 'cliente'}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Compras',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (comprasSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !comprasSnapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (compras.isEmpty)
                        const ListTile(title: Text('Sin compras registradas'))
                      else
                        ...compras.map((compra) {
                          final cantidad = ClientService.numero(
                            compra['cantidad'],
                          ).toInt();
                          final fecha = ClientService.fecha(compra['fecha']);
                          final subtotal = compra['subtotal'] is num
                              ? ClientService.numero(compra['subtotal'])
                              : ClientService.numero(compra['precioUnitario']) *
                                    cantidad;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              (compra['prendaNombre'] ?? 'Prenda').toString(),
                            ),
                            subtitle: Text(
                              '$cantidad unidades · '
                              '${fecha.day}/${fecha.month}/${fecha.year}',
                            ),
                            trailing: Text('\$${subtotal.toStringAsFixed(2)}'),
                          );
                        }),
                      const Divider(),
                      const Text(
                        'Pagos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (pagosSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !pagosSnapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (pagos.isEmpty)
                        const ListTile(title: Text('Sin pagos registrados'))
                      else
                        ...pagos.map((pago) {
                          final fecha = ClientService.fecha(pago['fecha']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              (pago['observacion'] ?? '').toString().isEmpty
                                  ? 'Abono recibido'
                                  : pago['observacion'].toString(),
                            ),
                            subtitle: Text(
                              '${fecha.day}/${fecha.month}/${fecha.year}',
                            ),
                            trailing: Text(
                              '\$${ClientService.numero(pago['monto']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    return partes.take(2).map((p) => p[0]).join().toUpperCase();
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }
}
