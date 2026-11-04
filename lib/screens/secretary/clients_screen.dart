import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../data/datos_prueba.dart';

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
    final busqueda = _buscarController.text.toLowerCase();

    final filtrados = clientesDemo.where((c) {
      final coincide =
          c.nombre.toLowerCase().contains(busqueda) ||
          c.telefono.toLowerCase().contains(busqueda) ||
          c.direccion.toLowerCase().contains(busqueda);

      final coincideFiltro =
          _filtro == 'Todas' ||
          (_filtro == 'Con saldo' && c.deuda > 0) ||
          (_filtro == 'Al día' && c.deuda == 0);

      return coincide && coincideFiltro;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
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
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${clientesDemo.length} REGISTRADAS',
                        style: const TextStyle(
                          color: AppTheme.violet,
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                        ),
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
            child: filtrados.isEmpty
                ? const Center(child: Text('No se encontraron clientes'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final cliente = filtrados[index];
                      final iniciales = cliente.nombre
                          .trim()
                          .split(RegExp(r'\s+'))
                          .take(2)
                          .map((p) => p[0])
                          .join();

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
                            cliente.nombre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${cliente.telefono}\n'
                            '${cliente.prendas} prendas registradas',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
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
                                    cliente.deuda <= 0 ? 'AL DÍA' : 'DEBE',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                  Text(
                                    '\$${cliente.deuda.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: cliente.deuda <= 0
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
                  ),
          ),
        ],
      ),
    ),
    );
  }

  void _nuevoCliente() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final direccionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                  controller: direccionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de casa',
                    hintText: 'Barrio, calle, número o referencia',
                    prefixIcon: Icon(Icons.home_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa la dirección'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              final nuevo = ClienteDemo(
                nombre: nombreController.text.trim(),
                telefono: telefonoController.text.trim(),
                direccion: direccionController.text.trim(),
              );

              Navigator.pop(dialogContext);

              setState(() {
                clientesDemo.add(nuevo);
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clienta agregada correctamente')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) {
      nombreController.dispose();
      telefonoController.dispose();
      direccionController.dispose();
    });
  }

  void _resumenCliente(ClienteDemo cliente) {
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
              child: ListView(
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
                          cliente.nombre
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((p) => p[0])
                              .join(),
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
                              cliente.nombre,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.dark,
                              ),
                            ),
                            Text(
                              cliente.telefono,
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
                          cliente.direccion.isEmpty
                              ? 'Dirección no registrada'
                              : cliente.direccion,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  if (cliente.compras.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text('Todavía no tiene prendas registradas'),
                      ),
                    )
                  else
                    ...cliente.compras.map(
                      (compra) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                compra.prendaNombre,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                '${compra.cantidad} × '
                                '\$${compra.precioUnitario.toStringAsFixed(2)}',
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
                                '\$${compra.subtotal.toStringAsFixed(2)}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 28),
                  _filaTotal('Total comprado', cliente.totalComprado),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Pagado', style: TextStyle(fontSize: 12)),
                      ),
                      Text(
                        '\$${cliente.totalPagado.toStringAsFixed(2)}',
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
                          '\$${cliente.deuda.toStringAsFixed(2)}',
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() {});
    });
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

  void _agregarPrenda(ClienteDemo cliente) {
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
                  initialValue: seleccionada,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Prenda'),
                  items: disponibles.map((prenda) {
                    return DropdownMenuItem(
                      value: prenda,
                      child: Text(
                        '${prenda.nombre} — \$${prenda.precio.toStringAsFixed(2)}',
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final cantidad = int.parse(cantidadController.text);
                Navigator.pop(dialogContext);
                setState(() => cliente.agregarCompra(seleccionada, cantidad));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prenda agregada correctamente'),
                    ),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    ).then((_) => cantidadController.dispose());
  }

  void _registrarPago(ClienteDemo cliente) {
    if (cliente.deuda <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta clienta no tiene saldo pendiente')),
      );
      return;
    }

    final montoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                        'Pago de ${cliente.nombre}',
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
                              '\$${cliente.deuda.toStringAsFixed(2)}',
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
                        autofocus: false,
                        keyboardType: const TextInputType.numberWithOptions(
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
                          if (monto > cliente.deuda + 0.001) {
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
                          for (final monto in [10.0, 20.0, cliente.deuda])
                            OutlinedButton(
                              onPressed: () {
                                actualizarDialogo(() {
                                  montoController.text = monto.toStringAsFixed(
                                    2,
                                  );
                                });
                              },
                              child: Text(
                                monto == cliente.deuda
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
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            final monto = double.parse(
                              montoController.text.replaceAll(',', '.'),
                            );
                            final registrado = cliente.registrarPago(monto);
                            if (!registrado) return;

                            Navigator.pop(sheetContext);
                            setState(() {});
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Pago registrado correctamente'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar pago'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.violet,
                            padding: const EdgeInsets.symmetric(vertical: 15),
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
    ).whenComplete(montoController.dispose);
  }

  void _verHistorial(ClienteDemo cliente) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial de ${cliente.nombre}',
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
              if (cliente.compras.isEmpty)
                const ListTile(title: Text('Sin compras registradas'))
              else
                ...cliente.compras.map(
                  (compra) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(compra.prendaNombre),
                    subtitle: Text(
                      '${compra.cantidad} unidades · '
                      '${compra.fecha.day}/${compra.fecha.month}/${compra.fecha.year}',
                    ),
                    trailing: Text('\$${compra.subtotal.toStringAsFixed(2)}'),
                  ),
                ),
              const Divider(),
              const Text(
                'Pagos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (cliente.pagos.isEmpty)
                const ListTile(title: Text('Sin pagos registrados'))
              else
                ...cliente.pagos.map(
                  (pago) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Abono recibido'),
                    subtitle: Text(
                      '${pago.fecha.day}/${pago.fecha.month}/${pago.fecha.year}',
                    ),
                    trailing: Text(
                      '\$${pago.monto.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
