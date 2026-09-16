import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'product_detail_screen.dart';
import 'payment_method_screen.dart';

class CustomerCartScreen extends StatefulWidget {
  @override
  _CustomerCartScreenState createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    try {
      final response = await _apiService.get('orders/cart/');
      if (response.data != null && response.data.isNotEmpty) {
        setState(() {
          _cartItems = response.data['items'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } on DioException catch (e) {
      print('Failed to load cart $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load Cart.')));
    }
  }

  Future<void> _removeItem(int itemId) async {
    try {
      await _apiService.delete('orders/cart/remove_item/', data: {'item_id': itemId});
      _fetchCart();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove item.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text('Cart')), body: Center(child: CircularProgressIndicator()));
    }

    if (_cartItems.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text('Cart')), body: Center(child: Text('Your cart is empty.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                final product = item['product'];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: product['image'] != null
                      ? Image.network(
                          product['image'].toString().startsWith('http') ? product['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                              : 'http://172.20.10.6:8000${product['image']}',
                          width: 50, height: 50, fit: BoxFit.cover,
                        )
                      : Icon(Icons.cake, size: 50),
                    title: Text(product['name']),
                    subtitle: Text('Qty: ${item['quantity']} | Flavor: ${item['flavor']} | Size: ${item['size']}\n₹${product['base_price']} each'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Remove Item?'),
                            content: Text('Do you want to remove this item from your cart?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('No')),
                              TextButton(onPressed: () {
                                Navigator.pop(ctx);
                                _removeItem(item['id']);
                              }, child: Text('Yes', style: TextStyle(color: Colors.red))),
                            ],
                          )
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (context) {
                    double cakeAmount = 0;
                    for (var item in _cartItems) {
                       cakeAmount += double.parse(item['product']['base_price'].toString()) * int.parse(item['quantity'].toString());
                    }
                    double deliveryCharge = _cartItems.isEmpty ? 0 : 50.0;
                    double totalAmount = cakeAmount + deliveryCharge;
                    return Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Cake Amount:', style: TextStyle(fontSize: 16)), Text('₹${cakeAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 16))]),
                        SizedBox(height: 5),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Delivery Charge:', style: TextStyle(fontSize: 16)), Text('₹${deliveryCharge.toStringAsFixed(2)}', style: TextStyle(fontSize: 16))]),
                        Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Payable:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('₹${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                      ],
                    );
                  }
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    List<int>? orderIds;
                    double cakeAmount = 0;
                    for (var item in _cartItems) {
                       cakeAmount += double.parse(item['product']['base_price'].toString()) * int.parse(item['quantity'].toString());
                    }
                    double deliveryCharge = _cartItems.isEmpty ? 0 : 50.0;
                    double totalAmount = cakeAmount + deliveryCharge;

                    try {
                      final response = await _apiService.post('orders/cart/checkout/', {});
                      orderIds = List<int>.from(response.data['order_ids']);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checkout failed.')));
                      setState(() => _isLoading = false);
                      return;
                    }
                    
                    if (orderIds.isEmpty) {
                      setState(() => _isLoading = false);
                      return;
                    }

                    setState(() => _isLoading = false);

                    if (!mounted) return;

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentMethodScreen(
                          orderIds: orderIds!,
                          totalAmount: totalAmount,
                        ),
                      ),
                    );

                    if (!mounted) return;
                    _fetchCart();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Checkout', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      )
    );
  }
}
