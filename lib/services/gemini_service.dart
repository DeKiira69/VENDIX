import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../secrets.dart';

/// Modelo de datos que encapsula el contexto real del cliente y de la tienda obtenido de Firebase
class ContextoClienteChatbot {
  final String nombre;
  final String telefono;
  final String codigoLive;
  final double totalComprado;
  final double totalPagado;
  final double saldoPendiente;
  final int totalPrendas;
  final List<String> ultimasPrendas;
  final String nombreTienda;
  final String nombreEmprendedor;
  final String direccionTienda;
  final String telefonoTienda;
  final String correoTienda;
  final List<String> catalogoPrendas;

  const ContextoClienteChatbot({
    required this.nombre,
    required this.telefono,
    required this.codigoLive,
    required this.totalComprado,
    required this.totalPagado,
    required this.saldoPendiente,
    required this.totalPrendas,
    required this.ultimasPrendas,
    required this.nombreTienda,
    required this.nombreEmprendedor,
    required this.direccionTienda,
    required this.telefonoTienda,
    required this.correoTienda,
    required this.catalogoPrendas,
  });

  factory ContextoClienteChatbot.vacio() {
    return const ContextoClienteChatbot(
      nombre: 'Cliente',
      telefono: '',
      codigoLive: '',
      totalComprado: 0,
      totalPagado: 0,
      saldoPendiente: 0,
      totalPrendas: 0,
      ultimasPrendas: [],
      nombreTienda: 'Tienda Vendix',
      nombreEmprendedor: 'Emprendedor Vendix',
      direccionTienda: 'Consultar en la tienda física o transmisiones en vivo',
      telefonoTienda: '',
      correoTienda: '',
      catalogoPrendas: [],
    );
  }
}

/// Servicio que integra Firebase Firestore con Google Gemini API
class GeminiService {
  GeminiService._();

