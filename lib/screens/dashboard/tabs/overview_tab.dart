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
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final isTablet = constraints.maxWidth < 1000;
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de bord - ${restaurant.name}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('restaurantId', isEqualTo: restaurant.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen)),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text("Erreur de chargement des données", style: TextStyle(color: Colors.red)),
                    );
                  }

                  final allOrders = snapshot.data?.docs.map((doc) => OrderModel.fromFirestore(doc)).toList() ?? [];
                  final todaysOrders = allOrders.where((order) => order.createdAt.isAfter(startOfDay)).toList();

                  final double totalRevenueToday = todaysOrders.fold(0, (sum, order) => sum + order.totalAmount);
                  final int pendingOrders = todaysOrders.where((o) => o.status == 0).length;
                  final int completedOrders = todaysOrders.where((o) => o.status == 3).length;

                  // Cartes KPI
                  final kpiWidgets = [
                    _buildKPI("Chiffre d'Affaires (Jour)", "${totalRevenueToday.toStringAsFixed(2)} €", Icons.monetization_on, AppTheme.emeraldGreen, isMobile),
                    _buildKPI("Commandes en attente", "$pendingOrders", Icons.timer, Colors.orangeAccent, isMobile),
                    _buildKPI("Commandes livrées", "$completedOrders", Icons.check_circle, Colors.blueAccent, isMobile),
                  ];

                  Widget kpisRow;
                  if (isMobile) {
                    kpisRow = Column(
                      children: kpiWidgets.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList(),
                    );
                  } else {
                    kpisRow = Row(
                      children: kpiWidgets.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: w))).toList(),
                    );
                  }

                  // Section Graphique + Commandes Récentes
                  final chartWidget = GlassContainer(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Évolution des ventes (Semaine)",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(height: 220, child: _buildChart(allOrders)),
                      ],
                    ),
                  );

                  final recentOrdersWidget = GlassContainer(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Commandes Récentes",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        if (todaysOrders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text("Aucune commande aujourd'hui", style: TextStyle(color: Colors.white54, fontSize: 13)),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todaysOrders.length > 5 ? 5 : todaysOrders.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                            itemBuilder: (context, index) {
                              todaysOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                              final order = todaysOrders[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(order.status).withValues(alpha: 0.2),
                                  child: Icon(Icons.receipt, color: _getStatusColor(order.status), size: 18),
                                ),
                                title: Text(
                                  "#${order.id.length >= 6 ? order.id.substring(0, 6).toUpperCase() : order.id}",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  DateFormat('HH:mm').format(order.createdAt),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: Text(
                                  "${order.totalAmount.toStringAsFixed(2)} €",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      kpisRow,
                      const SizedBox(height: 20),
                      if (isTablet) ...[
                        chartWidget,
                        const SizedBox(height: 20),
                        recentOrdersWidget,
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: chartWidget),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: recentOrdersWidget),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKPI(String title, String value, IconData icon, Color color, bool isMobile) {
    return GlassContainer(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: isMobile ? 24 : 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChart(List<OrderModel> orders) {
    final now = DateTime.now();
    final Map<int, double> salesByDay = {for (var i = 0; i < 7; i++) i: 0};

    for (var order in orders) {
      if (order.status == 4) continue;
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
            barWidth: 3.5,
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
