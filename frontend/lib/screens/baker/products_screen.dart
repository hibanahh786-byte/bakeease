import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../chat/chat_list_screen.dart';
import 'add_product_screen.dart';
import 'stock_management_screen.dart';
import 'product_recipe_screen.dart';
import 'dart:async';

class BakerProductsScreen extends StatefulWidget {
  @override
  _BakerProductsScreenState createState() => _BakerProductsScreenState();
}
class _BakerProductsScreenState extends State<BakerProductsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  int _selectedCategoryIndex = 0; // For the Pills
  String _searchQuery = ''; 

  List<String> _categories = ["All"];

  bool _isDrawerOpen = false;
  int _tickerIndex = 0;
  Timer? _tickerTimer;
  Timer? _simulationTimer1;
  Timer? _simulationTimer2;
  Timer? _simulationTimer3;

  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();

    // Rotate alert ticker
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        final activeAlerts = _notifications.where((n) => !n['isRead']).toList();
        if (activeAlerts.isNotEmpty) {
          setState(() {
            _tickerIndex = (_tickerIndex + 1) % activeAlerts.length;
          });
        }
      }
    });

    _fetchNotifications();

    // Refresh notifications every 15 seconds
    _simulationTimer1 = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _simulationTimer1?.cancel();
    _simulationTimer2?.cancel();
    _simulationTimer3?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await _apiService.get('users/notifications/');
      if (mounted && response.data is List) {
        setState(() {
          _notifications = (response.data as List).map((n) => {
            'id': n['id'],
            'title': n['title'],
            'description': n['message'],
            'isRead': n['is_read'],
            'time': 'Recent', // For simplicity, we could format created_at here
            'type': 'system'
          }).toList();
        });
      }
    } catch (e) {
      // Ignore silently
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.post('users/notifications/mark_all_read/', {});
      _fetchNotifications();
    } catch (e) {
      // Ignore silently
    }
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
    try {
      final response = await _apiService.get('products/items/my/');
      setState(() {
        _products = response.data;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load products.')));
    }
  }

  void _editProduct(dynamic product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductScreen(product: product)),
    );
    if (result == true) {
      _fetchProducts();
    }
  }

  void _showReviews(BuildContext context, dynamic product) {
    final List<dynamic> ratings = product['ratings'] ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reviews: ${product['name']}',
                style: GoogleFonts.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFED3F47),
                ),
              ),
              const SizedBox(height: 16),
              if (ratings.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'No reviews yet for this sweet treat.',
                    style: GoogleFonts.quicksand(fontSize: 16, color: Colors.grey),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: ratings.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final review = ratings[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text('${review['score']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(review['customer_name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(review['review']?.isNotEmpty == true ? review['review'] : 'No written review.', style: GoogleFonts.quicksand()),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertTicker() {
    final activeAlerts = _notifications.where((n) => !n['isRead']).toList();
    if (activeAlerts.isEmpty) {
      return const SizedBox.shrink(); // Hide if no unread alerts
    }
    
    // Safety check for index out of bounds
    if (_tickerIndex >= activeAlerts.length) {
      _tickerIndex = 0;
    }
    
    final alert = activeAlerts[_tickerIndex];
    Color alertBg;
    Color alertText;
    Color alertBorder;
    IconData alertIcon;
    
    switch (alert['type']) {
      case 'stock':
        alertBg = const Color(0xFFFFF3CD);
        alertText = const Color(0xFF856404);
        alertBorder = const Color(0xFFFFEEBA);
        alertIcon = Icons.warning_amber_rounded;
        break;
      case 'order':
        alertBg = const Color(0xFFD1ECF1);
        alertText = const Color(0xFF0C5460);
        alertBorder = const Color(0xFFBEE5EB);
        alertIcon = Icons.shopping_bag_outlined;
        break;
      case 'payout':
        alertBg = const Color(0xFFD4EDDA);
        alertText = const Color(0xFF155724);
        alertBorder = const Color(0xFFC3E6CB);
        alertIcon = Icons.monetization_on_outlined;
        break;
      case 'rating':
        alertBg = const Color(0xFFE2E3E5);
        alertText = const Color(0xFF383D41);
        alertBorder = const Color(0xFFD6D8DB);
        alertIcon = Icons.star_border_rounded;
        break;
      default:
        alertBg = const Color(0xFFF8D7DA);
        alertText = const Color(0xFF721C24);
        alertBorder = const Color(0xFFF5C6CB);
        alertIcon = Icons.notifications_none_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: alertBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: alertBorder),
          boxShadow: [
            BoxShadow(
              color: alertText.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(alertIcon, color: alertText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        alert['title'] ?? '',
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.bold,
                          color: alertText,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        alert['time'] ?? '',
                        style: TextStyle(
                          color: alertText.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert['description'] ?? '',
                    style: GoogleFonts.quicksand(
                      color: alertText.withOpacity(0.9),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close, color: alertText.withOpacity(0.6), size: 16),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  alert['isRead'] = true;
                  if (_tickerIndex >= activeAlerts.length - 1) {
                    _tickerIndex = 0;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationDrawer() {
    if (!_isDrawerOpen) return const SizedBox.shrink();

    return Positioned(
      top: 80, // Positioned right under the header row
      left: 24,
      right: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEFE8E0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header of Drawer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4A3022),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED3F47).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notifications.where((n) => !n['isRead']).length} New',
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFED3F47),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          color: const Color(0xFFE63946),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _isDrawerOpen = false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFE8E0)),
              
              // Notification List
              Flexible(
                child: _notifications.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_off_outlined, color: Colors.grey.shade400, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'All caught up! No notifications.',
                              style: GoogleFonts.quicksand(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5EFE9)),
                        itemBuilder: (context, index) {
                          final alert = _notifications[index];
                          final isUnread = !alert['isRead'];
                          
                          Color iconColor;
                          IconData iconData;
                          
                          switch (alert['type']) {
                            case 'stock':
                              iconColor = const Color(0xFFF5B041);
                              iconData = Icons.warning_amber_rounded;
                              break;
                            case 'order':
                              iconColor = const Color(0xFF3498DB);
                              iconData = Icons.shopping_bag_outlined;
                              break;
                            case 'payout':
                              iconColor = const Color(0xFF2ECC71);
                              iconData = Icons.monetization_on_outlined;
                              break;
                            case 'rating':
                              iconColor = const Color(0xFF9B59B6);
                              iconData = Icons.star_rounded;
                              break;
                            default:
                              iconColor = const Color(0xFFED3F47);
                              iconData = Icons.notifications;
                          }

                          return InkWell(
                            onTap: () {
                              setState(() {
                                alert['isRead'] = !alert['isRead'];
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              color: isUnread ? const Color(0xFFFFF8F5) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                alert['title'] ?? '',
                                                style: GoogleFonts.quicksand(
                                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isUnread ? const Color(0xFF4A3022) : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFED3F47),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          alert['description'] ?? '',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 12,
                                            color: isUnread ? Colors.grey.shade800 : Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          alert['time'] ?? '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _notifications.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: Color(0xFFEFE8E0)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _notifications.clear();
                      _isDrawerOpen = false;
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandRed = Color(0xFFED3F47);
    const Color textDark = Color(0xFF333333);

    List<dynamic> displayedProducts = _products;
    if (_selectedCategoryIndex > 0) {
      String selectedCat = _categories[_selectedCategoryIndex].toLowerCase();
      displayedProducts = displayedProducts.where((p) {
        String catName = (p['category_name'] ?? '').toString().toLowerCase();
        return catName == selectedCat;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      displayedProducts = displayedProducts.where((p) {
        String name = (p['name'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BakeEase',
                          style: GoogleFonts.lobster(
                            fontSize: 32,
                            color: textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage your sweet inventory!',
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.inventory_2_outlined, size: 28),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => StockManagementScreen()));
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 28),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
                        },
                      ),
                      const SizedBox(width: 4),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isDrawerOpen ? Icons.notifications : Icons.notifications_none_outlined,
                              size: 28,
                              color: _isDrawerOpen ? brandRed : Colors.black87,
                            ),
                            onPressed: () {
                              setState(() {
                                _isDrawerOpen = !_isDrawerOpen;
                              });
                            },
                          ),
                          if (_notifications.where((n) => !n['isRead']).isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: brandRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    '${_notifications.where((n) => !n['isRead']).length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: const AssetImage('assets/images/logo.png'), // Mapped to our local logo
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Search Bar & Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: GoogleFonts.quicksand(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: Colors.black, size: 28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            _buildAlertTicker(),
            const SizedBox(height: 16),

            // Category Pills
            SizedBox(
              height: 40,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  bool isSelected = _selectedCategoryIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? brandRed : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: brandRed.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        _categories[index],
                        style: GoogleFonts.quicksand(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Product Grid
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : displayedProducts.isEmpty 
                  ? Center(child: Text('No products found', style: GoogleFonts.quicksand(color: Colors.grey)))
                  : GridView.builder(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: displayedProducts.length,
                      itemBuilder: (context, index) {
                        final product = displayedProducts[index];
                        final String imgUrl = product['image'] != null
                            ? (product['image'].toString().startsWith('http') ? product['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                : 'http://172.20.10.6:8000${product['image']}')
                            : '';

                        return GestureDetector(
                          onTap: () => _editProduct(product), // Edit product on card tap
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Image Component
                                Expanded(
                                  child: Center(
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                          child: imgUrl.isNotEmpty
                                              ? Image.network(
                                                  imgUrl,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (c, e, s) => const Icon(Icons.cake, size: 60, color: Colors.grey),
                                                )
                                              : const Icon(Icons.cake, size: 60, color: Colors.grey),
                                        ),
                                        if (product['allows_customization'] == true)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text('Custom', style: GoogleFonts.quicksand(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Product Details Section
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'],
                                        style: GoogleFonts.quicksand(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      if (product['discount_price'] != null && product['discount_price'].toString().isNotEmpty)
                                        Row(
                                          children: [
                                            Text(
                                              '₹${product['discount_price']}',
                                              style: GoogleFonts.quicksand(
                                                fontSize: 12,
                                                color: brandRed,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '₹${product['base_price']}',
                                              style: GoogleFonts.quicksand(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          '₹${product['base_price']} | Base',
                                          style: GoogleFonts.quicksand(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () {
                                          _showReviews(context, product);
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.orange, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              product['average_rating'] != null ? '${product['average_rating']}' : '0.0',
                                              style: GoogleFonts.quicksand(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ProductRecipeScreen(
                                                      productId: product['id'],
                                                      productName: product['name'],
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: brandRed.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text('Recipe', style: GoogleFonts.quicksand(color: brandRed, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                            ),
                                          ],
                                        ),
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
        _buildNotificationDrawer(),
      ],
    ),
  ),
);
  }
}
