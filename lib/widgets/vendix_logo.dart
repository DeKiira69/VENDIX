import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget que renderiza y anima el isotipo y marca VENDIX con fidelidad 1:1
/// respecto a la especificación vectorial SVG/HTML a 60/120 FPS nativos.
class VendixLogo extends StatefulWidget {
  /// Tamaño del isotipo cuadrado (por defecto 145 según CSS `.logo-wrapper`).
  final double size;

  /// Si es true, renderiza abajo la tipografía VENDIX con degradado a juego.
  final bool showText;

  /// Tamaño de fuente para la marca VENDIX (por defecto 34).
  final double fontSize;

  /// Espaciado vertical entre el isotipo y el texto (por defecto 28).
  final double spacing;

  /// Si es true, reproduce la secuencia de entrada inicial (trazado, revelación).
  final bool animateEntrance;

  /// Si es true, mantiene la flotación continua, balanceo de órbita y pulso de barras.
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

  late final Animation<double> _swooshOpacity;
  late final Animation<double> _swooshScale;
  late final Animation<double> _swooshRotation;

  late final Animation<double> _bar1Growth;
  late final Animation<double> _bar2Growth;
  late final Animation<double> _bar3Growth;

  late final Animation<double> _textOpacity;
  late final Animation<double> _textTranslateY;

  // Animaciones de Bucle Continuo (3.4s)
  late final Animation<double> _logoFloatY;
  late final Animation<double> _swooshSwayAngle;
  late final Animation<double> _swooshSwayScale;
  late final Animation<double> _bar1Pulse;
  late final Animation<double> _bar2Pulse;
  late final Animation<double> _bar3Pulse;

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
    // Curva cúbica principal: cubic-bezier(0.22, 1, 0.36, 1)
    const bezierEaseOut = Cubic(0.22, 1.0, 0.36, 1.0);
    // Curva dibujo de trazo: cubic-bezier(0.33, 1, 0.68, 1)
    const bezierStroke = Cubic(0.33, 1.0, 0.68, 1.0);
    // Curva rebote suave barras: cubic-bezier(0.34, 1.56, 0.64, 1)
    const bezierBounce = Cubic(0.34, 1.56, 0.64, 1.0);

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