  /// Clave de API de Google Gemini — se lee desde lib/secrets.dart (excluido de Git)
  /// Si se pasa con --dart-define=GEMINI_API_KEY=xxx, esa tiene prioridad.
  static String apiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  ).isNotEmpty
      ? const String.fromEnvironment('GEMINI_API_KEY')
      : AppSecrets.geminiApiKey;

  /// Modelo de Gemini a utilizar (Gemini 3.5 Flash Lite es ultra rápido, moderno y estable)
  static const String modeloGemini = 'gemini-3.5-flash-lite';

  static GenerativeModel? _modelo;
  static ChatSession? _chatSession;
  static String? _ultimoSystemPrompt;

  /// Obtiene de Firebase toda la información relevante del cliente y de la tienda asociada
  static Future<ContextoClienteChatbot> obtenerContextoCliente() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return ContextoClienteChatbot.vacio();
    }

    final db = FirebaseFirestore.instance;
    final uid = authUser.uid;

    try {
      // 1. Buscar datos del cliente en 'clientes' o 'usuarios'
      QuerySnapshot<Map<String, dynamic>> snapCliente = await db
          .collection('clientes')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      Map<String, dynamic>? dataCliente;
      String clienteId = '';

      if (snapCliente.docs.isNotEmpty) {
        dataCliente = snapCliente.docs.first.data();
        clienteId = snapCliente.docs.first.id;
      } else {
        final docUsuario = await db.collection('usuarios').doc(uid).get();
        if (docUsuario.exists) {
          dataCliente = docUsuario.data();
          clienteId = docUsuario.id;
        }
      }

      final nombreCliente = (dataCliente?['nombre'] ??
              authUser.displayName ??
              'Cliente')
          .toString();
      final telefonoCliente = (dataCliente?['telefono'] ?? '').toString();
      final codigoLive = (dataCliente?['codigoLive'] ?? '').toString();
      String adminId = (dataCliente?['adminId'] ?? '').toString();

      // Si no tiene adminId directo, intentar resolverlo desde secretarios o compras
      if (adminId.isEmpty && codigoLive.isNotEmpty) {
        try {
          final snapSec = await db
              .collection('secretarios')
              .where('codigoLive', isEqualTo: codigoLive)
              .limit(1)
              .get();
          if (snapSec.docs.isNotEmpty) {
            adminId = snapSec.docs.first.data()['adminId']?.toString() ?? '';
          }
        } catch (_) {}
      }

      // 2. Consultar compras del cliente (segregado estrictamente a su ID)
      double totalComprado = 0;
      int totalPrendas = 0;
      final List<String> ultimasPrendas = [];

      if (clienteId.isNotEmpty) {
        final snapCompras = await db
            .collection('compras')
            .where('clienteId', isEqualTo: clienteId)
            .get();

        for (final doc in snapCompras.docs) {
          final data = doc.data();
          final cantidad = (data['cantidad'] is num)
              ? (data['cantidad'] as num).toInt()
              : int.tryParse(data['cantidad']?.toString() ?? '') ?? 1;
          final precio = (data['precioUnitario'] is num)
              ? (data['precioUnitario'] as num).toDouble()
              : double.tryParse(data['precioUnitario']?.toString() ?? '') ?? 0.0;
          final subtotal = (data['subtotal'] is num)
              ? (data['subtotal'] as num).toDouble()
              : (precio * cantidad);

          totalComprado += subtotal;
          totalPrendas += cantidad;

          final nombrePrenda = (data['prendaNombre'] ?? data['nombrePrenda'] ?? '').toString();
          if (nombrePrenda.isNotEmpty && ultimasPrendas.length < 5) {
            ultimasPrendas.add('$nombrePrenda (x$cantidad, \$${subtotal.toStringAsFixed(2)})');
          }
        }
      }

      // 3. Consultar pagos del cliente (segregado a su ID)
      double totalPagado = 0;
      if (clienteId.isNotEmpty) {
        final snapPagos = await db
            .collection('pagos')
            .where('clienteId', isEqualTo: clienteId)
            .get();

        for (final doc in snapPagos.docs) {
          final data = doc.data();
          final monto = (data['monto'] is num)
              ? (data['monto'] as num).toDouble()
              : double.tryParse(data['monto']?.toString() ?? '') ?? 0.0;
          totalPagado += monto;
        }
      }

      final saldoPendiente = (totalComprado - totalPagado).clamp(0.0, double.infinity);

      // 4. Consultar datos reales del Emprendimiento y Emprendedor en 'Administradores'
      String nombreTienda = 'Tienda Vendix';
      String nombreEmprendedor = 'Emprendedor Propietario';
      String direccionTienda = 'Ubicación coordinada por transmisiones en vivo';
      String telefonoTienda = '';
      String correoTienda = '';

      if (adminId.isNotEmpty) {
        try {
          final snapAdmin = await db.collection('Administradores').doc(adminId).get();
          if (snapAdmin.exists) {
            final dataAdmin = snapAdmin.data();
            if (dataAdmin != null) {
              // Nombre oficial del emprendimiento en Firestore
              if (dataAdmin['nombreEmprendimiento'] != null &&
                  dataAdmin['nombreEmprendimiento'].toString().trim().isNotEmpty) {
                nombreTienda = dataAdmin['nombreEmprendimiento'].toString().trim();
              } else if (dataAdmin['negocio'] != null &&
                  dataAdmin['negocio'].toString().trim().isNotEmpty) {
                nombreTienda = dataAdmin['negocio'].toString().trim();
              }

              // Nombre del emprendedor
              final nomAdm = dataAdmin['nombre']?.toString().trim() ?? '';
              final apeAdm = dataAdmin['apellido']?.toString().trim() ?? '';
              final adminComp = [nomAdm, apeAdm].where((s) => s.isNotEmpty).join(' ');
              if (adminComp.isNotEmpty) {
                nombreEmprendedor = adminComp;
              }

              // Dirección
              if (dataAdmin['ubicacion_tienda'] is Map) {
                final mapUbic = dataAdmin['ubicacion_tienda'] as Map<String, dynamic>;
                if (mapUbic['direccion'] != null && mapUbic['direccion'].toString().isNotEmpty) {
                  direccionTienda = mapUbic['direccion'].toString().trim();
                }
              } else if (dataAdmin['direccion'] != null &&
                  dataAdmin['direccion'].toString().trim().isNotEmpty) {
                direccionTienda = dataAdmin['direccion'].toString().trim();
              }

              if (dataAdmin['telefono'] != null) {
                telefonoTienda = dataAdmin['telefono'].toString().trim();
              }
              if (dataAdmin['correo'] != null) {
                correoTienda = dataAdmin['correo'].toString().trim();
              }
            }
          }
        } catch (_) {}
      }

      // 5. Consultar Catálogo de Prendas disponibles de la tienda (máx 15 prendas)
      final List<String> catalogoPrendas = [];
      if (adminId.isNotEmpty) {
        try {
          final snapPrendas = await db
              .collection('prendas')
              .where('adminId', isEqualTo: adminId)
              .where('disponible', isEqualTo: true)
              .limit(15)
              .get();

          for (final doc in snapPrendas.docs) {
            final d = doc.data();
            final nom = (d['nombre'] ?? 'Prenda').toString().trim();
            final pre = (d['precio'] is num)
                ? (d['precio'] as num).toDouble()
                : double.tryParse(d['precio']?.toString() ?? '') ?? 0.0;
            final tal = d['talla']?.toString().trim() ?? '';
            final col = d['color']?.toString().trim() ?? '';
            final stk = d['stock'] ?? 1;

            final List<String> detalles = [];
            if (tal.isNotEmpty) detalles.add('Talla $tal');
            if (col.isNotEmpty) detalles.add('Color $col');
            detalles.add('Stock: $stk');

            catalogoPrendas.add('$nom — \$${pre.toStringAsFixed(2)} (${detalles.join(', ')})');
          }
        } catch (_) {}
      }

      return ContextoClienteChatbot(
        nombre: nombreCliente,
        telefono: telefonoCliente,
        codigoLive: codigoLive,
        totalComprado: totalComprado,
        totalPagado: totalPagado,
        saldoPendiente: saldoPendiente,
        totalPrendas: totalPrendas,
        ultimasPrendas: ultimasPrendas,
        nombreTienda: nombreTienda,
        nombreEmprendedor: nombreEmprendedor,
        direccionTienda: direccionTienda,
        telefonoTienda: telefonoTienda,
        correoTienda: correoTienda,
        catalogoPrendas: catalogoPrendas,
      );
    } catch (_) {
      return ContextoClienteChatbot.vacio();
    }
  }

  /// Construye el Prompt de Sistema inyectando los datos vivos de Firebase con estricta seguridad
  static String _construirSystemPrompt(ContextoClienteChatbot ctx) {
    final catalogoTexto = ctx.catalogoPrendas.isNotEmpty
        ? ctx.catalogoPrendas.map((p) => '• $p').join('\n')
        : 'Catálogo disponible en transmisiones en vivo o actualizado por la tienda.';

    final ultimasPrendasTexto = ctx.ultimasPrendas.isNotEmpty
        ? ctx.ultimasPrendas.map((p) => '• $p').join('\n')
        : 'Aún no registra compras recientes.';

    return '''
Eres el asistente virtual inteligente oficial de la tienda "${ctx.nombreTienda}" en la plataforma VENDIX.
Tu misión es atender exclusivamente al cliente que ha iniciado sesión, respondiendo con amabilidad, precisión y datos 100% reales de la base de datos de Firebase:

=== 🏬 INFORMACIÓN REAL DEL EMPRENDIMIENTO Y PROPIETARIO ===
- Nombre oficial del negocio: ${ctx.nombreTienda}
- Emprendedor propietario: ${ctx.nombreEmprendedor}
- Dirección física de la tienda: ${ctx.direccionTienda}
- Teléfono de atención de la tienda: ${ctx.telefonoTienda.isNotEmpty ? ctx.telefonoTienda : 'Coordinación por la app'}
- Correo de contacto: ${ctx.correoTienda.isNotEmpty ? ctx.correoTienda : 'No registrado'}
- Código de transmisión en vivo (Live): ${ctx.codigoLive.isNotEmpty ? ctx.codigoLive : 'Sin código activo'}

=== 👗 CATÁLOGO DE PRENDAS DISPONIBLES EN TIENDA ===
$catalogoTexto

=== 👤 INFORMACIÓN REAL DE LA CUENTA DEL CLIENTE ===
- Nombre del cliente: ${ctx.nombre}
- Teléfono del cliente: ${ctx.telefono.isNotEmpty ? ctx.telefono : 'No registrado'}
- Saldo pendiente por cancelar: \$${ctx.saldoPendiente.toStringAsFixed(2)}
- Total comprado históricamente: \$${ctx.totalComprado.toStringAsFixed(2)}
- Total abonado / pagado: \$${ctx.totalPagado.toStringAsFixed(2)}
- Total prendas apartadas: ${ctx.totalPrendas} prendas
- Últimas prendas apartadas por este cliente:
$ultimasPrendasTexto

=== 🛡️ REGLAS ESTRICTAS DE RESPUESTA Y SEGURIDAD ===
1. Si preguntan por el nombre de la tienda, del negocio o quién es el dueño/emprendedor, responde exactamente: la tienda es "${ctx.nombreTienda}" y el emprendedor propietario es ${ctx.nombreEmprendedor}. ¡NUNCA inventes nombres de tiendas ficticias!
2. Si preguntan por prendas disponibles, catálogo, ropa, tallas o precios, describe amablemente las prendas reales del catálogo de la tienda indicado arriba.
3. Si el cliente pregunta por su saldo o deuda, dale su saldo pendiente actual (\$${ctx.saldoPendiente.toStringAsFixed(2)}). Si es \$0.00, felicítalo por estar al día.
4. Si preguntan dónde queda la tienda o cómo retirar prendas, indica la dirección exacta: "${ctx.direccionTienda}".
5. Si preguntan cómo apartar durante el live de TikTok o Facebook, explica que deben comentar en el live cuando muestren la prenda y el secretario la registrará en tiempo real a su nombre en VENDIX.
6. SEGURIDAD: NUNCA menciones datos de otros clientes ni expongas tokens, claves o contraseñas. Mantén un tono cordial, educado y conciso con emojis (🛍️, ✨, 📍, 👗, 🏷️).
''';
  }

  /// Envía un mensaje a la API de Gemini (con fallback inteligente a Firebase si la API Key no está configurada)
  static Future<String> enviarMensaje({
    required String mensaje,
    required ContextoClienteChatbot contexto,
  }) async {
    final mensajeLimpio = mensaje.trim();
    if (mensajeLimpio.isEmpty) return '';

    if (apiKey.isEmpty) {
      return _responderFallbackConFirebase(mensajeLimpio, contexto);
    }

    try {
      final systemPrompt = _construirSystemPrompt(contexto);

      if (_modelo == null || _ultimoSystemPrompt != systemPrompt) {
        _modelo = GenerativeModel(
          model: modeloGemini,
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt),
        );
        _ultimoSystemPrompt = systemPrompt;
        _chatSession = _modelo!.startChat();
      }

      final response = await _chatSession!.sendMessage(Content.text(mensajeLimpio));
      final respuestaTexto = response.text;

      if (respuestaTexto != null && respuestaTexto.trim().isNotEmpty) {
        return respuestaTexto.trim();
      }

      return _responderFallbackConFirebase(mensajeLimpio, contexto);
    } catch (e) {
      try {
        final systemPrompt = _construirSystemPrompt(contexto);
        final modeloRespaldo = GenerativeModel(
          model: 'gemini-3.1-flash-lite',
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt),
        );
        final respRespaldo = await modeloRespaldo.generateContent([Content.text(mensajeLimpio)]);
        final textoRespaldo = respRespaldo.text;
        if (textoRespaldo != null && textoRespaldo.trim().isNotEmpty) {
          return textoRespaldo.trim();
        }
      } catch (_) {}

      return _responderFallbackConFirebase(mensajeLimpio, contexto);
    }
  }

  /// Respuesta basada en datos reales de Firebase cuando la API Key no responde o está offline
  static String _responderFallbackConFirebase(
    String mensaje,
    ContextoClienteChatbot ctx,
  ) {
    final m = mensaje.toLowerCase();

    // 1. Consulta sobre la tienda o el emprendedor / dueño
    if (m.contains('tienda') ||
        m.contains('negocio') ||
        m.contains('dueño') ||
        m.contains('dueno') ||
        m.contains('propietario') ||
        m.contains('emprendedor') ||
        m.contains('quien')) {
      return '🏬 Nuestra tienda oficial es "${ctx.nombreTienda}", fundada y dirigida por el emprendedor ${ctx.nombreEmprendedor}. ¡Un gusto atenderte! ✨';
    }

    // 2. Consulta de saldo o deuda
    if (m.contains('saldo') ||
        m.contains('cuanto debo') ||
        m.contains('cuánto debo') ||
        m.contains('deuda') ||
        m.contains('total') ||
        m.contains('cuenta')) {
      if (ctx.saldoPendiente > 0) {
        return 'Hola ${ctx.nombre} 👋. Revisando tu cuenta en Firebase, tu saldo pendiente actual es de \$${ctx.saldoPendiente.toStringAsFixed(2)} (Total comprado: \$${ctx.totalComprado.toStringAsFixed(2)} y total abonado: \$${ctx.totalPagado.toStringAsFixed(2)}) 🛍️✨.';
      } else {
        return '¡Hola ${ctx.nombre}! 🎉 Actualmente no tienes saldo pendiente en Firebase, ¡estás completamente al día con tus compras! 🛍️';
      }
    }

    // 3. Consulta de ubicación / dónde se encuentran
    if (m.contains('donde') ||
        m.contains('dónde') ||
        m.contains('ubicacion') ||
        m.contains('ubicación') ||
        m.contains('encuentran') ||
        m.contains('local') ||
        m.contains('direccion') ||
        m.contains('dirección')) {
      return '📍 Nuestra tienda física "${ctx.nombreTienda}" se encuentra ubicada en:\n\n${ctx.direccionTienda}\n\n¡Puedes visitarnos para retirar tus prendas apartadas en las transmisiones en vivo! ✨👗';
    }

    // 4. Consulta de catálogo / prendas disponibles
    if (m.contains('catalogo') ||
        m.contains('catálogo') ||
        m.contains('prendas tienen') ||
        m.contains('ropa tienen') ||
        m.contains('que venden') ||
        m.contains('qué venden') ||
        m.contains('disponibles')) {
      if (ctx.catalogoPrendas.isNotEmpty) {
        final lista = ctx.catalogoPrendas.take(6).join('\n• ');
        return '👗 Prendas disponibles en "${ctx.nombreTienda}":\n\n• $lista\n\n¡Coméntalas en el próximo live para apartarlas!';
      }
    }

    // 5. Consulta de prendas apartadas del cliente
    if (m.contains('prenda') || m.contains('ropa') || m.contains('apartada') || m.contains('compras')) {
      if (ctx.totalPrendas > 0) {
        final detalle = ctx.ultimasPrendas.isNotEmpty ? '\n\nÚltimas prendas apartadas:\n• ${ctx.ultimasPrendas.join('\n• ')}' : '';
        return '📦 Tienes un total de ${ctx.totalPrendas} prenda(s) apartada(s) en tu cuenta.$detalle\n\nPuedes ver el desglose completo en la pestaña "Compras" de la app.';
      } else {
        return '📦 Aún no tienes prendas apartadas en tu cuenta. ¡Conéctate a la próxima transmisión en vivo de "${ctx.nombreTienda}" para apartar tus prendas favoritas! 👗✨';
      }
    }

    // 6. Consulta de cómo apartar en Live
    if (m.contains('apartar') || m.contains('live') || m.contains('comprar') || m.contains('pedido')) {
      return '🛍️ Para apartar prendas en "${ctx.nombreTienda}" es muy sencillo:\n\n1. Conéctate a las transmisiones en vivo en TikTok o Facebook Live.\n2. Cuando muestren una prenda de tu agrado, coméntalo en el chat en vivo.\n3. El secretario registrará la prenda a tu nombre en Vendix y verás tu saldo reflejado al instante en esta app ✨.';
    }

    // Respuesta general amable
    return '¡Hola ${ctx.nombre}! 👋 Soy el Asistente Vendix de "${ctx.nombreTienda}" (${ctx.nombreEmprendedor}). Puedo informarte tu saldo pendiente (\$${ctx.saldoPendiente.toStringAsFixed(2)}), nuestro catálogo de prendas, decirte dónde queda nuestra tienda física (${ctx.direccionTienda}) o cómo apartar en los lives.';
  }

  /// Limpia la sesión del chat al cerrar el modal o la sesión
  static void reiniciarSesion() {
    _chatSession = null;
    _modelo = null;
    _ultimoSystemPrompt = null;
  }
}
