import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/administrador_model.dart';
import '../secretary/quick_sales_screen.dart';
import '../secretary/clients_screen.dart';
import '../secretary/clothing_prices_screen.dart';
import '../secretary/statistics_screen.dart';
import '../auth/login_screen.dart';
import 'admin_more_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final AdministradorModel admin;

  const AdminHomeScreen({super.key, required this.admin});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _footerIndex = 0; // 0 = Inicio, 1 = Ventas, 2 = Secretarios, 3 = Más

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _footerIndex == 0
            ? _buildHomeContent()
            : _footerIndex == 1
                ? const QuickSalesScreen()
                : AdminMoreScreen(admin: widget.admin),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFF0E8FC),
          selectedIndex: _footerIndex,
          onDestinationSelected: (indice) {
            setState(() => _footerIndex = indice);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.violet),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.flash_on_outlined),
              selectedIcon: Icon(Icons.flash_on, color: AppTheme.violet),
              label: 'Ventas Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge, color: AppTheme.violet),
              label: 'Secretarios',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.violet),
              label: 'Perfil / Más',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      children: [
        // Top Bar
        Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E9FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.violet),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PANEL DE ADMIN (EMPRENDEDOR)',
                    style: TextStyle(
                      color: AppTheme.violet,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Buenas tardes, ${widget.admin.nombre}',
                    style: const TextStyle(
                      color: AppTheme.dark,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.violet,
              child: Text(
                widget.admin.iniciales,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0E9FC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'EN VIVO AHORA',
                style: TextStyle(
                  color: AppTheme.violet,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              const Text(
                'TikTok & FB Live',
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // KPIs en Grid 2x2
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                titulo: 'Total Vendido Hoy',
                valor: '\$1,240',
                colorValor: AppTheme.dark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                titulo: 'Prendas Vendidas',
                valor: '48',
                colorValor: AppTheme.violet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                titulo: 'Cobrado (Efectivo/Transf)',
                valor: '\$890',
                colorValor: AppTheme.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                titulo: 'Por Cobrar',
                valor: '\$350',
                colorValor: const Color(0xFFD84A75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Botón Venta Rápida
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.violet,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuickSalesScreen()),
              );
            },
            icon: const Icon(Icons.flash_on, size: 20),
            label: const Text(
              'VENTA RÁPIDA EN VIVO',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Accesos Rápidos
        const Text(
          'Accesos Rápidos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.dark,
          ),
        ),
        const SizedBox(height: 12),

        _buildQuickAccessTile(
          icon: Icons.people_outline,
          iconBg: const Color(0xFFF0E9FC),
          iconColor: AppTheme.violet,
          title: 'Administrar Clientas',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientsScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        _buildQuickAccessTile(
          icon: Icons.checkroom_outlined,
          iconBg: const Color(0xFFFDECEF),
          iconColor: const Color(0xFFD84A75),
          title: 'Prendas y Precios de Hoy',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClothingPricesScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        _buildQuickAccessTile(
          icon: Icons.bar_chart_outlined,
          iconBg: const Color(0xFFE6F5F2),
          iconColor: const Color(0xFF2A9D8F),
          title: 'Estadísticas del Live',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            );
          },
        ),
        const SizedBox(height: 10),

        // Gestión de Secretarios (Exclusivo Administrador)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: () {
              setState(() => _footerIndex = 2);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.badge_outlined, color: Colors.white, size: 20),
            ),
            title: const Text(
              'Gestión de Secretarios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5D4037)),
            ),
            subtitle: const Text(
              'Aprobar solicitudes y ver equipo activo',
              style: TextStyle(fontSize: 10, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFFFA000)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({required String titulo, required String valor, required Color colorValor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorValor),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.muted),
      ),
    );
  }
}
