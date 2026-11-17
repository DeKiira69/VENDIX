import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/client_service.dart';
import '../../services/perfil_foto_service.dart';
import '../../widgets/store_location_map.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  static const Color violeta = Color(0xFF7950C2);
  static const Color oscuro = Color(0xFF241B35);
  static const Color rosa = Color(0xFFE9A6C8);

  void _mostrarMapaTienda(
    BuildContext context, {
    required String nombre,
    required String direccion,
    required double? latitud,
    required double? longitud,
  }) {
    if (latitud == null || longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El emprendedor aún no ha guardado la ubicación de su tienda.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              nombre.isEmpty ? 'Ubicación de la tienda' : nombre,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: oscuro,
              ),
            ),
            if (direccion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(direccion, style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: StoreLocationPreview(
                latitude: latitud,
                longitude: longitud,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: ClientService.clienteActual(),
        builder: (context, clienteSnapshot) {
          if (clienteSnapshot.hasError) {
            return const Center(child: Text('No se pudo cargar tu perfil.'));
          }

          // Si el stream aún está conectando, mostramos la estructura visual de inmediato
          // utilizando los datos locales de autenticación para no mostrar una pantalla en blanco.
          if (!clienteSnapshot.hasData) {
            final authUser = FirebaseAuth.instance.currentUser;
            final nombreAuth = authUser?.displayName ?? '';
            final nombresAuth = nombreAuth.trim().split(RegExp(r'\s+'));
            final saludoAuth =
                nombresAuth.isNotEmpty && nombresAuth.first.isNotEmpty
                ? nombresAuth.first
                : 'Cliente';

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUÉ GUSTO VERTE',
                            style: TextStyle(
                              color: violeta,
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hola, $saludoAuth',
                            style: const TextStyle(
                              color: oscuro,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: rosa,
                      child: Text(
                        saludoAuth.isNotEmpty
                            ? saludoAuth[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6440AB), Color(0xFF9A69C6), rosa],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu saldo pendiente',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Cargando tu cuenta...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final cliente = clienteSnapshot.data;
          if (cliente == null) {
            return const _SinFicha();
          }

          final clienteId = cliente['id'] as String;
          final adminId = cliente['adminId']?.toString() ?? '';
          final nombre = (cliente['nombre'] ?? 'Cliente').toString();
          final nombres = nombre.trim().split(RegExp(r'\s+'));
          final saludo = nombres.isNotEmpty ? nombres.first : 'Cliente';

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: ClientService.compras(clienteId),
            builder: (context, comprasSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: ClientService.pagos(clienteId),
                builder: (context, pagosSnapshot) {
                  if (comprasSnapshot.hasError || pagosSnapshot.hasError) {
                    return const Center(
                      child: Text('No se pudo cargar tu estado de cuenta.'),
                    );
                  }

                  // En lugar de bloquear la pantalla completa con un spinner,
                  // mostramos la UI de inmediato con valores calculados o en carga.
                  final cargandoFinanzas =
                      !comprasSnapshot.hasData || !pagosSnapshot.hasData;

                  final compras = comprasSnapshot.data ?? [];
                  final pagos = pagosSnapshot.data ?? [];

                  final totalComprado = compras.fold<double>(
                    0,
                    (suma, compra) => suma + _subtotal(compra),
                  );

                  final totalPagado = pagos.fold<double>(
                    0,
                    (suma, pago) => suma + ClientService.numero(pago['monto']),
                  );

                  final saldo = (totalComprado - totalPagado)
                      .clamp(0.0, double.infinity)
                      .toDouble();

                  final prendas = compras.fold<int>(
                    0,
                    (suma, compra) =>
                        suma + ClientService.numero(compra['cantidad']).toInt(),
                  );

                  final ultimaCompra = compras.isEmpty ? null : compras.first;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'QUÉ GUSTO VERTE',
                                  style: TextStyle(
                                    color: violeta,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hola, $saludo',
                                  style: const TextStyle(
                                    color: oscuro,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<String?>(
                            stream: PerfilFotoService.fotoStream(
                              FirebaseAuth.instance.currentUser?.uid,
                            ),
                            builder: (context, fotoSnapshot) {
                              final fotoData =
                                  fotoSnapshot.data ??
                                  cliente['fotoBase64']?.toString() ??
                                  cliente['fotoUrl']?.toString();

                              if (fotoData != null && fotoData.isNotEmpty) {
                                ImageProvider? imageProvider;
                                if (fotoData.startsWith('http://') ||
                                    fotoData.startsWith('https://')) {
                                  imageProvider = NetworkImage(fotoData);
                                } else {
                                  try {
                                    final cleanBase64 = fotoData.contains(',')
                                        ? fotoData.split(',').last
                                        : fotoData;
                                    imageProvider = MemoryImage(
                                      base64Decode(cleanBase64),
                                    );
                                  } catch (_) {
                                    imageProvider = null;
                                  }
                                }

                                return CircleAvatar(
                                  radius: 22,
                                  backgroundColor: rosa,
                                  backgroundImage: imageProvider,
                                  child: imageProvider == null
                                      ? Text(
                                          nombres
                                              .map(
                                                (n) => n.isNotEmpty ? n[0] : '',
                                              )
                                              .take(2)
                                              .join()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                );
                              }

                              return CircleAvatar(
                                radius: 22,
                                backgroundColor: rosa,
                                child: Text(
                                  nombres
                                      .map((n) => n.isNotEmpty ? n[0] : '')
                                      .take(2)
                                      .join()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (adminId.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('Administradores')
                              .doc(adminId)
                              .get(),
                          builder: (context, snapAdmin) {
                            final dataAdmin =
                                snapAdmin.data?.data() as Map<String, dynamic>?;
                            final nombreAdmin =
                                dataAdmin?['nombre']?.toString() ??
                                dataAdmin?['negocio']?.toString() ??
                                'Emprendimiento Oficial';
                            final telefonoAdmin =
                                dataAdmin?['telefono']?.toString() ?? '';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5DCF5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: violeta.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1EAFE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.storefront_rounded,
                                      color: violeta,
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
                                          'TIENDA / EMPRENDEDOR',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: violeta,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          nombreAdmin,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: oscuro,
                                          ),
                                        ),
                                        if (telefonoAdmin.isNotEmpty) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            'Contacto: $telefonoAdmin',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1EAFE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Conectado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: violeta,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 22),

                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6440AB),
                              Color(0xFF9A69C6),
                              rosa,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tu saldo pendiente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            cargandoFinanzas
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    ClientService.dinero(saldo),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            Text(
                              cargandoFinanzas
                                  ? 'Actualizando compras...'
                                  : 'Por $prendas prendas compradas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Tu estado de cuenta se actualiza con tus compras y pagos.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _Resumen(
                              titulo: 'Total de compras',
                              valor: cargandoFinanzas
                                  ? '...'
                                  : ClientService.dinero(totalComprado),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Resumen(
                              titulo: 'Total pagado',
                              valor: cargandoFinanzas
                                  ? '...'
                                  : ClientService.dinero(totalPagado),
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: adminId.isEmpty
                            ? null
                            : FirebaseFirestore.instance
                                  .collection('Administradores')
                                  .doc(adminId)
                                  .snapshots(),
                        builder: (context, tiendaSnapshot) {
                          final tienda = tiendaSnapshot.data?.data() ?? {};
                          final nombreTienda = tienda['nombreEmprendimiento']
                              ?.toString()
                              .trim();
                          final direccionTienda =
                              tienda['direccionTienda']?.toString().trim() ??
                              '';
                          final latitud = (tienda['latitudTienda'] as num?)
                              ?.toDouble();
                          final longitud = (tienda['longitudTienda'] as num?)
                              ?.toDouble();
                          final tieneUbicacion =
                              latitud != null && longitud != null;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _tarjeta(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _mostrarMapaTienda(
                                    context,
                                    nombre: nombreTienda ?? '',
                                    direccion: direccionTienda,
                                    latitud: latitud,
                                    longitud: longitud,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.storefront_outlined,
                                        color: violeta,
                                        size: 36,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'VISÍTANOS',
                                              style: TextStyle(
                                                color: violeta,
                                                fontSize: 10,
                                                letterSpacing: 1,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              nombreTienda?.isNotEmpty == true
                                                  ? nombreTienda!
                                                  : 'Tienda del emprendedor',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: oscuro,
                                              ),
                                            ),
                                            Text(
                                              direccionTienda.isNotEmpty
                                                  ? direccionTienda
                                                  : 'Dirección pendiente',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.map_outlined,
                                        color: violeta,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                                if (tieneUbicacion) ...[
                                  const SizedBox(height: 14),
                                  StoreLocationPreview(
                                    latitude: latitud,
                                    longitude: longitud,
                                    height: 180,
                                  ),
                                ] else if (!tiendaSnapshot.hasData &&
                                    adminId.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const LinearProgressIndicator(minHeight: 2),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'La tienda aún no ha compartido su ubicación.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Última compra',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: oscuro,
                              ),
                            ),
                          ),
                          Text(
                            cargandoFinanzas
                                ? '...'
                                : '${compras.length} registros',
                            style: const TextStyle(
                              color: violeta,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (cargandoFinanzas)
                        const _TarjetaVacia(
                          mensaje: 'Consultando última compra...',
                        )
                      else if (ultimaCompra == null)
                        const _TarjetaVacia(
                          mensaje: 'Todavía no tienes compras registradas.',
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: _tarjeta(),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                color: violeta,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (ultimaCompra['descripcion'] ??
                                              ultimaCompra['prendaNombre'] ??
                                              'Compra registrada')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${ClientService.fecha(ultimaCompra['fecha']).day}/'
                                      '${ClientService.fecha(ultimaCompra['fecha']).month}/'
                                      '${ClientService.fecha(ultimaCompra['fecha']).year}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                ClientService.dinero(_subtotal(ultimaCompra)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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

  static double _subtotal(Map<String, dynamic> compra) {
    if (compra['subtotal'] is num) {
      return ClientService.numero(compra['subtotal']);
    }

    return ClientService.numero(compra['precioUnitario']) *
        ClientService.numero(compra['cantidad']);
  }

  static BoxDecoration _tarjeta() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: const Color(0xFFECE6F0)),
  );
}

class _Resumen extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color color;

  const _Resumen({
    required this.titulo,
    required this.valor,
    this.color = const Color(0xFF241B35),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE6F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 7),
          Text(
            valor,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaVacia extends StatelessWidget {
  final String mensaje;
  const _TarjetaVacia({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(mensaje, textAlign: TextAlign.center),
    );
  }
}

class _SinFicha extends StatelessWidget {
  const _SinFicha();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('secretarios')
            .doc(uid)
            .get(),
        builder: (context, secretarioSnapshot) {
          final adminId =
              secretarioSnapshot.data?.data()?['adminId']?.toString() ?? '';
          if (adminId.isEmpty) return _mensajeSinFicha();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('Administradores')
                .doc(adminId)
                .snapshots(),
            builder: (context, adminSnapshot) {
              final tienda = adminSnapshot.data?.data() ?? {};
              final latitud = (tienda['latitudTienda'] as num?)?.toDouble();
              final longitud = (tienda['longitudTienda'] as num?)?.toDouble();
              final tieneUbicacion = latitud != null && longitud != null;

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                children: [
                  if (tieneUbicacion)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: ClientHomeScreen._tarjeta(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TIENDA DEL EMPRENDEDOR',
                            style: TextStyle(
                              color: ClientHomeScreen.violeta,
                              fontSize: 10,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tienda['nombreEmprendimiento']?.toString() ??
                                'Tienda',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if ((tienda['direccionTienda']?.toString() ?? '')
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 3,
                                bottom: 12,
                              ),
                              child: Text(
                                tienda['direccionTienda'].toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 12),
                          StoreLocationPreview(
                            latitude: latitud,
                            longitude: longitud,
                            height: 190,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  _mensajeSinFicha(),
                ],
              );
            },
          );
        },
      );
    }

    return _mensajeSinFicha();
  }

  Widget _mensajeSinFicha() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Tu cuenta todavía no está vinculada a una ficha de cliente. '
          'Comunícate con la tienda para completar la vinculación.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
