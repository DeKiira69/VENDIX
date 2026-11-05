import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/prenda_model.dart';
import '../../data/prenda_service.dart';

class ClothingPricesScreen extends StatefulWidget {
  const ClothingPricesScreen({super.key});

  @override
  State<ClothingPricesScreen> createState() => _ClothingPricesScreenState();
}

class _ClothingPricesScreenState extends State<ClothingPricesScreen> {
  final PrendaService _prendaService = PrendaService();

  Future<void> _editarPrenda({PrendaModel? prenda, List<PrendaModel>? prendasActuales}) async {
    final nombreController = TextEditingController(text: prenda?.nombre ?? '');
    final precioController = TextEditingController(
      text: prenda != null ? prenda.precio.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(prenda == null ? 'Nueva prenda' : 'Editar prenda'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la prenda',
                  prefixIcon: Icon(Icons.checkroom_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Escribe el nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: precioController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  final precio = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  if (precio == null || precio <= 0) {
                    return 'Ingresa un precio mayor que cero';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final nombre = nombreController.text.trim();
                final precio = double.parse(
                  precioController.text.replaceAll(',', '.'),
                );

                if (prendasActuales != null) {
                  final duplicada = prendasActuales.any(
                    (p) =>
                        p.id != prenda?.id &&
                        p.nombre.toLowerCase() == nombre.toLowerCase(),
                  );

                  if (duplicada) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ya existe una prenda con ese nombre'),
                      ),
                    );
                    return;
                  }
                }

                try {
                  if (prenda == null) {
                    await _prendaService.agregarPrenda(
                      nombre: nombre,
                      precio: precio,
                    );
                  } else {
                    await _prendaService.actualizarPrenda(
                      id: prenda.id,
                      nombre: nombre,
                      precio: precio,
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error al guardar en Firebase: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    nombreController.dispose();
    precioController.dispose();

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prenda == null
                ? 'Prenda guardada en Firebase exitosamente'
                : 'Prenda actualizada en Firebase',
          ),
          backgroundColor: AppTheme.green,
        ),
      );
    }
  }

  Future<void> _cambiarEstado(PrendaModel prenda) async {
    final desactivar = prenda.activa;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(desactivar ? 'Desactivar prenda' : 'Activar prenda'),
        content: Text(
          desactivar
              ? '¿Deseas dejar de ofrecer "${prenda.nombre}"? '
                    'No aparecerá en las nuevas ventas.'
              : '¿Deseas volver a ofrecer "${prenda.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(desactivar ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _prendaService.toggleActiva(prenda.id, prenda.activa);
    }
  }

  Future<void> _eliminarPrenda(PrendaModel prenda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar prenda'),
        content: Text('¿Seguro que deseas eliminar "${prenda.nombre}" de la base de datos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _prendaService.eliminarPrenda(prenda.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenda eliminada de Firebase')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PrendaModel>>(
      stream: _prendaService.getPrendasStream(),
      builder: (context, snapshot) {
        final prendas = snapshot.data ?? [];
        final cargando = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final activas = prendas.where((p) => p.activa).length;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
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
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.violet),
                        ),
                      ),
                    ),
                  )
                : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'PRECIOS DE HOY',
                  style: TextStyle(
                    color: AppTheme.violet,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Prendas y precios',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.dark),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton.icon(
                  onPressed: () => _editarPrenda(prendasActuales: prendas),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.violet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nueva', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_outlined,
                      size: 30,
                      color: AppTheme.violet,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Catálogo en Tiempo Real (Firebase)',
                            style: TextStyle(
                              color: AppTheme.violet,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            cargando
                                ? 'Conectando con Firestore...'
                                : '$activas prendas disponibles para nuevas ventas',
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
              ),
              const SizedBox(height: 22),
              Text(
                'Todas las prendas (${prendas.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.dark,
                ),
              ),
              const SizedBox(height: 12),
              if (cargando)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (prendas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.muted),
                        const SizedBox(height: 12),
                        const Text(
                          'Aún no hay prendas en Firestore.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Presiona "Nueva prenda" para crear la primera.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...prendas.map((prenda) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: prenda.activa
                              ? const Color(0xFFF0E9FC)
                              : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.checkroom_outlined,
                          color: prenda.activa ? AppTheme.violet : AppTheme.muted,
                        ),
                      ),
                      title: Text(
                        prenda.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        prenda.activa ? 'Disponible' : 'Desactivada',
                        style: TextStyle(
                          fontSize: 11,
                          color: prenda.activa ? AppTheme.green : AppTheme.muted,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opciones',
                        onSelected: (opcion) {
                          if (opcion == 'editar') {
                            _editarPrenda(prenda: prenda, prendasActuales: prendas);
                          } else if (opcion == 'estado') {
                            _cambiarEstado(prenda);
                          } else if (opcion == 'eliminar') {
                            _eliminarPrenda(prenda);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'estado',
                            child: Row(
                              children: [
                                Icon(
                                  prenda.activa
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                const SizedBox(width: 8),
                                Text(prenda.activa ? 'Desactivar' : 'Activar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'eliminar',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${prenda.precio.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: prenda.activa
                                    ? AppTheme.violet
                                    : AppTheme.muted,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.more_horiz, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Text(
                'Sincronizado en tiempo real con Cloud Firestore.',
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
