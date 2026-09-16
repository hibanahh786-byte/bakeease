import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'invoice_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  @override
  _CustomerOrdersScreenState createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _filter = 'All';

  List<dynamic> get _filteredOrders {
    if (_filter == 'Delivered') {
      return _orders.where((o) => o['status'] == 'DELIVERED').toList();
    } else if (_filter == 'Undelivered') {
      return _orders.where((o) => o['status'] != 'DELIVERED' && o['status'] != 'REJECTED').toList();
    }
    return _orders;
  }

  @override
  void initState() {
    super.initState();
    _fetchOrders();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load orders.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Orders')),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : _orders.isEmpty 
          ? Center(child: Text('You have no orders.'))
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('All'),
                        selected: _filter == 'All',
                        onSelected: (bool selected) {
                          setState(() { _filter = 'All'; });
                        },
                      ),
                      SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Delivered'),
                        selected: _filter == 'Delivered',
                        onSelected: (bool selected) {
                          setState(() { _filter = 'Delivered'; });
                        },
                      ),
                      SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Undelivered'),
                        selected: _filter == 'Undelivered',
                        onSelected: (bool selected) {
                          setState(() { _filter = 'Undelivered'; });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? Center(child: Text('No orders found.'))
                      : ListView.builder(
                          itemCount: _filteredOrders.length,
                          itemBuilder: (ctx, index) {
                            final order = _filteredOrders[index];
                            return Card(
                  margin: EdgeInsets.all(8),
                  child: ExpansionTile(
                    leading: (order['items'] != null && order['items'].isNotEmpty && order['items'][0]['product']['image'] != null)
                        ? Image.network(
                            order['items'][0]['product']['image'].toString().startsWith('http') ? order['items'][0]['product']['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                : 'http://172.20.10.6:8000${order['items'][0]['product']['image']}',
                            width: 50, height: 50, fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.cake, 
                            color: order['status'] == 'DELIVERED' ? Colors.green : Colors.orange,
                            size: 40,
                          ),
                    title: Text('Order #${order['id']} - ${order['status']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total: ₹${order['total_amount']} | Placed: ${DateTime.parse(order['created_at']).toLocal().toString().substring(0, 16)}'),
                        if (order['delivery_time'] != null)
                          Text('Scheduled Delivery: ${DateTime.parse(order['delivery_time']).toLocal().toString().substring(0, 16)}', 
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    children: [
                      Divider(),
                      if (order['items'] != null)
                        ...(order['items'] as List).map((item) {
                          final product = item['product'];
                          return ListTile(
                            leading: product['image'] != null
                              ? Image.network(
                                  product['image'].toString().startsWith('http') ? product['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                      : 'http://172.20.10.6:8000${product['image']}',
                                  width: 40, height: 40, fit: BoxFit.cover,
                                )
                              : Icon(Icons.cake),
                            title: Text(product['name']),
                            subtitle: Text('Qty: ${item['quantity']} | ₹${item['price']}'),
                          );
                        }).toList(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (order['status'] == 'DELIVERED') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => InvoiceScreen(order: order)),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice is only available after delivery.')));
                            }
                          },
                          icon: Icon(Icons.receipt),
                          label: Text('View Invoice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: order['status'] == 'DELIVERED' ? Colors.blue : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
