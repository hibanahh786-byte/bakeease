import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'product_detail_screen.dart';

class CakesScreen extends StatefulWidget {
  @override
  _CakesScreenState createState() => _CakesScreenState();
}

class _CakesScreenState extends State<CakesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _selectedCategory = 'Cakes';
  List<String> _categories = ['All'];
  final Set<int> _wishlistedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _apiService.get('products/categories/');
      if (response.data is List) {
        setState(() {
          _categories = ["All", ...response.data.map((cat) => cat['name'] as String)];
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      String query = 'products/items/?';
      if (_selectedCategory != 'All') {
        query += 'category=$_selectedCategory&';
      }
      final response = await _apiService.get(query);
      setState(() {
        _products = response.data;
        _wishlistedIds.clear();
        for (var p in _products) {
          if (p['is_wishlisted'] == true) _wishlistedIds.add(p['id']);
        }
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load products: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text('Our Bake Catalog', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFD32F2F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _categories[index] == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = _categories[index]);
                    _fetchProducts();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD32F2F) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected ? [
                        BoxShadow(color: const Color(0xFFD32F2F).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                      ] : [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('No products available right now!'))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: product['image'] != null
                                    ? Image.network(
                                        product['image'].toString().startsWith('http') ? product['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                            : 'http://172.20.10.6:8000${product['image']}',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.cake, size: 50, color: Colors.grey)),
                                      )
                                    : const Center(child: Icon(Icons.cake, size: 50, color: Colors.grey)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A3022)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product['baker']['user']['username'],
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.orange, size: 16),
                                          const SizedBox(width: 4),
                                          Text('${product['average_rating']?.toStringAsFixed(1) ?? '0.0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _wishlistedIds.contains(product['id']) ? Icons.favorite : Icons.favorite_border,
                                          color: _wishlistedIds.contains(product['id']) ? Colors.red : const Color(0xFF4A3022),
                                        ),
                                        onPressed: () async {
                                          final int pId = product['id'];
                                          final bool wasWishlisted = _wishlistedIds.contains(pId);
                                          setState(() {
                                            if (wasWishlisted) _wishlistedIds.remove(pId);
                                            else _wishlistedIds.add(pId);
                                          });
                                          try {
                                            if (!wasWishlisted) {
                                              await _apiService.post('orders/wishlist/add_item/', {'product_id': pId});
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Wishlist!')));
                                            } else {
                                              await _apiService.delete('orders/wishlist/remove_item/', data: {'product_id': pId});
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Wishlist')));
                                            }
                                          } catch (e) {
                                            setState(() {
                                              if (wasWishlisted) _wishlistedIds.add(pId);
                                              else _wishlistedIds.remove(pId);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update wishlist')));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
