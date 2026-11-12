import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Modelo de datos que encapsula el contexto real del cliente obtenido de Firebase
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
  final String direccionTienda;
  final String telefonoTienda;

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
    required this.direccionTienda,
    required this.telefonoTienda,
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
      nombreTienda: 'Vendix Store',
      direccionTienda: 'Dirección física pendiente de configuración',
      telefonoTienda: '',
    );
  }
}

/// Servicio que integra Firebase Firestore con Google Gemini API
class GeminiService {
  GeminiService._();

  /// Clave de API de Google Gemini (generada gratis en https://aistudio.google.com/)
  /// Puedes definirla aquí o pasarla en tiempo de compilación con:
  /// flutter run --dart-define=GEMINI_API_KEY=tu_api_key
  static String apiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'TU_GEMINI_API_KEY_AQUI',
  );

  /// Modelo de Gemini a utilizar (1.5 Flash es rápido, moderno y cuenta con cuota gratuita)
  static const String modeloGemini = 'gemini-1.5-flash';

  static GenerativeModel? _modelo;
  static ChatSession? _chatSession;
  static String? _ultimoSystemPrompt;

  /// Obtiene de Firebase toda la información relevante del cliente actual
  static Future<ContextoClienteChatbot> obtenerContextoCliente() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return ContextoClienteChatbot.vacio();
    }

    final db = FirebaseFirestore.instance;
    final uid = authUser.uid;

    try {
      // 1. Buscar en la colección 'clientes' por UID
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
        // Fallback a la colección 'usuarios'
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
      final adminId = (dataCliente?['adminId'] ?? '').toString();

      // 2. Consultar compras del cliente
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

          final nombrePrenda = (data['prendaNombre'] ?? '').toString();
          if (nombrePrenda.isNotEmpty && ultimasPrendas.length < 4) {
            ultimasPrendas.add('$nombrePrenda (x$cantidad, \$${subtotal.toStringAsFixed(2)})');
          }
        }
      }

      // 3. Consultar pagos del cliente
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

      // 4. Consultar datos de la tienda y su ubicación física
      String nombreTienda = 'Moda Luna Showroom / Vendix';
      String direccionTienda = 'Calle 10 de Agosto y Guayaquil, Riobamba, Ecuador';
      String telefonoTienda = '';

      if (dataCliente?['direccionTienda'] != null &&
          dataCliente!['direccionTienda'].toString().trim().isNotEmpty) {
        direccionTienda = dataCliente['direccionTienda'].toString().trim();
      }

      if (adminId.isNotEmpty) {
        try {
          final snapAdmin = await db.collection('Administradores').doc(adminId).get();
          if (snapAdmin.exists) {
            final dataAdmin = snapAdmin.data();
            if (dataAdmin != null) {
              if (dataAdmin['negocio'] != null && dataAdmin['negocio'].toString().isNotEmpty) {
                nombreTienda = dataAdmin['negocio'].toString();
              } else if (dataAdmin['nombre'] != null) {
                nombreTienda = dataAdmin['nombre'].toString();
              }
              if (dataAdmin['direccion'] != null && dataAdmin['direccion'].toString().isNotEmpty) {
                direccionTienda = dataAdmin['direccion'].toString();
              }
              if (dataAdmin['telefono'] != null) {
                telefonoTienda = dataAdmin['telefono'].toString();
              }
            }
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
        direccionTienda: direccionTienda,
        telefonoTienda: telefonoTienda,
      );
    } catch (_) {
      return ContextoClienteChatbot.vacio();
    }
  }

  /// Construye el Prompt de Sistema inyectando los datos vivos de Firebase
  static String _construirSystemPrompt(ContextoClienteChatbot ctx) {
    return '''
Eres el asistente virtual oficial de compras de la tienda "${ctx.nombreTienda}" en la aplicación VENDIX.
Tu misión es atender exclusivamente al cliente que ha iniciado sesión, respondiendo siempre con amabilidad, claridad y precisión basándote en su información real de Firebase:

=== INFORMACIÓN REAL DEL CLIENTE EN FIREBASE ===
- Nombre del cliente: ${ctx.nombre}
- Teléfono: ${ctx.telefono.isNotEmpty ? ctx.telefono : 'No registrado'}
- Saldo pendiente por pagar: \$${ctx.saldoPendiente.toStringAsFixed(2)}
- Total comprado históricamente: \$${ctx.totalComprado.toStringAsFixed(2)}
- Total abonado / pagado: \$${ctx.totalPagado.toStringAsFixed(2)}
- Prendas apartadas en total: ${ctx.totalPrendas} prendas
- Últimas prendas registradas: ${ctx.ultimasPrendas.isEmpty ? 'Aún no registra compras recientes' : ctx.ultimasPrendas.join('; ')}
- Código de transmisión en vivo (Live): ${ctx.codigoLive.isNotEmpty ? ctx.codigoLive : 'Sin código asignado'}

=== UBICACIÓN DE LA TIENDA FÍSICA ===
- Nombre del negocio: ${ctx.nombreTienda}
- Dirección física de la tienda: ${ctx.direccionTienda}
- Teléfono de contacto / atención: ${ctx.telefonoTienda.isNotEmpty ? ctx.telefonoTienda : 'Directamente por esta app'}

=== REGLAS ESTRICTAS DE RESPUESTA ===
1. Si el cliente pregunta por su saldo, deuda o cuánto tiene que pagar, dale exactamente su saldo pendiente actual (\$${ctx.saldoPendiente.toStringAsFixed(2)}). Si es \$0.00, felicítalo amablemente por estar al día.
2. Si el cliente pregunta "¿Dónde se encuentran?", "¿Dónde queda la tienda?", su ubicación física o cómo retirar sus prendas, dale la dirección física exacta: "${ctx.direccionTienda}". Menciónale que pueden visitarnos para retirar sus prendas o coordinar entregas.
3. NO menciones medios de pago automáticos ni pasarelas de pago no autorizadas. Si pregunta cómo pagar, indícale que los abonos se coordinan directamente con la tienda o se registran en el local físico.
4. Si el cliente pregunta cómo apartar durante el Live de TikTok o Facebook, explícale que cuando la emprendedora muestre la prenda en la transmisión, solo debe comentar en el live y la secretaria encargada la registrará en tiempo real a su nombre en esta app.
5. Si pregunta por sus prendas apartadas, menciónale el total (${ctx.totalPrendas} prendas) y las últimas registradas: ${ctx.ultimasPrendas.join(', ')}.
6. Sé siempre cordial, educado y conciso. Emplea un tono cercano y emojis adecuados de moda y compras (🛍️, ✨, 📍, 👗, 🏷️).
''';
  }

  /// Envía un mensaje a la API de Gemini (con fallback inteligente a Firebase si la API Key no está configurada)
  static Future<String> enviarMensaje({
    required String mensaje,
    required ContextoClienteChatbot contexto,
  }) async {
    final mensajeLimpio = mensaje.trim();
    if (mensajeLimpio.isEmpty) return '';

    // Si no se ha configurado la clave de Gemini, respondemos con los datos directos de Firebase
    if (apiKey.isEmpty || apiKey == 'TU_GEMINI_API_KEY_AQUI') {
      return _responderFallbackConFirebase(mensajeLimpio, contexto);
    }

    try {
      final systemPrompt = _construirSystemPrompt(contexto);

      // Si el prompt cambió o el modelo no está inicializado, creamos una nueva sesión
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
      // Si ocurre un error con la API (cuota, red, etc.), respondemos con la información de Firebase
      return _responderFallbackConFirebase(mensajeLimpio, contexto);
    }
  }

  /// Respuesta basada en datos reales de Firebase cuando la API Key está pendiente
  static String _responderFallbackConFirebase(
    String mensaje,
    ContextoClienteChatbot ctx,
  ) {
    final m = mensaje.toLowerCase();

    // 1. Consulta de saldo o deuda
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

    // 2. Consulta de ubicación / dónde se encuentran
    if (m.contains('donde') ||
        m.contains('dónde') ||
        m.contains('ubicacion') ||
        m.contains('ubicación') ||
        m.contains('encuentran') ||
        m.contains('tienda') ||
        m.contains('local') ||
        m.contains('direccion') ||
        m.contains('dirección')) {
      return '📍 Nuestra tienda física "${ctx.nombreTienda}" se encuentra ubicada en:\n\n${ctx.direccionTienda}\n\n¡Puedes visitarnos para retirar tus prendas apartadas en las transmisiones en vivo! ✨👗';
    }

    // 3. Consulta de cómo apartar en Live
    if (m.contains('apartar') || m.contains('live') || m.contains('comprar') || m.contains('pedido')) {
      return '🛍️ Para apartar prendas es muy sencillo:\n\n1. Conéctate a las transmisiones en vivo en TikTok o Facebook Live.\n2. Cuando la vendedora muestre una prenda de tu agrado, coméntalo en el chat en vivo.\n3. La secretaria registrará la prenda a tu nombre en Vendix y verás tu saldo reflejado al instante en esta app ✨.';
    }

    // 4. Consulta de prendas apartadas
    if (m.contains('prenda') || m.contains('ropa') || m.contains('apartada') || m.contains('compras')) {
      if (ctx.totalPrendas > 0) {
        final detalle = ctx.ultimasPrendas.isNotEmpty ? '\n\nÚltimas prendas:\n• ${ctx.ultimasPrendas.join('\n• ')}' : '';
        return '📦 Tienes un total de ${ctx.totalPrendas} prenda(s) apartada(s) en tu cuenta.$detalle\n\nPuedes ver el desglose completo en la pestaña "Compras" de la app.';
      } else {
        return '📦 Aún no tienes prendas apartadas en tu cuenta. ¡Conéctate a la próxima transmisión en vivo para apartar tus prendas favoritas! 👗✨';
      }
    }

    // Respuesta general amable
    return '¡Hola ${ctx.nombre}! 👋 Soy el Asistente Vendix de "${ctx.nombreTienda}". Puedo informarte tu saldo pendiente (\$${ctx.saldoPendiente.toStringAsFixed(2)}), decirte dónde queda nuestra tienda física (${ctx.direccionTienda}) o explicarte cómo apartar prendas en las transmisiones en vivo.';
  }

  /// Limpia la sesión del chat al cerrar el modal o la sesión
  static void reiniciarSesion() {
    _chatSession = null;
    _modelo = null;
    _ultimoSystemPrompt = null;
  }
}
