import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/administrador_model.dart';
import '../../services/invitation_code_service.dart';
import '../../theme/app_theme.dart';
import '../vendix_logo.dart';

/// Diálogo que muestra el código QR oficial del emprendimiento usando
/// la API gratuita de QuickChart y la identidad visual de VendiX.
class StoreQrDialog extends StatefulWidget {
  final AdministradorModel admin;

  const StoreQrDialog({super.key, required this.admin});

  static Future<void> mostrar(
    BuildContext context, {
    required AdministradorModel admin,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StoreQrDialog(admin: admin),
    );
  }

  @override
  State<StoreQrDialog> createState() => _StoreQrDialogState();
}

class _StoreQrDialogState extends State<StoreQrDialog> {
  late Future<String> _codigoFuture;
  int _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _codigoFuture = InvitationCodeService.obtenerOGenerarCodigoAdmin(
      widget.admin.id,
    );
  }

  void _reintentar() {
    setState(() {
      _reloadKey++;
      _codigoFuture = InvitationCodeService.obtenerOGenerarCodigoAdmin(
        widget.admin.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final nombreTienda = widget.admin.nombreEmprendimiento.trim().isNotEmpty
        ? widget.admin.nombreEmprendimiento.trim()
        : (widget.admin.nombreCompleto.trim().isNotEmpty
              ? widget.admin.nombreCompleto.trim()
              : 'Mi Emprendimiento');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.violet.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Marca de agua muy tenue con el logo de VendiX (no afecta el QR)
              Positioned(
                right: -28,
                bottom: -24,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.045,
                    child: const VendixLogo(
                      size: 165,
                      showText: false,
                      animateEntrance: false,
                      continuousLoop: false,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                top: -20,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.035,
                    child: const VendixLogo(
                      size: 115,
                      showText: false,
                      animateEntrance: false,
                      continuousLoop: false,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: FutureBuilder<String>(
                  future: _codigoFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 310,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppTheme.violet),
                              SizedBox(height: 12),
                              Text(
                                'Cargando código del emprendimiento...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return SizedBox(
                        height: 260,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No se pudo obtener el código de invitación.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.dark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _reintentar,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reintentar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.violet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final codigo = snapshot.data!;
                    final qrUrl = InvitationCodeService.construirUrlQrQuickChart(
                      codigo,
                    );

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0E9FC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 14,
                                    color: AppTheme.violet,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'INVITACIÓN VENDIX',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.9,
                                      color: AppTheme.violet,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: AppTheme.muted,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nombreTienda,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Comparte este QR para que tus clientes se asocien a tu tienda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tarjeta limpia del QR con fondo blanco sólido y separación
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.violet.withValues(alpha: 0.18),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    qrUrl,
                                    key: ValueKey('qr_${codigo}_$_reloadKey'),
                                    width: 220,
                                    height: 220,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.violet,
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, err, stack) {
                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.wifi_off_rounded,
                                            size: 36,
                                            color: AppTheme.muted,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Sin conexión para cargar el QR',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.muted,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _reintentar,
                                            child: const Text('Reintentar'),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                // Logo central moderado con margen blanco protector
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const VendixLogo(
                                    size: 40,
                                    showText: false,
                                    animateEntrance: false,
                                    continuousLoop: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Código en texto copiable debajo del QR
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.violet.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CÓDIGO DE INVITACIÓN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.9,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    codigo,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.2,
                                      color: AppTheme.violet,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              IconButton.filledTonal(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: codigo),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Código copiado al portapapeles',
                                      ),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: 'Copiar código',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFEBE2FA),
                                  foregroundColor: AppTheme.violet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
