import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_theme.dart';
import '../../models/administrador_model.dart';
import '../../services/client_service.dart';
import '../secretary/clothing_prices_screen.dart';
import '../secretary/payments_screen.dart';
import '../auth/login_screen.dart';
import '../../services/perfil_foto_service.dart';

/// Pantalla "Más opciones" del admin – Figma fiel.
///
/// Muestra la tarjeta del administrador, la gestión de secretarios
/// (separando solicitudes Pendientes de Aprobación del Equipo Activo)
/// y accesos rápidos a Prendas, Pagos y Configuración.
class AdminMoreScreen extends StatelessWidget {
  final AdministradorModel admin;
  final VoidCallback? onVolver;

  const AdminMoreScreen({
    super.key,
    required this.admin,
    this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            // ─── Top bar ───
            Row(
              children: [
                if (onVolver != null || Navigator.canPop(context)) ...[
                  InkWell(
                    onTap: () {
                      if (onVolver != null) {
                        onVolver!();
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PANEL DE ADMIN',
                        style: TextStyle(
                          color: AppTheme.violet,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Más opciones',
                        style: TextStyle(
                          color: AppTheme.dark,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Admin Card ───
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF56349D), Color(0xFF7650BC)],
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: [
                  StreamBuilder<String?>(
                    stream: PerfilFotoService.fotoStream(admin.id),
                    builder: (context, fotoSnap) {
                      final foto = fotoSnap.data;
                      if (foto != null && foto.isNotEmpty) {
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0x55FFFFFF),
                          backgroundImage: NetworkImage(foto),
                        );
                      }
                      return CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0x55FFFFFF),
                        child: Text(
                          admin.iniciales,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin.nombreCompleto.isEmpty
                              ? 'Administrador'
                              : admin.nombreCompleto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          admin.correo.isEmpty
                              ? 'admin@vendix.com'
                              : admin.correo,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: Color(0xFFF39C12),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ─── Sección "Gestionar Secretarios" (con Pendientes y Aprobación) ───
            _SecretariosSection(admin: admin),

            const SizedBox(height: 26),

            // ─── Acciones rápidas ───
            const Text(
              'Acciones rápidas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 10),

            _buildActionCard(
              context,
              icon: Icons.checkroom_outlined,
              iconBg: const Color(0xFFF0E9FC),
              iconColor: AppTheme.violet,
              title: 'Gestionar prendas',
              subtitle: 'Editar catálogo, códigos y precios oficiales',
              destination: const ClothingPricesScreen(),
            ),
            const SizedBox(height: 8),

            _buildActionCard(
              context,
              icon: Icons.payments_outlined,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: AppTheme.green,
              title: 'Gestión de pagos',
              subtitle: 'Revisar abonos, verificar transferencias y saldos',
              destination: const PaymentsScreen(),
            ),

            const SizedBox(height: 26),

            // ─── Ajustes de la cuenta ───
            const Text(
              'Ajustes de la cuenta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined, color: AppTheme.violet),
                    title: const Text('Tema y apariencia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Colores del live y formato de moneda', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.muted),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: AppTheme.violet),
                    title: const Text('Seguridad y accesos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Cambiar contraseña y permisos', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.muted),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Cerrar sesión', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Cerrar sesión'),
                          content: const Text('¿Estás seguro de que deseas salir del panel de administración?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await FirebaseAuth.instance.signOut();
                                ClientService.limpiarCache();
                                if (!context.mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              },
                              child: const Text('Salir'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Sección "Gestionar Secretarios" con pestaña de Pendientes
// ══════════════════════════════════════════════════════════════
class _SecretariosSection extends StatefulWidget {
  final AdministradorModel admin;
  const _SecretariosSection({required this.admin});

  @override
  State<_SecretariosSection> createState() => _SecretariosSectionState();
}

class _SecretariosSectionState extends State<_SecretariosSection> {
  // 0 = Activos / Equipo, 1 = En Pendiente
  int _tabSeleccionada = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Título + botón Registrar ───
        Row(
          children: [
            const Expanded(
              child: Text(
                'Gestionar secretarios',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.dark,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _mostrarRegistroSecretario(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 16, color: AppTheme.violet),
                  SizedBox(width: 4),
                  Text(
                    'Registrar',
                    style: TextStyle(
                      color: AppTheme.violet,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ─── Selector de pestañas: Equipo / En Pendiente ───
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('secretarios').snapshots(),
          builder: (context, snapshot) {
            int countPendientes = 0;
            int countActivos = 0;

            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                final estado = d['estado'];
                final estadoSol = d['estado_solicitud']?.toString().toLowerCase();
                final aprobado = d['aprobado'];

                if (estadoSol == 'pendiente' || (estado == false && aprobado != true)) {
                  countPendientes++;
                } else if (d['adminId'] == widget.admin.id) {
                  countActivos++;
                }
              }
            }

            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBF8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabSeleccionada = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabSeleccionada == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _tabSeleccionada == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Activos ($countActivos)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _tabSeleccionada == 0 ? AppTheme.violet : AppTheme.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabSeleccionada = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabSeleccionada == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _tabSeleccionada == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'En pendiente',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _tabSeleccionada == 1 ? const Color(0xFFE67E22) : AppTheme.muted,
                              ),
                            ),
                            if (countPendientes > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE67E22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$countPendientes',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // ─── Lista en tiempo real según la pestaña seleccionada ───
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('secretarios')
              .orderBy('fecha_registro', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
            }

            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
            }

            final allDocs = snapshot.data?.docs ?? [];

            // Filtrar según pestaña
            // - Pendientes: sin adminId (cualquier admin puede aprobarlos)
            // - Activos: solo los que pertenecen a este admin
            final filteredDocs = allDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final estado = d['estado'];
              final estadoSol = d['estado_solicitud']?.toString().toLowerCase();
              final aprobado = d['aprobado'];
              final esPendiente = estadoSol == 'pendiente' || (estado == false && aprobado != true);

              if (_tabSeleccionada == 1) {
                return esPendiente;
              } else {
                // Solo activos que pertenecen a este admin
                return !esPendiente && d['adminId'] == widget.admin.id;
              }
            }).toList();

            if (filteredDocs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      _tabSeleccionada == 1 ? Icons.pending_actions_rounded : Icons.people_outline,
                      size: 32,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tabSeleccionada == 1
                          ? 'No hay solicitudes pendientes de aprobación'
                          : 'Aún no hay secretarios activos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: filteredDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final nombre = (data['nombre'] ?? 'Sin nombre').toString();
                final telefono = (data['telefono'] ?? '').toString();
                final correo = (data['correo'] ?? '').toString();
                final direccion = (data['direccion'] ?? '').toString();
                final iniciales = _getIniciales(nombre);

                // En la pestaña "En Pendiente"
                if (_tabSeleccionada == 1) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE67E22).withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: const Color(0xFFFFE0B2),
                              child: Text(
                                iniciales,
                                style: const TextStyle(
                                  color: Color(0xFFD35400),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.dark,
                                    ),
                                  ),
                                  Text(
                                    correo,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'En Pendiente',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE67E22),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (telefono.isNotEmpty || direccion.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (telefono.isNotEmpty) ...[
                                const Icon(Icons.phone_outlined, size: 12, color: AppTheme.muted),
                                const SizedBox(width: 4),
                                Text(telefono, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                                const SizedBox(width: 12),
                              ],
                              if (direccion.isNotEmpty) ...[
                                const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    direccion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _rechazarSecretario(context, docId, data),
                                child: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF27AE60),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _aprobarSecretario(context, docId, data),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Aprobar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // En la pestaña "Activos"
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFFF0E9FC),
                      child: Text(
                        iniciales,
                        style: const TextStyle(
                          color: AppTheme.violet,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dark,
                      ),
                    ),
                    subtitle: Text(
                      telefono.isNotEmpty ? telefono : correo,
                      style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: Color(0xFF27AE60)),
                          SizedBox(width: 4),
                          Text(
                            'Activo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF27AE60),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _getIniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    return partes.take(2).map((p) => p[0]).join().toUpperCase();
  }

  Future<void> _aprobarSecretario(BuildContext context, String docId, Map<String, dynamic> data) async {
    try {
      final db = FirebaseFirestore.instance;
      final lote = db.batch();
      final adminId = widget.admin.id;

      // Actualizar en 'secretarios' — vincular al admin que aprueba
      lote.update(db.collection('secretarios').doc(docId), {
        'estado': true,
        'aprobado': true,
        'estado_solicitud': 'aprobado',
        'fecha_aprobacion': FieldValue.serverTimestamp(),
        'adminId': adminId,
      });

      // Si tiene UID asociado o documento en usuarios con el mismo id
      final userDocRef = db.collection('usuarios').doc(docId);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        lote.update(userDocRef, {
          'estado': 'activo',
          'aprobado': true,
          'rol': 'secretaria',
          'adminId': adminId,
        });
      } else {
        // Buscar por correo en 'usuarios' si el docId no era el UID
        final correo = data['correo'];
        if (correo != null) {
          final query = await db.collection('usuarios').where('correo', isEqualTo: correo).limit(1).get();
          if (query.docs.isNotEmpty) {
            lote.update(query.docs.first.reference, {
              'estado': 'activo',
              'aprobado': true,
              'rol': 'secretaria',
              'adminId': adminId,
            });
          }
        }
      }

      await lote.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['nombre'] ?? 'Secretario'} ha sido aprobado con éxito.'),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al aprobar: $e')));
      }
    }
  }

  Future<void> _rechazarSecretario(BuildContext context, String docId, Map<String, dynamic> data) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Text('¿Deseas rechazar la cuenta de ${data['nombre'] ?? 'este usuario'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final db = FirebaseFirestore.instance;
      await db.collection('secretarios').doc(docId).update({
        'estado': false,
        'aprobado': false,
        'estado_solicitud': 'rechazado',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _mostrarRegistroSecretario(BuildContext context) {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final correoController = TextEditingController();
    final direccionController = TextEditingController();
    final contrasenaController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NUEVO SECRETARIO',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.violet,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Registrar miembro del equipo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EDFD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.people_outline, color: AppTheme.violet, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acceso directo autorizado',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.violet,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Al registrarlo directamente desde aquí, el secretario quedará Activo y aprobado de inmediato.',
                                style: TextStyle(fontSize: 11, color: AppTheme.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campos del formulario
                  const Text('Nombre completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nombreController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Ej. Luis Andrade',
                      filled: true,
                      fillColor: const Color(0xFFF7F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Número de teléfono', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '099 000 0000',
                      filled: true,
                      fillColor: const Color(0xFFF7F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Dirección', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: direccionController,
                    decoration: InputDecoration(
                      hintText: 'Dirección (opcional)',
                      filled: true,
                      fillColor: const Color(0xFFF7F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Correo para iniciar sesión', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'luis@vendix.com',
                      filled: true,
                      fillColor: const Color(0xFFF7F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Contraseña temporal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: contrasenaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Mínimo 6 caracteres y 1 símbolo (@, #, \$...)',
                      filled: true,
                      fillColor: const Color(0xFFF7F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa una contraseña temporal.';
                      }
                      if (v.length < 6) {
                        return 'Usa al menos 6 caracteres.';
                      }
                      if (!RegExp(r'[a-zA-Z0-9]').hasMatch(v)) {
                        return 'Debe incluir caracteres alfanuméricos.';
                      }
                      if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(v)) {
                        return 'Debe incluir al menos un carácter especial (ej. @, #, \$, *, !).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.violet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('secretarios')
                                .add({
                              'nombre': nombreController.text.trim(),
                              'telefono': telefonoController.text.trim(),
                              'correo': correoController.text.trim(),
                              'direccion': direccionController.text.trim(),
                              'estado': true,
                              'aprobado': true,
                              'estado_solicitud': 'aprobado',
                              'fecha_registro': FieldValue.serverTimestamp(),
                              'adminId': widget.admin.id,
                            });
                            if (bottomSheetContext.mounted) {
                              Navigator.pop(bottomSheetContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Secretario registrado y activado con éxito'),
                                  backgroundColor: AppTheme.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (bottomSheetContext.mounted) {
                              ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Registrar secretario',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }
}
