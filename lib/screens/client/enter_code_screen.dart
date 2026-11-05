import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'client_shell.dart';

/// Pantalla que se muestra cuando el cliente ya se registró pero aún
/// no tiene un código de Live vinculado. Es OBLIGATORIA — no se puede
/// saltar. El usuario debe ingresar un código válido de un secretario
/// o cerrar sesión y usar otra cuenta.
class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _codigoCtrl = TextEditingController();
  bool _cargando = false;

  static const violeta = Color(0xFF6C4AB6);
  static const rosa = Color(0xFFE9A6C8);

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _vincularCodigo() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigoCtrl.text.trim().toUpperCase();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el código del Live para continuar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) throw Exception('No hay sesión activa.');

      // Validar código contra la colección 'secretarios'
      final querySec = await db
          .collection('secretarios')
          .where('codigoLive', isEqualTo: codigo)
          .limit(1)
          .get();

      if (querySec.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Código no válido o no activo. Pídelo al operador durante el Live.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _cargando = false);
        }
        return;
      }

      final dataSec = querySec.docs.first.data();
      final secretarioId = querySec.docs.first.id;
      final adminId = dataSec['adminId']?.toString() ?? '';

      final actualizacion = {
        'adminId': adminId,
        'secretarioId': secretarioId,
        'codigoLive': codigo,
      };

      // Guardar vínculo en usuarios y clientes
      final lote = db.batch();
      lote.update(db.collection('usuarios').doc(uid), actualizacion);
      lote.set(
        db.collection('clientes').doc(uid),
        actualizacion,
        SetOptions(merge: true),
      );
      await lote.commit();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ClientShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Se cerrará tu sesión y volverás a la pantalla de inicio. '
          'Cuando vuelvas a entrar, deberás ingresar el código del Live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: violeta),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    // Reiniciar la app volviendo a la pantalla de inicio
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // El usuario no puede ir "atrás" para saltarse esta pantalla
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8FC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono con degradado
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [violeta, rosa],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: violeta.withValues(alpha: 0.28),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      '¡Un paso más! 🛍️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF241B35),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Para ver las ventas en vivo necesitas vincularte con tu operador. '
                      'Pídele el código durante la transmisión en vivo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF81798D),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tarjeta del campo de código
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFECE6F2)),
                        boxShadow: [
                          BoxShadow(
                            color: violeta.withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.vpn_key_outlined, size: 16, color: violeta),
                              SizedBox(width: 6),
                              Text(
                                'CÓDIGO DEL LIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: violeta,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _codigoCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              fontSize: 22,
                              color: violeta,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'VX-849',
                              hintStyle: const TextStyle(
                                letterSpacing: 2,
                                fontSize: 18,
                                color: Color(0xFFCDC6DA),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF1EAFE),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFDCCBFA)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: violeta, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _cargando ? null : _vincularCodigo,
                              style: FilledButton.styleFrom(
                                backgroundColor: violeta,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _cargando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Vincularme y Entrar',
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

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _cargando ? null : _cerrarSesion,
                      child: const Text(
                        'Cerrar sesión e iniciar con otra cuenta',
                        style: TextStyle(
                          color: Color(0xFF81798D),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
