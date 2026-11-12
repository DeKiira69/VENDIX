import 'package:flutter/material.dart';

/// Modelo de datos simulados para los mensajes del chat
class ChatMessageMock {
  final String text;
  final bool isUser;
  final String time;

  const ChatMessageMock({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

/// Botón Flotante (FAB) estilizado para abrir el Asistente Virtual
class ClientChatbotFAB extends StatelessWidget {
  const ClientChatbotFAB({super.key});

  static const Color violetaPrincipal = Color(0xFF6C4AB6);
  static const Color violetaClaro = Color(0xFF9A69C6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [violetaPrincipal, violetaClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: violetaPrincipal.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => ClientChatbotSheet.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF15966B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Text(
                  'Asistente Vendix',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom Sheet modal interactivo del Chatbot para Clientes
class ClientChatbotSheet extends StatefulWidget {
  const ClientChatbotSheet({super.key});

  /// Método estático auxiliar para abrir el modal con las dimensiones y diseño solicitados
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const ClientChatbotSheet(),
    );
  }

  @override
  State<ClientChatbotSheet> createState() => _ClientChatbotSheetState();
}

class _ClientChatbotSheetState extends State<ClientChatbotSheet> {
  static const Color violeta = Color(0xFF6C4AB6);
  static const Color violetaGradiente = Color(0xFF8B5CF6);
  static const Color rosa = Color(0xFFE9A6C8);
  static const Color oscuro = Color(0xFF241B35);
  static const Color fondoGris = Color(0xFFF7F5FA);
  static const Color bordeColor = Color(0xFFEBE5F2);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _puedeEnviar = false;

  /// Lista de mensajes simulados (Mockups) contextualizados en compras de Vendix
  final List<ChatMessageMock> _mensajes = [
    const ChatMessageMock(
      text: '¡Hola! 👋 Soy tu Asistente de Compras en Vivo Vendix.',
      isUser: false,
      time: 'Ahora',
    ),
    const ChatMessageMock(
      text: 'Puedo ayudarte a revisar tu saldo, entender cómo apartar prendas durante el live o resolver dudas sobre tus pedidos.',
      isUser: false,
      time: 'Ahora',
    ),
    const ChatMessageMock(
      text: '¿Cómo sé si la secretaria ya anotó mi prenda apartada?',
      isUser: true,
      time: '10:42 AM',
    ),
    const ChatMessageMock(
      text: '¡En tiempo real! En cuanto la secretaria confirme tu compra en la transmisión, se sumará automáticamente a tu pestaña "Saldo" y "Compras" de esta app ✨.',
      isUser: false,
      time: '10:43 AM',
    ),
  ];

  /// Sugerencias rápidas (Chips) para preguntas frecuentes
  final List<String> _sugerencias = [
    '💰 ¿Cuál es mi saldo?',
    '🛍️ ¿Cómo apartar en Live?',
    '💳 Medios de pago',
    '📦 Estado de envío',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final tieneTexto = _textController.text.trim().isNotEmpty;
      if (tieneTexto != _puedeEnviar) {
        setState(() => _puedeEnviar = tieneTexto);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviarMensaje([String? textoOpcional]) {
    final texto = (textoOpcional ?? _textController.text).trim();
    if (texto.isEmpty) return;

    final ahora = DateTime.now();
    final hora = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

    setState(() {
      _mensajes.add(
        ChatMessageMock(
          text: texto,
          isUser: true,
          time: hora,
        ),
      );
      if (textoOpcional == null) {
        _textController.clear();
        _puedeEnviar = false;
      }
    });

    _scrollAlFinal();

    // Simulación de respuesta automática del bot (Mockup UI)
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _mensajes.add(
          ChatMessageMock(
            text: '¡Mensaje recibido! 🤖 Esta es una simulación visual de la interfaz. En la siguiente etapa me conectaré con la IA para responderte en tiempo real.',
            isUser: false,
            time: hora,
          ),
        );
      });
      _scrollAlFinal();
    });
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // El modal ocupa entre el 75% y el 80% de la altura total de la pantalla
    final alturaDeseada = mediaQuery.size.height * 0.78;
    final paddingTeclado = mediaQuery.viewInsets.bottom;

    return Container(
      height: alturaDeseada,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32), // Bordes redondeados pronunciados estilo premium
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false, // Control manual para suavidad perfecta
          body: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: paddingTeclado),
              child: Column(
                children: [
                  // 1. Barra de arrastre (Drag handle)
                  _buildDragHandle(),

                  // 2. Header moderno y limpio
                  _buildHeader(context),

                  const Divider(height: 1, thickness: 1, color: bordeColor),

                  // 3. Área de historial de chat
                  Expanded(
                    child: Container(
                      color: fondoGris,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _mensajes.length,
                        itemBuilder: (context, index) {
                          final mensaje = _mensajes[index];
                          return _buildBurbuja(mensaje);
                        },
                      ),
                    ),
                  ),

                  // 4. Barra de sugerencias rápidas (Chips)
                  _buildSugerencias(),

                  // 5. Input de texto fijo inferior con botón de envío
                  _buildInputArea(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 44,
        height: 4.5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Row(
        children: [
          // Avatar con degradado e indicador activo
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [violeta, rosa],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: violeta.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF15966B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Títulos del Bot
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente Vendix',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: oscuro,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'En línea • Soporte para tus compras',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF15966B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Botón cerrar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF5E546C)),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              tooltip: 'Cerrar chat',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurbuja(ChatMessageMock mensaje) {
    final esUsuario = mensaje.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esUsuario) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE8FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: violeta,
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: esUsuario
                    ? const LinearGradient(
                        colors: [violeta, violetaGradiente],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: esUsuario ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(esUsuario ? 20 : 4),
                  bottomRight: Radius.circular(esUsuario ? 4 : 20),
                ),
                border: esUsuario ? null : Border.all(color: bordeColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: esUsuario
                        ? violeta.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    mensaje.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: esUsuario ? Colors.white : oscuro,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    mensaje.time,
                    style: TextStyle(
                      fontSize: 10,
                      color: esUsuario
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF9B92A7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugerencias() {
    return Container(
      color: fondoGris,
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sugerencias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sugerencia = _sugerencias[index];
          return ActionChip(
            label: Text(
              sugerencia,
              style: const TextStyle(
                fontSize: 12,
                color: violeta,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            pressElevation: 1,
            side: const BorderSide(color: Color(0xFFE4DAEE), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onPressed: () => _enviarMensaje(sugerencia),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: bordeColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFECE6F2)),
              ),
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviarMensaje(),
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta o duda...',
                  hintStyle: TextStyle(
                    color: Color(0xFFA197AF),
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _puedeEnviar
                  ? const LinearGradient(
                      colors: [violeta, violetaGradiente],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade300],
                    ),
              boxShadow: _puedeEnviar
                  ? [
                      BoxShadow(
                        color: violeta.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
                onPressed: _puedeEnviar ? () => _enviarMensaje() : null,
                tooltip: 'Enviar mensaje',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
