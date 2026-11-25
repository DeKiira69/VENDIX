import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/administrador_model.dart';
import '../../services/client_service.dart';
import '../../services/id_service.dart';
import '../../services/perfil_foto_service.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_home_screen.dart';
import '../auth/login_screen.dart';
import '../secretary/secretary_shell.dart';
import 'client_shell.dart';
import 'enter_code_screen.dart';
import 'solicitud_empleo_screen.dart';

/// Pantalla inteligente de bienvenida / selección para el rol Cliente.
///
/// Detecta asociaciones existentes (tiendas y empleos) y enruta
/// automáticamente cuando solo hay una, o muestra un picker cuando hay varias.
/// Si no hay ninguna, muestra las 2 tarjetas originales.
class ClientWelcomeHubScreen extends StatefulWidget {
  const ClientWelcomeHubScreen({super.key});

  @override
  State<ClientWelcomeHubScreen> createState() => _ClientWelcomeHubScreenState();
}

class _ClientWelcomeHubScreenState extends State<ClientWelcomeHubScreen> {
  static const Color violeta = Color(0xFF6C4AB6);
  static const Color violetaOscuro = Color(0xFF4D2C91);
  static const Color rosa = Color(0xFFE9A6C8);
  static const Color fondo = Color(0xFFF8F6FA);

  bool _cargando = true;
  List<Map<String, dynamic>> _misTiendas = [];
  List<Map<String, dynamic>> _misEmpleos = [];

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  void initState() {
    super.initState();
    _detectarAsociaciones();
  }

