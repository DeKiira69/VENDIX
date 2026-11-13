import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/prenda_model.dart';
import '../../theme/app_theme.dart';

class _ClienteData {
  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final int prendas;
  final double totalComprado;
  final double totalPagado;
  final double deuda;
  final List<Map<String, dynamic>> compras;
  final List<Map<String, dynamic>> pagos;

  _ClienteData({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.prendas,
    required this.totalComprado,
    required this.totalPagado,
    required this.deuda,
    required this.compras,
    required this.pagos,
  });
}

class ClientsScreen extends StatefulWidget {
  final VoidCallback? onVolver;

  const ClientsScreen({super.key, this.onVolver});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 1;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 1;
    return 1;
  }
  final _db = FirebaseFirestore.instance;
  final _buscarController = TextEditingController();
  String _filtro = 'Todas';

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('clientes').snapshots(),
          builder: (context, snapClientes) {
            final docsClientes = snapClientes.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: _db.collection('compras').snapshots(),
              builder: (context, snapCompras) {
                final docsCompras = snapCompras.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('pagos').snapshots(),
                  builder: (context, snapPagos) {
                    final docsPagos = snapPagos.data?.docs ?? [];

                    // Organizar compras por clienteId
                    final mapCompras = <String, List<Map<String, dynamic>>>{};
                    for (final doc in docsCompras) {
                      final data = doc.data() as Map<String, dynamic>;
                      final cId = data['clienteId']?.toString() ?? '';
                      if (cId.isNotEmpty) {
                        mapCompras.putIfAbsent(cId, () => []).add({
                          'id': doc.id,
                          ...data,
                        });
                      }
                    }

                    // Organizar pagos por clienteId
                    final mapPagos = <String, List<Map<String, dynamic>>>{};
                    for (final doc in docsPagos) {
                      final data = doc.data() as Map<String, dynamic>;
                      final cId = data['clienteId']?.toString() ?? '';
                      if (cId.isNotEmpty) {
                        mapPagos.putIfAbsent(cId, () => []).add({
                          'id': doc.id,
                          ...data,
                        });
                      }
                    }

                    // Mapear a _ClienteData
                    final listaClientes = docsClientes.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final nombre = data['nombre']?.toString() ?? 'Sin nombre';
                      final telefono = data['telefono']?.toString() ?? '';
                      final direccion = data['direccion']?.toString() ?? '';

                      final compras = mapCompras[id] ?? [];
                      final pagos = mapPagos[id] ?? [];

                      int totalPrendas = 0;
                      double totalComprado = 0;
                      for (final c in compras) {
                        final cant = _toInt(c['cantidad']);
                        final sub = _toDouble(c['total'] ?? c['subtotal']);
                        totalPrendas += cant;
                        totalComprado += sub;
                      }

                      double totalPagado = 0;
                      for (final p in pagos) {
                        totalPagado += _toDouble(p['monto']);
                      }

                      final saldo = totalComprado - totalPagado;
                      final deuda = saldo > 0.001 ? saldo : 0.0;

                      return _ClienteData(
                        id: id,
                        nombre: nombre,
                        telefono: telefono,
                        direccion: direccion,
                        prendas: totalPrendas,
                        totalComprado: totalComprado,
                        totalPagado: totalPagado,
                        deuda: deuda,
                        compras: compras,
                        pagos: pagos,
                      );
                    }).toList();

                    // Filtrar por texto y por saldo
                    final busqueda = _buscarController.text.trim().toLowerCase();
                    final filtrados = listaClientes.where((c) {
                      final coincide = c.nombre.toLowerCase().contains(busqueda) ||
                          c.telefono.toLowerCase().contains(busqueda) ||
                          c.direccion.toLowerCase().contains(busqueda);

                      final coincideFiltro = _filtro == 'Todas' ||
                          (_filtro == 'Con saldo' && c.deuda > 0) ||
                          (_filtro == 'Al día' && c.deuda == 0);

                      return coincide && coincideFiltro;
                    }).toList();

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
                          child: Row(
                            children: [
                              if (widget.onVolver != null || Navigator.canPop(context)) ...[
                                InkWell(
                                  onTap: () {
                                    if (widget.onVolver != null) {
                                      widget.onVolver!();
                                    } else if (Navigator.canPop(context)) {
                                      Navigator.maybePop(context);
                                    }
                                  },
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
                                      '${listaClientes.length} REGISTRADAS',
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
                                        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
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
                                            iniciales.isEmpty ? 'C' : iniciales,
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
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ingresa el teléfono' : null,
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
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ingresa la dirección' : null,
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
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final nombre = nombreController.text.trim();
              final telefono = telefonoController.text.trim();
              final direccion = direccionController.text.trim();

              Navigator.pop(dialogContext);

              await _db.collection('clientes').add({
                'nombre': nombre,
                'telefono': telefono,
                'direccion': direccion,
                'fecha': FieldValue.serverTimestamp(),
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

  void _resumenCliente(_ClienteData cliente) {
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
            final iniciales = cliente.nombre
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                .join();

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
                          iniciales.isEmpty ? 'C' : iniciales,
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
                      (compra) {
                        final nombrePrenda = compra['prendaNombre'] ?? compra['prenda'] ?? 'Prenda';
                        final cant = _toInt(compra['cantidad']);
                        final precioUnitario = _toDouble(compra['precio'] ?? compra['precioUnitario']);
                        final subtotal = _toDouble(compra['total'] ?? compra['subtotal'] ?? (precioUnitario * cant));

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  nombrePrenda,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  '$cant × \$${precioUnitario.toStringAsFixed(2)}',
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
                      },
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
                          icon: const Icon(Icons.account_balance_wallet_outlined),
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

  Future<void> _agregarPrenda(_ClienteData cliente) async {
    // Obtener prendas activas de Firestore
    final snapPrendas = await _db.collection('prendas').where('activa', isEqualTo: true).get();
    if (!mounted) return;

    final disponibles = snapPrendas.docs.map((d) => PrendaModel.fromFirestore(d)).toList();

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay prendas activas en el catálogo')),
      );
      return;
    }

    PrendaModel seleccionada = disponibles.first;
    final cantidadController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (alertContext, actualizarDialogo) => AlertDialog(
          title: const Text('Agregar prenda'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PrendaModel>(
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final cantidad = int.parse(cantidadController.text);
                final total = seleccionada.precio * cantidad;

                Navigator.pop(dialogContext);

                await _db.collection('compras').add({
                  'clienteId': cliente.id,
                  'clienteNombre': cliente.nombre,
                  'prenda': seleccionada.nombre,
                  'prendaNombre': seleccionada.nombre,
                  'precio': seleccionada.precio,
                  'cantidad': cantidad,
                  'total': total,
                  'subtotal': total,
                  'fecha': FieldValue.serverTimestamp(),
                });

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

  void _registrarPago(_ClienteData cliente) {
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
          builder: (modalContext, actualizarDialogo) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
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
                                  montoController.text = monto.toStringAsFixed(2);
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
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final monto = double.parse(
                              montoController.text.replaceAll(',', '.'),
                            );

                            Navigator.pop(sheetContext);

                            await _db.collection('pagos').add({
                              'clienteId': cliente.id,
                              'clienteNombre': cliente.nombre,
                              'monto': monto,
                              'observacion': 'Abono desde clientas',
                              'fecha': FieldValue.serverTimestamp(),
                            });

                            final nuevoSaldo = (cliente.deuda - monto).clamp(0.0, double.infinity);
                            try {
                              await _db.collection('clientes').doc(cliente.id).set({
                                'saldo': nuevoSaldo,
                                'ultimoPago': monto,
                                'fechaUltimoPago': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            } catch (_) {}

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pago registrado correctamente'),
                                ),
                              );
                            }
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

  void _verHistorial(_ClienteData cliente) {
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
                  (compra) {
                    final nombrePrenda = compra['prendaNombre'] ?? compra['prenda'] ?? 'Prenda';
                    final cant = _toInt(compra['cantidad']);
                    final subtotal = _toDouble(compra['total'] ?? compra['subtotal']);
                    final ts = compra['fecha'];
                    String fechaStr = 'Reciente';
                    if (ts is Timestamp) {
                      final f = ts.toDate();
                      fechaStr = '${f.day}/${f.month}/${f.year}';
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(nombrePrenda),
                      subtitle: Text('$cant unidades · $fechaStr'),
                      trailing: Text('\$${subtotal.toStringAsFixed(2)}'),
                    );
                  },
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
                  (pago) {
                    final monto = _toDouble(pago['monto']);
                    final ts = pago['fecha'];
                    String fechaStr = 'Reciente';
                    if (ts is Timestamp) {
                      final f = ts.toDate();
                      fechaStr = '${f.day}/${f.month}/${f.year}';
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Abono recibido'),
                      subtitle: Text(fechaStr),
                      trailing: Text(
                        '\$${monto.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
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