    // swooshReveal: delay 0.5s, dur 0.75s (0.40 -> 1.0)
    _swooshOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 1.0, curve: bezierEaseOut),
      ),
    );
    _swooshScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 1.0, curve: bezierEaseOut),
      ),
    );
    _swooshRotation = Tween<double>(begin: -6.0 * (math.pi / 180.0), end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 1.0, curve: bezierEaseOut),
      ),
    );

    // Barras: barGrow 0.4s (delays 0.7s, 0.8s, 0.9s -> 0.56, 0.64, 0.72 hasta 0.88, 0.96, 1.0)
    _bar1Growth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.56, 0.88, curve: bezierBounce),
      ),
    );
    _bar2Growth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.64, 0.96, curve: bezierBounce),
      ),
    );
    _bar3Growth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.72, 1.0, curve: bezierBounce),
      ),
    );

    // textReveal: delay 0.8s, dur 0.75s (0.64 -> 1.0)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.64, 1.0, curve: bezierEaseOut),
      ),
    );
    _textTranslateY = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.64, 1.0, curve: bezierEaseOut),
      ),
    );
  }

  void _configurarAnimacionesBucle() {
    // logoFloat: 0s -> -7px -> 0s
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

    // swooshSway: 0deg, scale 1.0 -> -2.5deg, scale 1.015 -> 0deg, scale 1.0
    _swooshSwayAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -2.5 * (math.pi / 180.0))
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -2.5 * (math.pi / 180.0), end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(_loopController);

    _swooshSwayScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.015).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.015, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(_loopController);

    // barPulse con desfase orgánico senoidal continuo: scaleY 1.0 -> 0.72 -> 1.0
    _bar1Pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.72).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _loopController,
        curve: const Interval(0.0, 0.75, curve: Curves.linear),
      ),
    );

    _bar2Pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.72).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _loopController,
        curve: const Interval(0.12, 0.87, curve: Curves.linear),
      ),
    );

    _bar3Pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.72).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _loopController,
        curve: const Interval(0.24, 0.99, curve: Curves.linear),
      ),
    );
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

        // Cálculos acumulados de transformación
        final opacity = widget.animateEntrance ? _logoOpacity.value : 1.0;
        final scale = widget.animateEntrance ? _logoScale.value : 1.0;
        final floatY = (widget.continuousLoop && entranceDone) ? _logoFloatY.value : 0.0;
        final entranceY = widget.animateEntrance ? _logoTranslateY.value : 0.0;
        final totalTranslateY = entranceY + floatY;

        // Trazado progresivo
        final bagProg = widget.animateEntrance ? _bagStrokeProgress.value : 1.0;
        final handleProg = widget.animateEntrance ? _handleStrokeProgress.value : 1.0;

        // Órbita
        final swooshOp = widget.animateEntrance ? _swooshOpacity.value : 1.0;
        final baseSwooshScale = widget.animateEntrance ? _swooshScale.value : 1.0;
        final baseSwooshRot = widget.animateEntrance ? _swooshRotation.value : 0.0;

        final swayScale = (widget.continuousLoop && entranceDone) ? _swooshSwayScale.value : 1.0;
        final swayRot = (widget.continuousLoop && entranceDone) ? _swooshSwayAngle.value : 0.0;

        final totalSwooshScale = baseSwooshScale * swayScale;
        final totalSwooshRot = baseSwooshRot + swayRot;

        // Barras
        final b1Grow = widget.animateEntrance ? _bar1Growth.value : 1.0;
        final b2Grow = widget.animateEntrance ? _bar2Growth.value : 1.0;
        final b3Grow = widget.animateEntrance ? _bar3Growth.value : 1.0;

        final b1Pulse = (widget.continuousLoop && entranceDone) ? _bar1Pulse.value : 1.0;
        final b2Pulse = (widget.continuousLoop && entranceDone) ? _bar2Pulse.value : 1.0;
        final b3Pulse = (widget.continuousLoop && entranceDone) ? _bar3Pulse.value : 1.0;

        final bar1HeightFactor = b1Grow * b1Pulse;
        final bar2HeightFactor = b2Grow * b2Pulse;
        final bar3HeightFactor = b3Grow * b3Pulse;

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
                        swooshOpacity: swooshOp,
                        swooshScale: totalSwooshScale,
                        swooshRotation: totalSwooshRot,
                        bar1ScaleY: bar1HeightFactor,
                        bar2ScaleY: bar2HeightFactor,
                        bar3ScaleY: bar3HeightFactor,
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
                          Color(0xFF6938EF),
                          Color(0xFF9E54E8),
                          Color(0xFFEC69B4),
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
  final double swooshOpacity;
  final double swooshScale;
  final double swooshRotation;
  final double bar1ScaleY;
  final double bar2ScaleY;
  final double bar3ScaleY;

  // Cache estática de paths para evitar recreación de geometría cada frame
  static Path? _cachedHandlePath;
  static Path? _cachedBagPath;
  static Path? _cachedSwooshPath;

  VendixLogoPainter({
    required this.bagProgress,
    required this.handleProgress,
    required this.swooshOpacity,
    required this.swooshScale,
    required this.swooshRotation,
    required this.bar1ScaleY,
    required this.bar2ScaleY,
    required this.bar3ScaleY,
  });

  static Path _getHandlePath() {
    if (_cachedHandlePath != null) return _cachedHandlePath!;
    final path = Path();
    // M80 74V62C80 50.9543 88.9543 42 100 42C111.046 42 120 50.9543 120 62V74
    path.moveTo(80, 74);
    path.lineTo(80, 62);
    path.cubicTo(80, 50.9543, 88.9543, 42, 100, 42);
    path.cubicTo(111.046, 42, 120, 50.9543, 120, 62);
    path.lineTo(120, 74);
    _cachedHandlePath = path;
    return path;
  }

  static Path _getBagPath() {
    if (_cachedBagPath != null) return _cachedBagPath!;
    final path = Path();
    // M66 74H134C138.971 74 143.138 77.775 143.621 82.722L149.121 139.022C149.687 144.819 145.134 149.8 139.309 149.8H60.691C54.866 149.8 50.313 144.819 50.879 139.022L56.379 82.722C56.862 77.775 61.029 74 66 74Z
    path.moveTo(66, 74);
    path.lineTo(134, 74);
    path.cubicTo(138.971, 74, 143.138, 77.775, 143.621, 82.722);
    path.lineTo(149.121, 139.022);
    path.cubicTo(149.687, 144.819, 145.134, 149.8, 139.309, 149.8);
    path.lineTo(60.691, 149.8);
    path.cubicTo(54.866, 149.8, 50.313, 144.819, 50.879, 139.022);
    path.lineTo(56.379, 82.722);
    path.cubicTo(56.862, 77.775, 61.029, 74, 66, 74);
    path.close();
    _cachedBagPath = path;
    return path;
  }

  static Path _getSwooshPath() {
    if (_cachedSwooshPath != null) return _cachedSwooshPath!;
    final path = Path();
    // M52 94C35 103 29 116 40 124C54 134 102 126 142 108C166 97 174 85 162 78C156 75 148 74 140 75C148 76 154 78 156 82C160 89 142 101 112 112C76 125 46 126 42 118C39 112 44 103 54 96L52 94Z
    path.moveTo(52, 94);
    path.cubicTo(35, 103, 29, 116, 40, 124);
    path.cubicTo(54, 134, 102, 126, 142, 108);
    path.cubicTo(166, 97, 174, 85, 162, 78);
    path.cubicTo(156, 75, 148, 74, 140, 75);
    path.cubicTo(148, 76, 154, 78, 156, 82);
    path.cubicTo(160, 89, 142, 101, 112, 112);
    path.cubicTo(76, 125, 46, 126, 42, 118);
    path.cubicTo(39, 112, 44, 103, 54, 96);
    path.close();
    _cachedSwooshPath = path;
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.scale(scale, scale);

    _drawBackgroundSquircle(canvas);
    _drawHandle(canvas);
    _drawBag(canvas);
    _drawBars(canvas);
    _drawSwoosh(canvas);

    canvas.restore();
  }

  void _drawBackgroundSquircle(Canvas canvas) {
    final rect = Rect.fromLTWH(20, 20, 160, 160);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(44));

    // Sombra suave fiel a feDropShadow dx="0" dy="12" stdDeviation="12" flood-color="#7C3AED" flood-opacity="0.18"
    final shadowPaint = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.save();
    canvas.translate(0, 12);
    canvas.drawRRect(rrect, shadowPaint);
    canvas.restore();

    // Degradado bgGrad: x1=25 y1=20 x2=175 y2=180
    // #6938EF -> #9E54E8 (55%) -> #F285C1 (100%)
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(25, 20),
        const Offset(175, 180),
        const [
          Color(0xFF6938EF),
          Color(0xFF9E54E8),
          Color(0xFFF285C1),
        ],
        const [0.0, 0.55, 1.0],
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
      ..strokeWidth = 7.5
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
      ..strokeWidth = 7.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  void _drawBars(Canvas canvas) {
    final barPaint = Paint()..color = Colors.white;

    // Bar 1: x:108, y:128, w:5.5, h:9, rx:2.75. Base y = 137
    if (bar1ScaleY > 0.0) {
      final h = 9.0 * bar1ScaleY;
      final y = 137.0 - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(108, y, 5.5, h),
          const Radius.circular(2.75),
        ),
        barPaint,
      );
    }

    // Bar 2: x:118, y:121, w:5.5, h:16, rx:2.75. Base y = 137
    if (bar2ScaleY > 0.0) {
      final h = 16.0 * bar2ScaleY;
      final y = 137.0 - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(118, y, 5.5, h),
          const Radius.circular(2.75),
        ),
        barPaint,
      );
    }

    // Bar 3: x:128, y:114, w:5.5, h:23, rx:2.75. Base y = 137
    if (bar3ScaleY > 0.0) {
      final h = 23.0 * bar3ScaleY;
      final y = 137.0 - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(128, y, 5.5, h),
          const Radius.circular(2.75),
        ),
        barPaint,
      );
    }
  }

  void _drawSwoosh(Canvas canvas) {
    if (swooshOpacity <= 0.0) return;

    final path = _getSwooshPath();

    canvas.save();
    // transform-origin: 100px 105px
    canvas.translate(100, 105);
    canvas.rotate(swooshRotation);
    canvas.scale(swooshScale, swooshScale);
    canvas.translate(-100, -105);

    // swooshGrad: x1=30 y1=115 x2=170 y2=90
    // #FFFFFF (0.85) -> #FFFFFF (1.0) -> #F5D0FE (0.90)
    final swooshPaint = Paint()
      ..color = Colors.white.withValues(alpha: swooshOpacity.clamp(0.0, 1.0))
      ..shader = ui.Gradient.linear(
        const Offset(30, 115),
        const Offset(170, 90),
        [
          const Color(0xFFFFFFFF).withValues(alpha: 0.85 * swooshOpacity),
          const Color(0xFFFFFFFF).withValues(alpha: 1.0 * swooshOpacity),
          const Color(0xFFF5D0FE).withValues(alpha: 0.90 * swooshOpacity),
        ],
        const [0.0, 0.5, 1.0],
      );

    canvas.drawPath(path, swooshPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VendixLogoPainter oldDelegate) {
    return oldDelegate.bagProgress != bagProgress ||
        oldDelegate.handleProgress != handleProgress ||
        oldDelegate.swooshOpacity != swooshOpacity ||
        oldDelegate.swooshScale != swooshScale ||
        oldDelegate.swooshRotation != swooshRotation ||
        oldDelegate.bar1ScaleY != bar1ScaleY ||
        oldDelegate.bar2ScaleY != bar2ScaleY ||
        oldDelegate.bar3ScaleY != bar3ScaleY;
  }
}
