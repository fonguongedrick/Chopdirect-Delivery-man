import 'package:chopdirect_delivery/screens/application_screen.dart';
import 'package:chopdirect_delivery/screens/available_orders_screen.dart';
import 'package:chopdirect_delivery/screens/oreder_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDeliveryApproved = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkDeliveryApproval();
  }

  Future<void> _checkDeliveryApproval() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final application = await _firestore.collection('delivery_applications_chopdirect')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    setState(() {
      _isDeliveryApproved = application.docs.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDeliveryApproved) {
      return const ApplicationScreen();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Deliveries'),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                await Provider.of<AuthService>(context, listen: false).signOut();
              },
            ),
          ],
          bottom: const TabBar(
              tabs: [
          Tab(icon: Icon(Icons.list)),
          Tab(icon: Icon(Icons.directions_bike)),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _buildCurrentDeliveries(),
          const AvailableOrdersScreen(),
        ],
      ),
    ),
    );
  }

  Widget _buildCurrentDeliveries() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('orders_chopdirect')
          .where('deliveryId', isEqualTo: user.uid)
          .where('status', whereIn: ['shipped', 'out_for_delivery'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No current deliveries'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final order = snapshot.data!.docs[index];
            return Card(
              child: ListTile(
                title: Text('Order #${order['orderId']}'),
                subtitle: Text('Status: ${order['status']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailScreen(
                        orderId: order.id,
                        orderData: order.data() as Map<String, dynamic>,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}