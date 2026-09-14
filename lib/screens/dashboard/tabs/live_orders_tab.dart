import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:openfood_models/openfood_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_container.dart';

class LiveOrdersTab extends StatefulWidget {
  final RestaurantModel restaurant;
  const LiveOrdersTab({super.key, required this.restaurant});

  @override
  State<LiveOrdersTab> createState() => _LiveOrdersTabState();
}

class _LiveOrdersTabState extends State<LiveOrdersTab> {
  void _updateOrderStatus(String orderId, int newStatus, [int? prepTimeMinutes]) {
    final data = <String, dynamic>{'status': newStatus};
    if (newStatus == 3) {
      data['deliveredAt'] = Timestamp.now();
    }
    if (prepTimeMinutes != null) {
      data['prepTimeMinutes'] = prepTimeMinutes;
    }
    FirebaseFirestore.instance.collection('orders').doc(orderId).update(data).catchError((e) {
      debugPrint("Error updating status: $e");
    });
  }

  void _promptAcceptOrder(String orderId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Temps de préparation', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Combien de temps faut-il pour préparer cette commande ?', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [10, 20, 30, 40].map((time) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: () {
                          _updateOrderStatus(orderId, 1, time);
                          Navigator.of(context).pop();
                        },
                        child: Text('$time min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commandes en Cours',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('restaurantId', isEqualTo: widget.restaurant.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));

                if (snapshot.hasData) {
                  var orders = snapshot.data!.docs
                      .map((doc) => OrderModel.fromFirestore(doc))
                      .where((order) => order.status < 4)
                      .toList();

                  orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  if (orders.isEmpty) {
                    return const GlassContainer(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Aucune commande active', style: TextStyle(color: Colors.white70, fontSize: 18))),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 3;
                      if (constraints.maxWidth < 600) crossAxisCount = 1;
                      else if (constraints.maxWidth < 1100) crossAxisCount = 2;

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: 440,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return _OrderCard(
                            order: orders[index],
                            onAccept: () => _promptAcceptOrder(orders[index].id),
                            onReject: () => _updateOrderStatus(orders[index].id, 4),
                            onReady: () => _updateOrderStatus(orders[index].id, 2),
                          );
                        },
                      );
                    }
                  );
                }
                return const Center(child: CircularProgressIndicator(color: AppTheme.emeraldGreen));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onReady;

  const _OrderCard({required this.order, required this.onAccept, required this.onReject, required this.onReady});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: return 'En Attente';
      case 1: return 'En Préparation';
      case 2: return 'En Route';
      case 3: return 'Livré';
      case 4: return 'Annulé';
      default: return 'Inconnu';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.redAccent;
      case 1: return Colors.orangeAccent;
      case 2: return Colors.blueAccent;
      case 3: return AppTheme.emeraldGreen;
      case 4: return Colors.grey;
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final now = DateTime.now();
    final elapsedMinutes = now.difference(order.createdAt).inMinutes;
    
    bool showClientInfo = true;
    if (order.status == 3) {
      if (order.deliveredAt != null) {
        showClientInfo = now.difference(order.deliveredAt!).inMinutes <= 30;
      } else {
        showClientInfo = false;
      }
    } else if (order.status == 4) {
      showClientInfo = false;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${order.id.substring(0, 6).toUpperCase()}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  Text(DateFormat('HH:mm').format(order.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(order.status).withValues(alpha: 0.5)),
                ),
                child: Text(
                  _getStatusText(order.status),
                  style: TextStyle(color: _getStatusColor(order.status), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          // Timer
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                'Écoulé: $elapsedMinutes min',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (order.prepTimeMinutes != null) ...[
                const SizedBox(width: 8),
                const Text('|', style: TextStyle(color: Colors.white24)),
                const SizedBox(width: 8),
                Text('Prévu: ${order.prepTimeMinutes} min', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]
            ],
          ),
          const SizedBox(height: 12),
          // Info Client conditionnelle
          if (showClientInfo) ...[
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       const Icon(Icons.person, color: Colors.white54, size: 14),
                       const SizedBox(width: 4),
                       Expanded(child: Text(order.customerName ?? 'Client Inconnu', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       const Icon(Icons.phone, color: Colors.white54, size: 14),
                       const SizedBox(width: 4),
                       Text(order.customerPhone ?? 'Sans numéro', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       const Icon(Icons.location_on, color: Colors.white54, size: 14),
                       const SizedBox(width: 4),
                       Expanded(child: Text(order.deliveryAddress ?? 'Adresse inconnue', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                     ],
                   ),
                 ],
               )
             )
          ] else ...[
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
               child: const Row(
                 children: [
                   Icon(Icons.lock, color: Colors.white38, size: 14),
                   SizedBox(width: 4),
                   Text('Données masquées (Délai expiré)', style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                 ],
               ),
             )
          ],
          const SizedBox(height: 12),
          // Items List
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: order.items.length,
                separatorBuilder: (_,__) => const Divider(color: Colors.white12),
                itemBuilder: (context, i) {
                  final item = order.items[i];
                  final modifiers = item['selectedOptions'] != null ? (item['selectedOptions'] as List).map((m) => m['name']).join(', ') : '';
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.emeraldGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('${item['quantity']}x', style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            if (modifiers.isNotEmpty)
                              Text(modifiers, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total (client)', style: TextStyle(color: Colors.white70)),
              Text(
                NumberFormat.currency(locale: 'fr', symbol: '€').format(order.totalAmount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          if (order.status == 0)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Refuser'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            )
          else if (order.status == 1)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onReady,
                icon: const Icon(Icons.delivery_dining),
                label: const Text('Commande Prête'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            )
          else 
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(order.status == 3 ? 'Livrée' : 'En attente livreur', style: const TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}
