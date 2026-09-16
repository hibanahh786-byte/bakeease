import 'package:flutter/material.dart';
import 'checkout_screen.dart';
import '../../services/api_service.dart';
import '../chat/chat_page.dart';

class ProductDetailScreen extends StatefulWidget {
  final dynamic product;
  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedFlavor;
  String? _selectedSize;
  int _quantity = 1;
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _isWishlisted = widget.product['is_wishlisted'] ?? false;
  }

  void _proceedToCheckout() {
    if (_selectedFlavor == null || _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select flavor and size')));
      return;
    }
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          product: widget.product,
          flavor: _selectedFlavor!,
          size: _selectedSize!,
          quantity: _quantity,
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> flavors = widget.product['available_flavors']?.split(',') ?? ['Vanilla'];
    List<String> sizes = widget.product['available_sizes']?.split(',') ?? ['500g', '1kg'];

    void _addToCart() async {
      if (_selectedFlavor == null || _selectedSize == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select flavor and size for cart')));
        return;
      }
      try {
        await ApiService().post('orders/cart/add_item/', {
          'product_id': widget.product['id'],
          'quantity': _quantity,
          'flavor': _selectedFlavor,
          'size': _selectedSize,
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to Cart!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add to cart: $e')));
      }
    }

    void _toggleWishlist() async {
      final bool wasWishlisted = _isWishlisted;
      setState(() => _isWishlisted = !wasWishlisted);
      try {
        if (!wasWishlisted) {
          await ApiService().post('orders/wishlist/add_item/', {
            'product_id': widget.product['id'],
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to Wishlist!')));
        } else {
          await ApiService().delete('orders/wishlist/remove_item/', data: {
            'product_id': widget.product['id'],
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed from Wishlist')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isWishlisted = wasWishlisted);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update wishlist')));
        }
      }
    }

    void _showRatingDialog() {
      int _currentRating = 5;
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('Rate ${widget.product['name']}'),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _currentRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 36,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _currentRating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await ApiService().post('products/items/${widget.product['id']}/rate/', {
                          'score': _currentRating,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rating submitted!')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit rating.')));
                      }
                    },
                    child: Text('Submit'),
                  ),
                ],
              );
            }
          );
        }
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product['name']),
        actions: [
          IconButton(
            icon: Icon(
              _isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: _isWishlisted ? Colors.red : null,
            ),
            onPressed: _toggleWishlist
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.brown[100],
              child: widget.product['image'] != null
                  ? Image.network(
                      widget.product['image'].toString().startsWith('http') ? widget.product['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                          : 'http://172.20.10.6:8000${widget.product['image']}',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: 100, color: Colors.brown),
                    )
                  : Icon(Icons.cake, size: 100, color: Colors.brown),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${widget.product['base_price']}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                Row(
                  children: [
                     Icon(Icons.star, color: Colors.orange),
                     Text(' ${widget.product['average_rating']?.toStringAsFixed(1) ?? '0.0'} (${widget.product['rating_count'] ?? 0})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     SizedBox(width: 8),
                     TextButton(onPressed: _showRatingDialog, child: Text("Rate")),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(widget.product['description']),
              ...[
                SizedBox(height: 20),
                Text('Select Flavor:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedFlavor,
                  hint: Text('Choose Flavor'),
                  items: flavors.map((e) => DropdownMenuItem(value: e.trim(), child: Text(e.trim()))).toList(),
                  onChanged: (val) => setState(() => _selectedFlavor = val),
                ),
                SizedBox(height: 20),
                Text('Select Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSize,
                  hint: Text('Choose Size'),
                  items: sizes.map((e) => DropdownMenuItem(value: e.trim(), child: Text(e.trim()))).toList(),
                  onChanged: (val) => setState(() => _selectedSize = val),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Text('Quantity:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Spacer(),
                    IconButton(icon: Icon(Icons.remove), onPressed: () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    Text('$_quantity', style: TextStyle(fontSize: 18)),
                    IconButton(icon: Icon(Icons.add), onPressed: () => setState(() => _quantity++)),
                  ],
                ),
                SizedBox(height: 16),
                 ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat with Baker'),
                  onPressed: () {
                    final baker = widget.product['baker'];
                    if (baker != null && baker['user'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            recipientId: baker['user']['id'],
                            recipientName: baker['user']['username'] ?? 'Baker',
                            recipientRole: 'BAKER',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Baker details not available.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.brown[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.shopping_cart),
                        onPressed: _addToCart,
                        label: Text('Add to Cart'),
                        style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 50), foregroundColor: Colors.brown),
                      )
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _proceedToCheckout,
                        child: Text('Checkout'),
                        style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.brown, foregroundColor: Colors.white),
                      )
                    )
                  ]
                ),
                SizedBox(height: 24),
              ]
            ],
          ),
        ),
      );
    }
}
