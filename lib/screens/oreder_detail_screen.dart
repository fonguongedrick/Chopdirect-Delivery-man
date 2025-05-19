import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initMarkers();
  }

  void _initMarkers() {
    final farmerLocation = widget.orderData['farmerLocation'] as GeoPoint?;
    final customerLocation = widget.orderData['customerLocation'] as GeoPoint?;

    if (farmerLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('farmer'),
        position: LatLng(farmerLocation.latitude, farmerLocation.longitude),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (customerLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(customerLocation.latitude, customerLocation.longitude),
        infoWindow: const InfoWindow(title: 'Delivery Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: ${e.toString()}')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmerLocation = widget.orderData['farmerLocation'] as GeoPoint?;
    final initialCameraPosition = farmerLocation != null
        ? LatLng(farmerLocation.latitude, farmerLocation.longitude)
        : const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderData['orderId']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${widget.orderData['status']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delivery Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('Address: ${widget.orderData['deliveryAddress']}'),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialCameraPosition,
                  zoom: 14,
                ),
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
            ),
            const SizedBox(height: 16),
            if (widget.orderData['status'] == 'shipped')
              _isUpdating
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: () => _updateOrderStatus('out_for_delivery'),
                child: const Text('Picked Up - Start Delivery'),
              ),
            if (widget.orderData['status'] == 'out_for_delivery')
              _isUpdating
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: () => _updateOrderStatus('delivered'),
                child: const Text('Mark as Delivered'),
              ),
          ],
        ),
      ),
    );
  }
}