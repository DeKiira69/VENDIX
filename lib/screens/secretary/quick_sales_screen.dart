import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/prenda_model.dart';
import '../../theme/app_theme.dart';

class QuickSalesScreen extends StatefulWidget {
  final VoidCallback? onVolver;

  const QuickSalesScreen({super.key, this.onVolver});

  @override
  State<QuickSalesScreen> createState() => _QuickSalesScreenState();
}

class _QuickSalesScreenState extends State<QuickSalesScreen> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _buscadorController = TextEditingController();

  String? _clienteSeleccionadoId;
  String _clienteSeleccionadoNombre = '';

  // client doc ID -> { PrendaModel: cantidad }
  final Map<String, Map<PrendaModel, int>> _pedidosPendientes = {};

  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _buscadorController.addListener(() {
      setState(() {
        _busqueda = _buscadorController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  Map<PrendaModel, int> get _pedidoActual {
    final cId = _clienteSeleccionadoId;
    if (cId == null) return {};
    return _pedidosPendientes.putIfAbsent(cId, () => {});
  }

  final Map<String, String> _nombresClientesCache = {};

  double _totalPendiente(String clienteId) {
    final pedido = _pedidosPendientes[clienteId];
    if (pedido == null) return 0;
    return pedido.entries.fold<double>(
      0,
      (total, entrada) => total + entrada.key.precio * entrada.value,
    );
  }

  int _cantidadPendiente(String clienteId) {
    final pedido = _pedidosPendientes[clienteId];
    if (pedido == null) return 0;
    return pedido.values.fold<int>(0, (total, cantidad) => total + cantidad);
  }

  int get _totalClientesConPedidos {
    return _pedidosPendientes.entries
        .where((e) => e.value.values.fold<int>(0, (s, c) => s + c) > 0)
        .length;
  }

  int get _totalPrendasPendientesGlobal {
    int total = 0;
    for (final pedido in _pedidosPendientes.values) {
      total += pedido.values.fold<int>(0, (s, c) => s + c);
    }
    return total;
  }

  double get _totalDineroPendienteGlobal {
    double total = 0;
    for (final pedido in _pedidosPendientes.values) {
      for (final entrada in pedido.entries) {
        total += entrada.key.precio * entrada.value;
      }
    }
    return total;
  }

  bool get _hayPedidosPendientes => _totalPrendasPendientesGlobal > 0;

  void _agregarPrenda(PrendaModel prenda) {
    if (_clienteSeleccionadoId == null) {
      _mostrarMensaje('Selecciona una clienta primero.');
      return;
    }

    setState(() {
      final pedido = _pedidoActual;
      final existente = pedido.keys.where((p) => p.id == prenda.id).firstOrNull;
      if (existente != null) {
        pedido[existente] = (pedido[existente] ?? 0) + 1;
      } else {
        pedido[prenda] = 1;
      }
    });
  }

  void _quitarPrenda(PrendaModel prenda, [String? targetClienteId]) {
    final cId = targetClienteId ?? _clienteSeleccionadoId;
    if (cId == null) return;

    setState(() {
      final pedido = _pedidosPendientes[cId];
      if (pedido == null) return;

      final existente = pedido.keys.where((p) => p.id == prenda.id).firstOrNull;
      if (existente == null) return;

      final cantidad = pedido[existente] ?? 0;
      if (cantidad <= 1) {
        pedido.remove(existente);
        if (pedido.isEmpty) {
          _pedidosPendientes.remove(cId);
        }
      } else {
        pedido[existente] = cantidad - 1;
      }
    });
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }


  Future<void> _verResumenCliente(String cId, String nombreCliente) async {
    final pedido = Map<PrendaModel, int>.from(_pedidosPendientes[cId] ?? {});
    if (pedido.isEmpty) {
      _mostrarMensaje('Toca una prenda para agregarla al pedido de $nombreCliente.');
      return;
    }

    final total = pedido.entries.fold<double>(
      0,
      (suma, entrada) => suma + entrada.key.precio * entrada.value,
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Pedido de $nombreCliente'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...pedido.entries.map((entrada) {
                  final prenda = entrada.key;
                  final cantidad = entrada.value;
                  final subtotal = prenda.precio * cantidad;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text('${prenda.nombre} x$cantidad')),
                        Text(
                          '\$${subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total de la venta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.violet,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Registrar venta'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    final batch = _db.batch();
    final comprasRef = _db.collection('compras');

    for (final entrada in pedido.entries) {
      final docRef = comprasRef.doc();
      final subtotal = entrada.key.precio * entrada.value;

      batch.set(docRef, {
        'clienteId': cId,
        'clienteNombre': nombreCliente,
        'prenda': entrada.key.nombre,
        'prendaNombre': entrada.key.nombre,
        'precio': entrada.key.precio,
        'cantidad': entrada.value,
        'total': subtotal,
        'subtotal': subtotal,
        'fecha': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (mounted) {
      setState(() {
        _pedidosPendientes.remove(cId);
      });
      _mostrarMensaje('Venta de $nombreCliente registrada correctamente.');
    }
  }

  Future<void> _registrarTodasLasVentas() async {
    final pedidosValidos = _pedidosPendientes.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (pedidosValidos.isEmpty) {
      _mostrarMensaje('No hay prendas agregadas para registrar.');
      return;
    }

    final totalPrendas = _totalPrendasPendientesGlobal;
    final totalDinero = _totalDineroPendienteGlobal;
    final totalClientes = pedidosValidos.length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppTheme.violet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen general del Live',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dark,
                      ),
                    ),
                    Text(
                      'Todas las clientas con pedidos',
                      style: TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...pedidosValidos.map((entradaCliente) {
                    final cId = entradaCliente.key;
                    final nombreCliente = _nombresClientesCache[cId] ?? 'Clienta';
                    final pedido = entradaCliente.value;
                    final subtotalCliente = pedido.entries.fold<double>(
                      0,
                      (total, e) => total + e.key.precio * e.value,
                    );
                    final prendasCliente = pedido.values.fold<int>(
                      0,
                      (s, c) => s + c,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF8FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                nombreCliente,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.dark,
                                ),
                              ),
                              Text(
                                '\$${subtotalCliente.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pedido.entries
                                .map(
                                  (e) =>
                                      '${e.key.nombre} x${e.value} (\$${(e.key.precio * e.value).toStringAsFixed(0)})',
                                )
                                .join(' Â· '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$prendasCliente ${prendasCliente == 1 ? 'prenda' : 'prendas'} agregadas',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E62D6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total a registrar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.dark,
                            ),
                          ),
                          Text(
                            '$totalPrendas prendas Â· $totalClientes clientas',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${totalDinero.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.violet,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir editando'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.violet,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.done_all, size: 16),
              label: Text(
                'Registrar todas (\$${totalDinero.toStringAsFixed(0)})',
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    final batch = _db.batch();
    final comprasRef = _db.collection('compras');

    for (final entradaCliente in pedidosValidos) {
      final cId = entradaCliente.key;
      final nombreCliente = _nombresClientesCache[cId] ?? 'Clienta';
      final pedido = entradaCliente.value;

      for (final entrada in pedido.entries) {
        final docRef = comprasRef.doc();
        final subtotal = entrada.key.precio * entrada.value;

        batch.set(docRef, {
          'clienteId': cId,
          'clienteNombre': nombreCliente,
          'prenda': entrada.key.nombre,
          'prendaNombre': entrada.key.nombre,
          'precio': entrada.key.precio,
          'cantidad': entrada.value,
          'total': subtotal,
          'subtotal': subtotal,
          'fecha': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();

    if (mounted) {
      setState(() {
        _pedidosPendientes.clear();
      });
      _mostrarMensaje(
        'âœ… Se registraron $totalPrendas prendas en $totalClientes clientas por \$${totalDinero.toStringAsFixed(2)}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: (widget.onVolver != null || Navigator.canPop(context))
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: InkWell(
                    onTap: () {
                      if (widget.onVolver != null) {
                        widget.onVolver!();
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REGISTRO RÁPIDO',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: AppTheme.violet,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Ventas del live',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 21,
                color: AppTheme.dark,
              ),
            ),
          ],
        ),
        actions: [
          if (_hayPedidosPendientes)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _registrarTodasLasVentas,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C4AB6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text(
                    'Guardar todo ($_totalPrendasPendientesGlobal)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('clientes').snapshots(),
        builder: (context, snapClientes) {
          final docsClientes = snapClientes.data?.docs ?? [];
          for (final doc in docsClientes) {
            final data = doc.data() as Map<String, dynamic>;
            _nombresClientesCache[doc.id] = data['nombre'] ?? 'Clienta';
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _db.collection('prendas').where('activa', isEqualTo: true).snapshots(),
            builder: (context, snapPrendas) {
              final prendasActivas = (snapPrendas.data?.docs ?? [])
                  .map((d) => PrendaModel.fromFirestore(d))
                  .toList();

              return StreamBuilder<QuerySnapshot>(
                stream: _db.collection('compras').snapshots(),
                builder: (context, snapCompras) {
                  final docsCompras = snapCompras.data?.docs ?? [];

                  // Total de prendas y compras históricas por cliente
                  final prendasHistoricas = <String, int>{};
                  final totalHistorico = <String, double>{};
                  for (final doc in docsCompras) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cId = data['clienteId']?.toString() ?? '';
                    final cant = (data['cantidad'] is num) ? (data['cantidad'] as num).toInt() : 1;
                    final sub = (data['total'] ?? data['subtotal'] ?? 0).toDouble();

                    prendasHistoricas[cId] = (prendasHistoricas[cId] ?? 0) + cant;
                    totalHistorico[cId] = (totalHistorico[cId] ?? 0) + sub;
                  }

                  // Autoseleccionar primer cliente si no hay seleccionado
                  if (_clienteSeleccionadoId == null && docsClientes.isNotEmpty) {
                    final primerDoc = docsClientes.first;
                    final data = primerDoc.data() as Map<String, dynamic>;
                    _clienteSeleccionadoId = primerDoc.id;
                    _clienteSeleccionadoNombre = data['nombre'] ?? '';
                  }

                  final cId = _clienteSeleccionadoId;
                  final totalActual = cId == null ? 0.0 : _totalPendiente(cId);
                  final cantidadActual = cId == null ? 0 : _cantidadPendiente(cId);

                  // Filtrar clientes
                  final clientasFiltradas = docsClientes.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                    final tel = (data['telefono'] ?? '').toString().toLowerCase();
                    return nombre.contains(_busqueda) || tel.contains(_busqueda);
                  }).toList();

                  return Column(
                    children: [
                      // Buscador de clientas
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: TextField(
                          controller: _buscadorController,
                          decoration: InputDecoration(
                            hintText: 'Buscar clienta por nombre o teléfono',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _busqueda.isNotEmpty
                                ? IconButton(
                                    onPressed: _buscadorController.clear,
                                    icon: const Icon(Icons.close),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.violet,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Botones de prendas
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: AppTheme.border)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _clienteSeleccionadoNombre.isEmpty
                                  ? 'Selecciona una clienta para comenzar'
                                  : 'Toca para sumar a '
                                        '${_clienteSeleccionadoNombre.split(' ').first}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                            ),
                            const SizedBox(height: 10),
                            if (prendasActivas.isEmpty)
                              const Text('No hay prendas activas en el catálogo.')
                            else
                              SizedBox(
                                height: 58,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: prendasActivas.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final prenda = prendasActivas[index];
                                    final pedido = _pedidoActual;
                                    final existente = pedido.keys
                                        .where((p) => p.id == prenda.id)
                                        .firstOrNull;
                                    final cantidad = existente != null ? (pedido[existente] ?? 0) : 0;

                                    return Material(
                                      color: const Color(0xFFF1EAFE),
                                      borderRadius: BorderRadius.circular(13),
                                      child: InkWell(
                                        onTap: () => _agregarPrenda(prenda),
                                        borderRadius: BorderRadius.circular(13),
                                        child: Container(
                                          constraints: const BoxConstraints(minWidth: 82),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(13),
                                            border: Border.all(
                                              color: const Color(0xFFDCCBFA),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                prenda.nombre.toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.violet,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '+\$${prenda.precio.toStringAsFixed(0)}'
                                                '${cantidad > 0 ? ' Â· $cantidad' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.violet,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Encabezados
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'CLIENTA',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Text(
                                'PEDIDO',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filas de clientas
                      Expanded(
                        child: clientasFiltradas.isEmpty
                            ? const Center(child: Text('No se encontraron clientas.'))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                                itemCount: clientasFiltradas.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final doc = clientasFiltradas[index];
                                  final id = doc.id;
                                  final data = doc.data() as Map<String, dynamic>;
                                  final nombre = data['nombre']?.toString() ?? 'Sin nombre';

                                  final seleccionado = id == _clienteSeleccionadoId;
                                  final pedido = _pedidosPendientes[id] ?? {};

                                  final prendasTotales = (prendasHistoricas[id] ?? 0) + _cantidadPendiente(id);
                                  final dineroTotal = (totalHistorico[id] ?? 0) + _totalPendiente(id);

                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _clienteSeleccionadoId = id;
                                          _clienteSeleccionadoNombre = nombre;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(15),
                                      child: Container(
                                        constraints: const BoxConstraints(minHeight: 80),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(
                                            color: seleccionado
                                                ? AppTheme.violet
                                                : AppTheme.border,
                                            width: seleccionado ? 1.4 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 12,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      seleccionado
                                                          ? Icons.radio_button_checked
                                                          : Icons.radio_button_unchecked,
                                                      color: seleccionado
                                                          ? AppTheme.violet
                                                          : AppTheme.muted,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 7),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            nombre,
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.dark,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            '$prendasTotales prendas',
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              color: AppTheme.muted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 76,
                                              color: AppTheme.border,
                                            ),
                                            Expanded(
                                              flex: 6,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 9,
                                                  vertical: 9,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            '\$${dineroTotal.toStringAsFixed(0)}',
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.violet,
                                                            ),
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: pedido.isNotEmpty
                                                              ? () => _verResumenCliente(
                                                                    id,
                                                                    nombre,
                                                                  )
                                                              : null,
                                                          borderRadius:
                                                              BorderRadius.circular(12),
                                                          child: const Padding(
                                                            padding: EdgeInsets.all(2),
                                                            child: Icon(
                                                              Icons.chevron_right,
                                                              size: 19,
                                                              color: AppTheme.violet,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (pedido.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        alignment: WrapAlignment.end,
                                                        spacing: 4,
                                                        runSpacing: 4,
                                                        children: pedido.entries.map((
                                                          entrada,
                                                        ) {
                                                          return Container(
                                                            padding: const EdgeInsets.only(
                                                              left: 5,
                                                              right: 2,
                                                              top: 3,
                                                              bottom: 3,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: const Color(
                                                                0xFFF1EEF5,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(6),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize.min,
                                                              children: [
                                                                ConstrainedBox(
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxWidth: 62,
                                                                      ),
                                                                  child: Text(
                                                                    '${entrada.key.nombre} ${entrada.value}',
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow
                                                                        .ellipsis,
                                                                    style: const TextStyle(
                                                                      fontSize: 8,
                                                                      color: AppTheme.dark,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 3),
                                                                InkWell(
                                                                  onTap: () =>
                                                                      _quitarPrenda(
                                                                        entrada.key,
                                                                        id,
                                                                      ),
                                                                  child: const Padding(
                                                                    padding: EdgeInsets.all(
                                                                      2,
                                                                    ),
                                                                    child: Icon(
                                                                      Icons.remove,
                                                                      size: 10,
                                                                      color:
                                                                          AppTheme.violet,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ] else
                                                      const SizedBox(height: 8),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Resumen inferior
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292330),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _totalClientesConPedidos > 1
                                          ? 'Total Live ($_totalClientesConPedidos clientas)'
                                          : (_clienteSeleccionadoNombre.isEmpty
                                              ? 'Selecciona una clienta'
                                              : 'Total de '
                                                  '${_clienteSeleccionadoNombre.split(' ').first}'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '\$${(_totalClientesConPedidos > 1 ? _totalDineroPendienteGlobal : totalActual).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_totalPrendasPendientesGlobal > 0)
                                      Text(
                                        _totalClientesConPedidos > 1
                                            ? '$_totalPrendasPendientesGlobal prendas nuevas en total'
                                            : '$cantidadActual prendas nuevas',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFE9A6C8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_totalClientesConPedidos > 1 && cantidadActual > 0 && cId != null) ...[
                                    IconButton(
                                      tooltip:
                                          'Ver pedido de ${_clienteSeleccionadoNombre.split(' ').first}',
                                      icon: const Icon(
                                        Icons.person_outline,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      onPressed: () => _verResumenCliente(
                                        cId,
                                        _clienteSeleccionadoNombre,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  FilledButton(
                                    onPressed: _hayPedidosPendientes
                                        ? _registrarTodasLasVentas
                                        : (_pedidoActual.isNotEmpty && cId != null
                                            ? () => _verResumenCliente(
                                                  cId,
                                                  _clienteSeleccionadoNombre,
                                                )
                                            : null),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF7546C2),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Colors.white12,
                                      disabledForegroundColor: Colors.white38,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _totalClientesConPedidos > 1
                                              ? Icons.done_all
                                              : Icons.check,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _totalClientesConPedidos > 1
                                              ? 'Registrar todo'
                                              : 'Registrar venta',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }
}