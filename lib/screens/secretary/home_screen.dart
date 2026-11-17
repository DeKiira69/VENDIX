import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/client_service.dart';
import '../../services/perfil_foto_service.dart';
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

    final usuario = FirebaseAuth.instance.currentUser;
    final usuarioId = usuario?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('usuarios').doc(usuarioId).snapshots(),
      builder: (context, snapUsuario) {
        final dataUsuario = snapUsuario.data?.data() ?? {};
        final nombreSecretario = (dataUsuario['nombre'] ??
                usuario?.displayName ??
                'Secretario')
            .toString()
            .trim();
        final inicial = nombreSecretario.isNotEmpty
            ? nombreSecretario[0].toUpperCase()
            : 'S';

        // Escuchar los empleos activos del secretario para identificar el negocio
        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('secretarios')
              .where('clienteId', isEqualTo: usuarioId)
              .where('aprobado', isEqualTo: true)
              .snapshots(),
          builder: (context, snapEmpleos) {
            final empleosDocs = snapEmpleos.data?.docs ?? [];

            String nombreEmprendimiento =
                ClientService.activeSecretaryNombreEmprendimiento ?? '';
            String adminNombre =
                ClientService.activeSecretaryAdminNombre ?? '';
            String adminId = ClientService.activeSecretaryAdminId ?? '';

            if (empleosDocs.isNotEmpty) {
              // Buscar el doc que coincida con adminId o usar el primero
              QueryDocumentSnapshot? docActivo;
              if (adminId.isNotEmpty) {
                docActivo = empleosDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['adminId'] == adminId;
                }).firstOrNull;
              }
              docActivo ??= empleosDocs.first;

              final dataActiva = docActivo.data() as Map<String, dynamic>;
              if (nombreEmprendimiento.isEmpty) {
                nombreEmprendimiento =
                    dataActiva['nombreEmprendimiento']?.toString() ??
                        'Emprendimiento';
              }
              if (adminNombre.isEmpty) {
                adminNombre = dataActiva['adminNombre']?.toString() ??
                    'Emprendedor Propietario';
              }
              if (adminId.isEmpty) {
                adminId = dataActiva['adminId']?.toString() ?? '';
              }

              // Sincronizar en memoria
              ClientService.setActiveSecretarySession(
                adminId: adminId,
                nombreEmprendimiento: nombreEmprendimiento,
                adminNombre: adminNombre,
              );
            }

            return Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                backgroundColor: AppTheme.background,
                elevation: 0,
                toolbarHeight: 68,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ROL: SECRETARIO · OPERADOR LIVE',
                      style: TextStyle(
                        color: AppTheme.violet,
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_saludo()}, $nombreSecretario',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dark,
                      ),
                    ),
                    Text(
                      nombreEmprendimiento.isNotEmpty
                          ? 'Tienda: $nombreEmprendimiento'
                          : 'Tu negocio está listo para vender.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: StreamBuilder<String?>(
                      stream: PerfilFotoService.fotoStream(usuarioId),
                      builder: (context, fotoSnap) {
                        final foto = fotoSnap.data;
                        if (foto != null && foto.isNotEmpty) {
                          return InkWell(
                            onTap: alAbrirMas,
                            borderRadius: BorderRadius.circular(21),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.violet,
                              backgroundImage: NetworkImage(foto),
                            ),
                          );
                        }
                        return InkWell(
                          onTap: alAbrirMas,
                          borderRadius: BorderRadius.circular(21),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.violet,
                            child: Text(
                              inicial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
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
                          final monto =
                              (d['total'] ?? d['subtotal'] ?? 0).toDouble();
                          final prendas = (d['cantidad'] ?? 0) as int;
                          totalVentas += monto;
                          prendasVendidas += prendas;

                          final ts = d['fecha'];
                          if (ts is Timestamp) {
                            final fecha = ts.toDate();
                            if (fecha.isAfter(inicioHoy) &&
                                fecha.isBefore(finHoy)) {
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
                            final totalPendiente = (totalVentas - totalCobrado)
                                .clamp(0.0, double.infinity);

                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tarjeta destacada con el Emprendimiento y Emprendedor
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppTheme.violet
                                            .withValues(alpha: 0.25),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0E9FC),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.storefront_rounded,
                                            color: AppTheme.violet,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'EMPRENDIMIENTO ASIGNADO',
                                                style: TextStyle(
                                                  color: AppTheme.violet,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                nombreEmprendimiento.isNotEmpty
                                                    ? nombreEmprendimiento
                                                    : 'Emprendimiento en Live',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.dark,
                                                ),
                                              ),
                                              Text(
                                                adminNombre.isNotEmpty
                                                    ? 'Propietario: $adminNombre'
                                                    : 'Propietario: Administrador',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (empleosDocs.length > 1)
                                          InkWell(
                                            onTap: () {
                                              _mostrarSelectorEmprendimientos(
                                                context,
                                                empleosDocs,
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0E9FC),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Cambiar',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppTheme.violet,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.keyboard_arrow_down,
                                                    size: 14,
                                                    color: AppTheme.violet,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
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
          },
        );
      },
    );
  }

  void _mostrarSelectorEmprendimientos(
    BuildContext context,
    List<QueryDocumentSnapshot> empleos,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cambiar Emprendimiento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona la tienda para la que deseas operar:',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              ...empleos.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final emp = data['nombreEmprendimiento']?.toString() ??
                    data['adminNombre']?.toString() ??
                    'Emprendimiento';
                final adminNom = data['adminNombre']?.toString() ?? '';
                final adminId = data['adminId']?.toString() ?? '';
                final esActivo =
                    adminId == ClientService.activeSecretaryAdminId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esActivo
                        ? AppTheme.violet
                        : const Color(0xFFF0E8FC),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: esActivo ? Colors.white : AppTheme.violet,
                    ),
                  ),
                  title: Text(
                    emp,
                    style: TextStyle(
                      fontWeight:
                          esActivo ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text('Propietario: $adminNom'),
                  trailing: esActivo
                      ? const Icon(Icons.check_circle, color: AppTheme.violet)
                      : null,
                  onTap: () {
                    ClientService.setActiveSecretarySession(
                      adminId: adminId,
                      nombreEmprendimiento: emp,
                      adminNombre: adminNom,
                    );
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cambiado a $emp'),
                        backgroundColor: AppTheme.violet,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
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
