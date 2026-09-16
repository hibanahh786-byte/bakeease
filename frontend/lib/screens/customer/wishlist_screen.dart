import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'product_detail_screen.dart';

class CustomerWishlistScreen extends StatefulWidget {
  @override
  _CustomerWishlistScreenState createState() => _CustomerWishlistScreenState();
}

class _CustomerWishlistScreenState extends State<CustomerWishlistScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _wishlistItems = [];

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    try {
      final response = await _apiService.get('orders/wishlist/');
      if (response.data != null && response.data.isNotEmpty) {
        setState(() {
          _wishlistItems = response.data['items'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } on DioException catch (e) {
      print('Failed to load wishlist $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load Wishlist.')));
    }
  }

  Future<void> _removeItem(int itemId) async {
    try {
      await _apiService.delete('orders/wishlist/remove_item/', data: {'item_id': itemId});
      _fetchWishlist();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove item.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text('Wishlist')), body: Center(child: CircularProgressIndicator()));
    }

    if (_wishlistItems.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text('Wishlist')), body: Center(child: Text('Your wishlist is empty.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Wishlist')),
      body: ListView.builder(
        itemCount: _wishlistItems.length,
        itemBuilder: (context, index) {
          final item = _wishlistItems[index];
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
              subtitle: Text('₹${product['base_price']}'),
              trailing: IconButton(
                icon: Icon(Icons.favorite, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Remove from Wishlist?'),
                      content: Text('Do you want to remove this item from your wishlist?'),
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
    );
  }
}
