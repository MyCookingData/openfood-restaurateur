import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
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
          OverviewTab(restaurant: restaurant), // Update OverviewTab to take restaurant
          LiveOrdersTab(restaurant: restaurant), // Update LiveOrdersTab to take restaurant
          RestoInfoTab(restaurant: restaurant),
          RestoMenuTab(restaurant: restaurant),
          RestoInventoryTab(restaurant: restaurant),
        ];

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          body: Row(
            children: [
              // Sidebar
              Container(
                width: 280,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.darkBackground, AppTheme.lighterDarkBackground],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(right: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.storefront, color: AppTheme.emeraldGreen, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Restaurateur',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      restaurant.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 40),
                    _buildNavItem(Icons.dashboard_rounded, 'Vue d\'ensemble', 0),
                    _buildNavItem(Icons.receipt_long_rounded, 'Commandes en direct', 1),
                    _buildNavItem(Icons.info_outline, 'Infos Restaurant', 2),
                    _buildNavItem(Icons.restaurant_menu_rounded, 'Menu & Options', 3),
                    _buildNavItem(Icons.inventory_2_outlined, 'Disponibilité (Stock)', 4),
                    const Spacer(),
                    const Divider(color: Colors.white12),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white54),
                      title: const Text('Déconnexion', style: TextStyle(color: Colors.white54)),
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // Contenu Principal
              Expanded(
                child: tabs[_selectedIndex],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
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
      onTap: () => setState(() => _selectedIndex = index),
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: const Border(left: BorderSide(color: Colors.transparent, width: 4)),
      selectedTileColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}
