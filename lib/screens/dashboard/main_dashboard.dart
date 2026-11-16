import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../theme/app_theme.dart';
import 'tabs/overview_tab.dart';
import 'tabs/live_orders_tab.dart';
import 'tabs/resto_info_tab.dart';
import 'tabs/resto_menu_tab.dart';
import 'tabs/resto_inventory_tab.dart';

class MainDashboard extends StatefulWidget {
  final String restaurantId;
  const MainDashboard({super.key, required this.restaurantId});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  String _getTabTitle(int index) {
    switch (index) {
      case 0: return "Vue d'ensemble";
      case 1: return "Commandes en direct";
      case 2: return "Infos Restaurant";
      case 3: return "Menu & Options";
      case 4: return "Disponibilité (Stock)";
      default: return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurantId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen)),
          );
        }

        if (!snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 60),
                  const SizedBox(height: 16),
                  const Text('Restaurant introuvable.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
                    child: const Text('Se déconnecter'),
                  )
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        data['id'] = snapshot.data!.id;
        final restaurant = RestaurantModel.fromJson(data);

        final List<Widget> tabs = [
          OverviewTab(restaurant: restaurant),
          LiveOrdersTab(restaurant: restaurant),
          RestoInfoTab(restaurant: restaurant),
          RestoMenuTab(restaurant: restaurant),
          RestoInventoryTab(restaurant: restaurant),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 900;

            if (isMobile) {
              return Scaffold(
                backgroundColor: AppTheme.darkBackground,
                appBar: AppBar(
                  backgroundColor: AppTheme.darkBackground,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        restaurant.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getTabTitle(_selectedIndex),
                        style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 12),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      tooltip: 'Se déconnecter',
                      onPressed: () => FirebaseAuth.instance.signOut(),
                    ),
                  ],
                ),
                drawer: Drawer(
                  backgroundColor: AppTheme.darkBackground,
                  child: SafeArea(
                    child: _buildSidebarContent(restaurant, isDrawer: true),
                  ),
                ),
                body: SafeArea(
                  child: tabs[_selectedIndex],
                ),
              );
            }

            return Scaffold(
              backgroundColor: AppTheme.darkBackground,
              body: Row(
                children: [
                  // Sidebar Desktop
                  Container(
                    width: 260,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.darkBackground, AppTheme.lighterDarkBackground],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border(right: BorderSide(color: Colors.white12)),
                    ),
                    child: _buildSidebarContent(restaurant, isDrawer: false),
                  ),
                  // Contenu Principal
                  Expanded(
                    child: tabs[_selectedIndex],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebarContent(RestaurantModel restaurant, {required bool isDrawer}) {
    return Column(
      children: [
        SizedBox(height: isDrawer ? 20 : 36),
        const Icon(Icons.storefront, color: AppTheme.emeraldGreen, size: 44),
        const SizedBox(height: 12),
        const Text(
          'Restaurateur',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            restaurant.name.toUpperCase(),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildNavItem(Icons.dashboard_rounded, "Vue d'ensemble", 0, isDrawer),
              _buildNavItem(Icons.receipt_long_rounded, 'Commandes en direct', 1, isDrawer),
              _buildNavItem(Icons.info_outline, 'Infos Restaurant', 2, isDrawer),
              _buildNavItem(Icons.restaurant_menu_rounded, 'Menu & Options', 3, isDrawer),
              _buildNavItem(Icons.inventory_2_outlined, 'Disponibilité (Stock)', 4, isDrawer),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.code_rounded, color: AppTheme.emeraldGreen, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "Cooking Data",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                "Propulsé par Cooking Data • Solutions Numériques & IA en Martinique 🇲🇶",
                style: TextStyle(color: Colors.white38, fontSize: 9.5),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.white54),
          title: const Text('Déconnexion', style: TextStyle(color: Colors.white54)),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index, bool isDrawer) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.emeraldGreen : Colors.white54),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        if (isDrawer) {
          Navigator.of(context).pop();
        }
        setState(() => _selectedIndex = index);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      selectedTileColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}