  Future<void> _detectarAsociaciones() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    try {
      final db = FirebaseFirestore.instance;

      // Consultar tiendas del cliente y empleos aprobados en paralelo
      final resultados = await Future.wait([
        db.collection('usuarios').doc(uid).collection('mis_tiendas').get(),
        db
            .collection('secretarios')
            .where('clienteId', isEqualTo: uid)
            .get(),
      ]);

      final tiendasSnap = resultados[0] as QuerySnapshot;
      final empleosSnap = resultados[1] as QuerySnapshot;

      final tiendas = tiendasSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {...data, 'docId': d.id};
      }).toList();

      final empleos = empleosSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final est = data['estado_solicitud']?.toString().toLowerCase() ?? '';
        return (data['aprobado'] == true || data['estado'] == true) &&
            est != 'renunciado' &&
            est != 'rechazado';
      }).map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {...data, 'docId': d.id};
      }).toList();

      if (!mounted) return;

      setState(() {
        _misTiendas = tiendas;
        _misEmpleos = empleos;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Modal para crear emprendimiento: pide solo el nombre de la tienda.
  void _mostrarModalEmprendedor() {
    final formKey = GlobalKey<FormState>();
    final emprendimientoCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(bottomCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Crear mi emprendimiento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF241B35),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ingresa el nombre de tu negocio para comenzar a vender en VendiX.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF81798D)),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Nombre del emprendimiento',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emprendimientoCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Ej. Boutique Bella',
                        prefixIcon: const Icon(
                          Icons.storefront_outlined,
                          color: Color(0xFF2E7D32),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAF8FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFECE6F2)),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre del emprendimiento'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => guardando = true);

                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) throw Exception('No hay sesión activa.');

                                  final uid = user.uid;
                                  final db = FirebaseFirestore.instance;
                                  final nombreEmprendimiento = emprendimientoCtrl.text.trim();

                                  // Leer datos actuales del usuario
                                  final userDoc = await db.collection('usuarios').doc(uid).get();
                                  final userData = userDoc.data() ?? {};
                                  final nombre = userData['nombre']?.toString() ?? '';
                                  final apellido = userData['apellido']?.toString() ?? '';
                                  final correo = userData['correo']?.toString() ?? user.email ?? '';
                                  final telefono = userData['telefono']?.toString() ?? '';
                                  final fotoUrl = userData['fotoUrl']?.toString() ?? user.photoURL ?? '';

                                  final idAdmin = await IdService.generarIdAdministrador('$nombre $apellido');
                                  final lote = db.batch();

                                  // Crear documento en Administradores
                                  lote.set(db.collection('Administradores').doc(idAdmin), {
                                    'id': idAdmin,
                                    'codigo': idAdmin,
                                    'uid': uid,
                                    'firebaseUid': uid,
                                    'nombre': nombre,
                                    'apellido': apellido,
                                    'nombreEmprendimiento': nombreEmprendimiento,
                                    'correo': correo,
                                    'telefono': telefono,
                                    'direccionTienda': '',
                                    'latitudTienda': null,
                                    'longitudTienda': null,
                                    'fotoUrl': fotoUrl,
                                    'estado': true,
                                    'creadoEn': FieldValue.serverTimestamp(),
                                    'metodo_registro': userData['metodo_registro'] ?? 'google',
                                  });

                                  // Actualizar documento en usuarios para cambiar rol
                                  lote.set(db.collection('usuarios').doc(uid), {
                                    'rol': 'administrador',
                                    'adminId': idAdmin,
                                    'nombreEmprendimiento': nombreEmprendimiento,
                                    'actualizadoEn': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  await lote.commit();

                                  if (!bottomCtx.mounted) return;
                                  Navigator.pop(bottomCtx);

                                  if (!mounted) return;

                                  final admin = AdministradorModel(
                                    id: idAdmin,
                                    nombre: nombre,
                                    apellido: apellido,
                                    nombreEmprendimiento: nombreEmprendimiento,
                                    correo: correo,
                                    telefono: telefono,
                                    estado: true,
                                  );

                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => AdminHomeScreen(admin: admin)),
                                    (route) => false,
                                  );
                                } catch (e) {
                                  setModalState(() => guardando = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al crear emprendimiento: $e')),
                                    );
                                  }
                                }
                              },
                        child: guardando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Crear emprendimiento',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Activa una tienda como la tienda activa y navega a ClientShell
  Future<void> _activarTiendaYEntrar(Map<String, dynamic> tienda) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;
    final adminId = tienda['adminId']?.toString() ?? '';
    final codigo = tienda['codigoLive']?.toString() ?? '';
    final secretarioId = tienda['secretarioId']?.toString() ?? '';

    final actualizacion = {
      'adminId': adminId,
      'codigoLive': codigo,
      'secretarioId': secretarioId,
    };

    try {
      final lote = db.batch();
      lote.set(db.collection('usuarios').doc(uid), actualizacion, SetOptions(merge: true));
      lote.set(db.collection('clientes').doc(uid), actualizacion, SetOptions(merge: true));
      await lote.commit();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ClientShell()),
      (route) => false,
    );
  }

  /// Navega al modo secretario con los datos del empleo
  void _entrarComoSecretario(Map<String, dynamic> empleo) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SecretaryShell(
          adminIdInicial: empleo['adminId']?.toString(),
          nombreEmprendimientoInicial: empleo['nombreEmprendimiento']?.toString(),
          adminNombreInicial: empleo['adminNombre']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    final usuarioId = usuario?.uid ?? '';

    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(usuarioId)
              .snapshots(),
          builder: (context, snapshot) {
            final datos = snapshot.data?.data() ?? {};
            final nombre = datos['nombre']?.toString().trim() ?? '';
            final apellido = datos['apellido']?.toString().trim() ?? '';
            final nombreCompleto = [nombre, apellido]
                .where((s) => s.isNotEmpty)
                .join(' ');
            final nombreMostrar = nombreCompleto.isNotEmpty
                ? nombreCompleto
                : (usuario?.displayName ?? 'Cliente');

            final inicial = nombreMostrar.isNotEmpty
                ? nombreMostrar[0].toUpperCase()
                : 'C';

            if (_cargando) {
              return const Center(child: CircularProgressIndicator(color: violeta));
            }

            final tieneTiendas = _misTiendas.isNotEmpty;
            final tieneEmpleos = _misEmpleos.isNotEmpty;
            final tieneAsociaciones = tieneTiendas || tieneEmpleos;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                // ─── Header superior con perfil y salir ───
                _buildHeader(usuarioId, inicial, nombreMostrar),
                const SizedBox(height: 22),

                // ─── Banner Hero ───
                _buildBanner(tieneAsociaciones),
                const SizedBox(height: 24),

                // ─── Contenido dinámico según asociaciones ───
                if (tieneAsociaciones) ...[
                  // Sección: Mis Tiendas (Cliente)
                  if (tieneTiendas) ...[
                    _buildSeccionTitulo('Mis Tiendas', Icons.storefront_outlined, const Color(0xFFE91E63)),
                    const SizedBox(height: 10),
                    ..._misTiendas.map((tienda) => _buildTiendaCard(tienda)),
                    const SizedBox(height: 16),
                  ],

                  // Sección: Mis Empleos (Secretario)
                  if (tieneEmpleos) ...[
                    _buildSeccionTitulo('Mis Empleos', Icons.badge_outlined, violeta),
                    const SizedBox(height: 10),
                    ..._misEmpleos.map((empleo) => _buildEmpleoCard(empleo)),
                    const SizedBox(height: 16),
                  ],

                  // Acciones adicionales
                  const Divider(height: 32),
                  _buildAccionSecundaria(
                    icono: Icons.add_business_outlined,
                    texto: 'Unirme a otro emprendimiento (código)',
                    color: const Color(0xFFE91E63),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnterCodeScreen())),
                  ),
                  const SizedBox(height: 8),
                  _buildAccionSecundaria(
                    icono: Icons.work_outline_rounded,
                    texto: 'Solicitar empleo en otra tienda',
                    color: violeta,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitudEmpleoScreen())),
                  ),
                ] else ...[
                  // ─── Sin asociaciones: Mostrar tarjetas originales ───
                  const Text(
                    'Selecciona una opción',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HubCard(
                    titulo: 'Asociarse a un emprendimiento',
                    subtitulo:
                        'Ingresa el código proporcionado por el vendedor o secretario durante el live para comprar y consultar tus prendas.',
                    etiqueta: 'MODO COMPRADOR',
                    etiquetaColor: const Color(0xFFE91E63),
                    icono: Icons.shopping_bag_outlined,
                    colorFondoIcono: const Color(0xFFFDECEF),
                    colorIcono: const Color(0xFFE91E63),
                    botonTexto: 'Ingresar código del Live',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EnterCodeScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _HubCard(
                    titulo: 'Solicitar empleo',
                    subtitulo:
                        'Explora todos los emprendimientos registrados y postúlate para ser secretario y operador de ventas en transmisiones en vivo.',
                    etiqueta: 'OPORTUNIDAD LABORAL',
                    etiquetaColor: violeta,
                    icono: Icons.work_outline_rounded,
                    colorFondoIcono: const Color(0xFFF0E9FC),
                    colorIcono: violeta,
                    botonTexto: 'Ver tiendas y postular',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SolicitudEmpleoScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _HubCard(
                    titulo: 'Trabajar como emprendedor',
                    subtitulo:
                        'Crea tu propia tienda en VendiX, registra prendas, gestiona ventas en vivo y haz crecer tu negocio.',
                    etiqueta: 'EMPRENDIMIENTO',
                    etiquetaColor: const Color(0xFF2E7D32),
                    icono: Icons.storefront_outlined,
                    colorFondoIcono: const Color(0xFFE8F5E9),
                    colorIcono: const Color(0xFF2E7D32),
                    botonTexto: 'Crear mi emprendimiento',
                    onTap: () => _mostrarModalEmprendedor(),
                  ),
                ],

                const SizedBox(height: 24),
                _MisSolicitudesSection(usuarioId: usuarioId),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Widgets auxiliares del Hub Inteligente ───

  Widget _buildHeader(String usuarioId, String inicial, String nombreMostrar) {
    return Row(
      children: [
        StreamBuilder<String?>(
          stream: PerfilFotoService.fotoStream(usuarioId),
          builder: (context, fotoSnap) {
            final foto = fotoSnap.data;
            if (foto != null && foto.isNotEmpty) {
              return CircleAvatar(
                radius: 24,
                backgroundColor: violeta,
                backgroundImage: NetworkImage(foto),
              );
            }
            return CircleAvatar(
              radius: 24,
              backgroundColor: rosa,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BIENVENIDO A VENDIX',
                style: TextStyle(
                  color: violeta,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_saludo()}, $nombreMostrar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.dark,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout_rounded, color: Colors.grey),
          onPressed: () => _confirmarCerrarSesion(context),
        ),
      ],
    );
  }

  Widget _buildBanner(bool tieneAsociaciones) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [violetaOscuro, violeta, Color(0xFF9B59B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: violeta.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      tieneAsociaciones ? 'TUS EMPRENDIMIENTOS' : 'TU ESPACIO COMERCIAL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tieneAsociaciones ? '¡Bienvenido de vuelta!' : '¿Cómo deseas participar hoy?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tieneAsociaciones
                ? 'Selecciona la tienda o empleo al que deseas ingresar, o únete a un nuevo emprendimiento.'
                : 'Elige si deseas ingresar como comprador a una tienda o postularte para trabajar como secretario en transmisiones en vivo.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Icon(icono, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTiendaCard(Map<String, dynamic> tienda) {
    final nombre = tienda['nombreEmprendimiento']?.toString() ?? 'Tienda';
    final admin = tienda['adminNombre']?.toString() ?? '';
    final codigo = tienda['codigoLive']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE6F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _activarTiendaYEntrar(tienda),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront, color: Color(0xFFE91E63), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (admin.isNotEmpty)
                        Text(
                          'Dueño: $admin',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      if (codigo.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E8FC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Código: $codigo',
                            style: const TextStyle(color: violeta, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.link_off, size: 20, color: Color(0xFF9E9E9E)),
                  tooltip: 'Desvincularme',
                  onPressed: () => _desvincularTiendaDesdeHub(tienda),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _desvincularTiendaDesdeHub(Map<String, dynamic> tienda) async {
    final nombre = tienda['nombreEmprendimiento']?.toString() ?? 'esta tienda';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.link_off, color: Colors.redAccent),
            SizedBox(width: 8),
            Flexible(child: Text('Desvincularse')),
          ],
        ),
        content: Text(
          '¿Deseas desvincularte de "$nombre"?\n\nYa no verás sus prendas ni pedidos en vivo.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Desvincularme'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final docId = tienda['docId']?.toString() ?? '';
      if (docId.isNotEmpty) {
        batch.delete(db.collection('usuarios').doc(uid).collection('mis_tiendas').doc(docId));
      }

      // Si no tiene docId o por seguridad, buscar todas las coincidencias
      final misTiendasSnap = await db
          .collection('usuarios')
          .doc(uid)
          .collection('mis_tiendas')
          .get();
      final adminId = tienda['adminId']?.toString() ?? '';
      for (final d in misTiendasSnap.docs) {
        if (d.id == docId || (adminId.isNotEmpty && (d.id == adminId || d.data()['adminId'] == adminId))) {
          batch.delete(d.reference);
        }
      }

      // Limpieza de campos raíz
      final actualizacion = {
        'codigoLive': '',
        'adminId': '',
        'secretarioId': '',
        'fecha_desvinculacion': FieldValue.serverTimestamp(),
      };
      batch.set(db.collection('usuarios').doc(uid), actualizacion, SetOptions(merge: true));
      batch.set(db.collection('clientes').doc(uid), actualizacion, SetOptions(merge: true));

      try {
        final qClientes = await db.collection('clientes').where('uid', isEqualTo: uid).get();
        for (final cDoc in qClientes.docs) {
          batch.set(cDoc.reference, actualizacion, SetOptions(merge: true));
        }
      } catch (_) {}

      await batch.commit();
      ClientService.limpiarCache();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Te has desvinculado de "$nombre" correctamente.'),
          backgroundColor: const Color(0xFF6C4AB6),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _detectarAsociaciones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al desvincularse: $e')),
      );
    }
  }

  Widget _buildEmpleoCard(Map<String, dynamic> empleo) {
    final nombre = empleo['nombreEmprendimiento']?.toString() ??
        empleo['adminNombre']?.toString() ??
        'Emprendimiento';
    final adminNom = empleo['adminNombre']?.toString() ?? '';
    final codigo = empleo['codigoLive']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE6F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _entrarComoSecretario(empleo),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E9FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_outlined, color: violeta, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (adminNom.isNotEmpty)
                        Text('Emprendedor: $adminNom', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (codigo.isNotEmpty)
                        Text('Código: $codigo', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF9E9E9E)),
                  tooltip: 'Renunciar a este empleo',
                  onPressed: () => _renunciarEmpleoDesdeHub(empleo),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: violeta,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renunciarEmpleoDesdeHub(Map<String, dynamic> empleo) async {
    final nombre = empleo['nombreEmprendimiento']?.toString() ??
        empleo['adminNombre']?.toString() ??
        'este emprendimiento';
    final adminId = empleo['adminId']?.toString() ?? '';
    final docId = empleo['docId']?.toString() ?? '';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Renunciar al empleo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Deseas renunciar como secretario de "$nombre"?\n\nYa no tendrás acceso a la administración ni ventas de esta tienda.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sí, renunciar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final lote = db.batch();

      if (docId.isNotEmpty) {
        lote.update(db.collection('secretarios').doc(docId), {
          'estado': false,
          'aprobado': false,
          'estado_solicitud': 'renunciado',
          'fecha_renuncia': FieldValue.serverTimestamp(),
        });
      }

      if (adminId.isNotEmpty) {
        lote.set(
          db.collection('usuarios').doc(uid).collection('mis_empleos').doc(adminId),
          {
            'estado': 'renunciado',
            'aprobado': false,
            'fecha_renuncia': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await lote.commit();
      ClientService.limpiarCache();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Has renunciado como secretario de $nombre.'),
          backgroundColor: const Color(0xFF27AE60),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _detectarAsociaciones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al renunciar: $e')),
      );
    }
  }

  Widget _buildAccionSecundaria({
    required IconData icono,
    required String texto,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas salir de VENDIX?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      ClientService.limpiarCache();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Widget de Tarjeta Principal del Hub
// ─────────────────────────────────────────────────────────────
class _HubCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String etiqueta;
  final Color etiquetaColor;
  final IconData icono;
  final Color colorFondoIcono;
  final Color colorIcono;
  final String botonTexto;
  final VoidCallback onTap;

  const _HubCard({
    required this.titulo,
    required this.subtitulo,
    required this.etiqueta,
    required this.etiquetaColor,
    required this.icono,
    required this.colorFondoIcono,
    required this.colorIcono,
    required this.botonTexto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorFondoIcono,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icono, color: colorIcono, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: etiquetaColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              etiqueta,
                              style: TextStyle(
                                color: etiquetaColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      botonTexto,
                      style: TextStyle(
                        color: colorIcono,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: colorIcono),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sección para monitorear solicitudes de empleo enviadas
// ─────────────────────────────────────────────────────────────
class _MisSolicitudesSection extends StatelessWidget {
  final String usuarioId;

  const _MisSolicitudesSection({required this.usuarioId});

  @override
  Widget build(BuildContext context) {
    if (usuarioId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('secretarios')
          .where('clienteId', isEqualTo: usuarioId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final aprobados = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final est = data['estado_solicitud']?.toString().toLowerCase();
          return (data['aprobado'] == true || data['estado'] == true) &&
              est != 'renunciado' &&
              est != 'rechazado';
        }).toList();

        final pendientes = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final est = data['estado_solicitud']?.toString().toLowerCase();
          return est == 'pendiente' || (data['aprobado'] != true && est != 'rechazado' && est != 'renunciado');
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tus Solicitudes de Empleo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.dark,
              ),
            ),
            const SizedBox(height: 10),

            // Si tiene empleos aprobados, permitir entrar directo al modo secretario
            if (aprobados.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA3E4D7)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF27AE60),
                      radius: 18,
                      child: Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¡Has sido contratado!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E8449),
                            ),
                          ),
                          Text(
                            'Tienes ${aprobados.length} empleo(s) activo(s) como secretario.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF145A32)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        final primerEmpleo = aprobados.first.data() as Map<String, dynamic>;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => SecretaryShell(
                              adminIdInicial: primerEmpleo['adminId']?.toString(),
                              nombreEmprendimientoInicial: primerEmpleo['nombreEmprendimiento']?.toString(),
                              adminNombreInicial: primerEmpleo['adminNombre']?.toString(),
                            ),
                          ),
                        );
                      },
                      child: const Text('Entrar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Lista de solicitudes en revisión pendiente
            ...pendientes.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final tienda = data['nombreEmprendimiento']?.toString() ??
                  data['adminNombre']?.toString() ??
                  'Emprendimiento';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: Color(0xFFE67E22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tienda,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.dark,
                            ),
                          ),
                          const Text(
                            'Solicitud en revisión por el emprendedor',
                            style: TextStyle(fontSize: 10, color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
              );
            }),
          ],
        );
      },
    );
  }
}
