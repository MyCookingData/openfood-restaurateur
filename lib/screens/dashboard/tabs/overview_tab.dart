import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class OverviewTab extends StatelessWidget {
  final RestaurantModel restaurant;
  const OverviewTab({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    // Calculer le début de la journée pour filtrer les commandes d'aujourd'hui
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tableau de bord - ${restaurant.name}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('restaurantId', isEqualTo: restaurant.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Erreur de chargement des données", style: TextStyle(color: Colors.red)));
                }

                final allOrders = snapshot.data?.docs.map((doc) => OrderModel.fromFirestore(doc)).toList() ?? [];
                
                // Filtrer pour aujourd'hui
                final todaysOrders = allOrders.where((order) => order.createdAt.isAfter(startOfDay)).toList();
                
                final double totalRevenueToday = todaysOrders.fold(0, (sum, order) => sum + order.totalAmount);
                final int pendingOrders = todaysOrders.where((o) => o.status == 0).length;
                final int completedOrders = todaysOrders.where((o) => o.status == 3).length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildKPI("Chiffre d'Affaires (Jour)", "${totalRevenueToday.toStringAsFixed(2)} €", Icons.monetization_on, AppTheme.emeraldGreen)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildKPI("Commandes en attente", "$pendingOrders", Icons.timer, Colors.orangeAccent)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildKPI("Commandes livrées", "$completedOrders", Icons.check_circle, Colors.blueAccent)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Évolution des ventes (Semaine)", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 24),
                                  Expanded(child: _buildChart(allOrders)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: GlassContainer(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Commandes Récentes", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.separated(
                                itemCount: todaysOrders.length > 5 ? 5 : todaysOrders.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                                itemBuilder: (context, index) {
                                  // Trier par date décroissante
                                  todaysOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                                  final order = todaysOrders[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(order.status).withValues(alpha: 0.2),
                                      child: Icon(Icons.receipt, color: _getStatusColor(order.status), size: 20),
                                    ),
                                    title: Text("#${order.id.substring(0, 5).toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    subtitle: Text(DateFormat('HH:mm').format(order.createdAt), style: const TextStyle(color: Colors.white54)),
                                    trailing: Text("${order.totalAmount.toStringAsFixed(2)} €", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKPI(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChart(List<OrderModel> orders) {
    // Regrouper par jour sur les 7 derniers jours
    final now = DateTime.now();
    final Map<int, double> salesByDay = {for (var i = 0; i < 7; i++) i: 0};
    
    for (var order in orders) {
      if (order.status == 4) continue; // Ignorer annulées
      final diff = now.difference(order.createdAt).inDays;
      if (diff >= 0 && diff < 7) {
        salesByDay[6 - diff] = (salesByDay[6 - diff] ?? 0) + order.totalAmount;
      }
    }

    final spots = salesByDay.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.emeraldGreen,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.redAccent;
      case 1: return Colors.orangeAccent;
      case 2: return Colors.blueAccent;
      case 3: return AppTheme.emeraldGreen;
      default: return Colors.grey;
    }
  }
}
