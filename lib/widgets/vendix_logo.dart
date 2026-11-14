import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget que renderiza y anima el isotipo y marca VENDIX con fidelidad 1:1
/// respecto a la identidad visual oficial a 60/120 FPS nativos.
class VendixLogo extends StatefulWidget {
  /// Tamaño del isotipo cuadrado (por defecto 145 para Splash, 72 para cabeceras).
  final double size;

  /// Si es true, renderiza abajo la tipografía VENDIX con degradado a juego.
  final bool showText;

  /// Tamaño de fuente para la marca VENDIX (por defecto 34).
  final double fontSize;

  /// Espaciado vertical entre el isotipo y el texto (por defecto 28).
  final double spacing;

  /// Si es true, reproduce la secuencia de entrada inicial (trazado, revelación).
  final bool animateEntrance;

  /// Si es true, mantiene la flotación continua, balanceo y pulso.
  final bool continuousLoop;

  /// Callback opcional disparado cuando la animación de entrada termina.
  final VoidCallback? onEntranceEnd;

  const VendixLogo({
    super.key,
    this.size = 145,
    this.showText = true,
    this.fontSize = 34,
    this.spacing = 28,
    this.animateEntrance = true,
    this.continuousLoop = true,
    this.onEntranceEnd,
  });

  @override
  State<VendixLogo> createState() => _VendixLogoState();
}

