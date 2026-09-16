import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';

class BakerOrdersScreen extends StatefulWidget {
  @override
  _BakerOrdersScreenState createState() => _BakerOrdersScreenState();
}

class _BakerOrdersScreenState extends State<BakerOrdersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  List<dynamic> _deliveryPersons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _fetchDeliveryPersons();
  }

  Future<void> _fetchDeliveryPersons() async {
    try {
      final response = await _apiService.get('users/delivery_persons/');
      setState(() {
        _deliveryPersons = response.data;
      });
    } catch (e) {
      print('Failed to load delivery persons');
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await _apiService.get('orders/list/');
      setState(() {
        _orders = response.data;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load orders.')));
    }
  }

  void _updateOrderStatus(int orderId, String status, {String? deliveryTime}) async {
    try {
      final Map<String, dynamic> data = {'status': status};
      if (deliveryTime != null && deliveryTime.trim().isNotEmpty) {
        data['delivery_time'] = deliveryTime.trim();
      }
      
      await _apiService.post('orders/list/$orderId/status/', data); 
      _fetchOrders(); // Refresh
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order status updated: $status', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    } catch (e) {
      String errMsg = 'Unknown error';
      if (e is DioException) {
        errMsg = e.response?.data.toString() ?? e.message ?? 'Network Error';
      } else {
        errMsg = e.toString();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $errMsg', maxLines: 3, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  void _showAssignDeliveryDialog(int orderId) {
    if (_deliveryPersons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No delivery persons available.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Assign Delivery Person'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _deliveryPersons.length,
              itemBuilder: (context, index) {
                final dp = _deliveryPersons[index];
                return ListTile(
                  title: Text(dp['user']['username']),
                  subtitle: Text(dp['contact_number'] ?? 'No contact'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _assignDeliveryPerson(orderId, dp['id']);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel')),
          ]
        );
      },
    );
  }

  void _assignDeliveryPerson(int orderId, int dpId) async {
    try {
      await _apiService.patch('orders/list/$orderId/assign_delivery/', {'delivery_person_id': dpId});
      _fetchOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delivery person assigned!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = _orders.where((o) => o['status'] != 'DELIVERED' && o['status'] != 'REJECTED').toList();
    final pastOrders = _orders.where((o) => o['status'] == 'DELIVERED' || o['status'] == 'REJECTED').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Orders'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
            labelColor: Color(0xFFE63946),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFE63946),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: _isLoading 
          ? Center(child: CircularProgressIndicator()) 
          : TabBarView(
              children: [
                _buildOrderList(activeOrders),
                _buildOrderList(pastOrders),
              ],
            ),
      ),
    );
  } 
  Widget _buildOrderList(List<dynamic> orders) {
    if (orders.isEmpty) {
      return Center(child: Text('No orders found.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (ctx, index) {
              final order = orders[index];
              return Card(
                child: ExpansionTile(
                  leading: (order['items'] != null && order['items'].isNotEmpty && order['items'][0]['product']['image'] != null)
                    ? Image.network(
                        order['items'][0]['product']['image'].toString().startsWith('http') ? order['items'][0]['product']['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                          : 'http://172.20.10.6:8000${order['items'][0]['product']['image']}',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50, height: 50, color: Colors.grey.shade200,
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 50, height: 50, color: Colors.grey.shade200,
                        child: Icon(Icons.cake, color: Colors.grey),
                      ),
                  title: Text('Order #${order['id']} - ${order['status']}'),
                  subtitle: Text('Customer: ${order['customer']['user']['username']} (${order['customer']['contact_number']})\nTotal: ₹${order['total_amount']}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            SizedBox(height: 8),
                            SizedBox(height: 8),
                            if (order['custom_request'] != null) ...[
                              Divider(),
                              Text('Custom Request Details:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                              SizedBox(height: 4),
                              if (order['custom_request']['special_instructions'] != null && order['custom_request']['special_instructions'].toString().isNotEmpty)
                                Text('Instructions: ${order['custom_request']['special_instructions']}'),
                              if (order['custom_request']['delivery_date'] != null)
                                Text('Requested Date: ${order['custom_request']['delivery_date']}'),
                              if (order['custom_request']['custom_design_image'] != null) ...[
                                SizedBox(height: 8),
                                Text('Reference Photo:', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    order['custom_request']['custom_design_image'].toString().startsWith('http') ? order['custom_request']['custom_design_image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                      : 'http://172.20.10.6:8000${order['custom_request']['custom_design_image']}',
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 100, width: double.infinity, color: Colors.grey.shade100,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, color: Colors.grey),
                                          Text('Image not available', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              Divider(),
                            ],
                            if (order['status'] == 'ORDER_IN_PROGRESS' || order['status'] == 'PENDING' || order['status'] == 'CONFIRMED')
                              TextField(
                                decoration: InputDecoration(
                                  labelText: 'Set Delivery Time (e.g. 2026-03-07 14:00)',
                                  hintText: 'YYYY-MM-DD HH:MM',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => order['delivery_time_input'] = val,
                              ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                  if (order['status'] == 'PENDING' || order['status'] == 'CONFIRMED') ...[
                                    ElevatedButton(
                                      onPressed: () => _updateOrderStatus(order['id'], 'ORDER_IN_PROGRESS', deliveryTime: order['delivery_time_input']),
                                    child: Text('Accept'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _updateOrderStatus(order['id'], 'REJECTED'),
                                    child: Text('Reject'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  ),
                                ],
                                if (order['status'] == 'ORDER_IN_PROGRESS') ...[
                                  if (order['delivery_person'] == null)
                                    ElevatedButton(
                                      onPressed: () => _showAssignDeliveryDialog(order['id']),
                                      child: Text('Assign Delivery'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    ),
                                  ElevatedButton(
                                    onPressed: () => _updateOrderStatus(order['id'], 'DELIVERED'),
                                    child: Text('Mark Delivered'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  ),
                                ],
                                if (order['status'] == 'DELIVERED' || order['status'] == 'REJECTED') ...[
                                   Text('No further actions available.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                                ]
                              ]
                            )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
  }
}