class _VendixLogoState extends State<VendixLogo> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _loopController;

  // Animaciones de Entrada (0.0s a 1.25s)
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoTranslateY;

  late final Animation<double> _bagStrokeProgress;
  late final Animation<double> _handleStrokeProgress;

  late final Animation<double> _textOpacity;
  late final Animation<double> _textTranslateY;

  // Animaciones de Bucle Continuo (3.4s)
  late final Animation<double> _logoFloatY;
  late final Animation<double> _bagSwayAngle;
  late final Animation<double> _bagPulseScale;

  @override
  void initState() {
    super.initState();

    // 1. Controlador de Entrada: 1250ms
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    // 2. Controlador de Bucle: 3400ms
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    _configurarAnimacionesEntrada();
    _configurarAnimacionesBucle();

    if (widget.animateEntrance) {
      _entranceController.forward().then((_) {
        widget.onEntranceEnd?.call();
        if (mounted && widget.continuousLoop) {
          _loopController.repeat();
        }
      });
    } else {
      _entranceController.value = 1.0;
      if (widget.continuousLoop) {
        _loopController.repeat();
      }
    }
  }

  void _configurarAnimacionesEntrada() {
    const bezierEaseOut = Cubic(0.22, 1.0, 0.36, 1.0);
    const bezierStroke = Cubic(0.33, 1.0, 0.68, 1.0);

    // logoEntrance: 0s a 0.9s (0.0 -> 0.72)
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.72, curve: bezierEaseOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.72, curve: bezierEaseOut),
      ),
    );
    _logoTranslateY = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.72, curve: bezierEaseOut),
      ),
    );

    // bag-stroke: delay 0.2s, dur 0.85s (0.16 -> 0.84)
    _bagStrokeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.16, 0.84, curve: bezierStroke),
      ),
    );

    // handle-stroke: delay 0.4s, dur 0.6s (0.32 -> 0.80)
    _handleStrokeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.32, 0.80, curve: bezierStroke),
      ),
    );

    // textReveal: delay 0.7s, dur 0.75s (0.56 -> 1.0)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.56, 1.0, curve: bezierEaseOut),
      ),
    );
    _textTranslateY = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.56, 1.0, curve: bezierEaseOut),
      ),
    );
  }

  void _configurarAnimacionesBucle() {
    // logoFloat: flotación vertical senoidal 0s -> -7px -> 0s
    _logoFloatY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -7.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -7.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(_loopController);

    // bagSway: sutil balanceo de rotación (-2° a 2°)
    _bagSwayAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -2.0 * (math.pi / 180.0))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -2.0 * (math.pi / 180.0), end: 2.0 * (math.pi / 180.0))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.0 * (math.pi / 180.0), end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
    ]).animate(_loopController);

    // bagPulse: sutil respiración orgánica del icono central
    _bagPulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(_loopController);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _loopController]),
      builder: (context, _) {
        final entranceDone = _entranceController.value >= 1.0;

        final opacity = widget.animateEntrance ? _logoOpacity.value : 1.0;
        final scale = widget.animateEntrance ? _logoScale.value : 1.0;
        final floatY = (widget.continuousLoop && entranceDone) ? _logoFloatY.value : 0.0;
        final entranceY = widget.animateEntrance ? _logoTranslateY.value : 0.0;
        final totalTranslateY = entranceY + floatY;

        final bagProg = widget.animateEntrance ? _bagStrokeProgress.value : 1.0;
        final handleProg = widget.animateEntrance ? _handleStrokeProgress.value : 1.0;

        final swayRot = (widget.continuousLoop && entranceDone) ? _bagSwayAngle.value : 0.0;
        final pulseScale = (widget.continuousLoop && entranceDone) ? _bagPulseScale.value : 1.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Isotipo
            Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, totalTranslateY),
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CustomPaint(
                      painter: VendixLogoPainter(
                        bagProgress: bagProg,
                        handleProgress: handleProg,
                        iconRotation: swayRot,
                        iconScale: pulseScale,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Tipografía VENDIX
            if (widget.showText) ...[
              SizedBox(height: widget.spacing),
              Opacity(
                opacity: (widget.animateEntrance ? _textOpacity.value : 1.0).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    widget.animateEntrance ? _textTranslateY.value : 0.0,
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFF6C4AB6),
                          Color(0xFF9E54E8),
                          Color(0xFFE9A6C8),
                        ],
                        stops: [0.0, 0.55, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      'VENDIX',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: widget.fontSize * 0.18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// CustomPainter que dibuja el isotipo canónico de VENDIX en resolución 200x200
class VendixLogoPainter extends CustomPainter {
  final double bagProgress;
  final double handleProgress;
  final double iconRotation;
  final double iconScale;

  // Cache estática de paths para evitar recreación de geometría cada frame
  static Path? _cachedHandlePath;
  static Path? _cachedBagPath;

  VendixLogoPainter({
    required this.bagProgress,
    required this.handleProgress,
    this.iconRotation = 0.0,
    this.iconScale = 1.0,
  });

  static Path _getHandlePath() {
    if (_cachedHandlePath != null) return _cachedHandlePath!;
    final path = Path();
    // Asa centrada en 200x200 (x: 82 a 118, y: 68 a 88, radio superior: 18)
    path.moveTo(85, 88);
    path.lineTo(85, 82);
    path.cubicTo(85, 72.5, 91.5, 66, 100, 66);
    path.cubicTo(108.5, 66, 115, 72.5, 115, 82);
    path.lineTo(115, 88);
    _cachedHandlePath = path;
    return path;
  }

  static Path _getBagPath() {
    if (_cachedBagPath != null) return _cachedBagPath!;
    final path = Path();
    // Cuerpo de la bolsa rectangular redondeada centrada en 200x200:
    // Left: 68, Right: 132, Top: 88, Bottom: 144. Radius: 8
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(68, 88, 64, 56),
      const Radius.circular(9),
    );
    path.addRRect(rect);
    _cachedBagPath = path;
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.scale(scale, scale);

    _drawBackgroundSquircle(canvas);

    // Animación de rotación y pulso del icono de la bolsa sobre su centro (100, 105)
    canvas.save();
    canvas.translate(100, 105);
    canvas.rotate(iconRotation);
    canvas.scale(iconScale, iconScale);
    canvas.translate(-100, -105);

    _drawHandle(canvas);
    _drawBag(canvas);

    canvas.restore();
    canvas.restore();
  }

  void _drawBackgroundSquircle(Canvas canvas) {
    final rect = Rect.fromLTWH(20, 20, 160, 160);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(52));

    // Sombra suave fiel al diseño [0, 12, blur: 18, color: #6C4AB6 28%]
    final shadowPaint = Paint()
      ..color = const Color(0xFF6C4AB6).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.save();
    canvas.translate(0, 10);
    canvas.drawRRect(rrect, shadowPaint);
    canvas.restore();

    // Degradado oficial: violeta (#6C4AB6) -> rosa (#E9A6C8) en ángulo de 135°
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(25, 20),
        const Offset(175, 180),
        const [
          Color(0xFF6C4AB6),
          Color(0xFF8B64C8),
          Color(0xFFE9A6C8),
        ],
        const [0.0, 0.45, 1.0],
      );

    canvas.drawRRect(rrect, bgPaint);
  }

  void _drawHandle(Canvas canvas) {
    if (handleProgress <= 0.0) return;

    final fullPath = _getHandlePath();
    final path = Path();

    if (handleProgress >= 1.0) {
      path.addPath(fullPath, Offset.zero);
    } else {
      for (final metric in fullPath.computeMetrics()) {
        final extractLen = metric.length * handleProgress;
        path.addPath(metric.extractPath(0.0, extractLen), Offset.zero);
      }
    }

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  void _drawBag(Canvas canvas) {
    if (bagProgress <= 0.0) return;

    final fullPath = _getBagPath();
    final path = Path();

    if (bagProgress >= 1.0) {
      path.addPath(fullPath, Offset.zero);
    } else {
      for (final metric in fullPath.computeMetrics()) {
        final extractLen = metric.length * bagProgress;
        path.addPath(metric.extractPath(0.0, extractLen), Offset.zero);
      }
    }

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant VendixLogoPainter oldDelegate) {
    return oldDelegate.bagProgress != bagProgress ||
        oldDelegate.handleProgress != handleProgress ||
        oldDelegate.iconRotation != iconRotation ||
        oldDelegate.iconScale != iconScale;
  }
}
