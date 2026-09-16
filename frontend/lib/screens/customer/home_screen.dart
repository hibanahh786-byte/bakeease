import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../services/api_service.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'wishlist_screen.dart';
import '../common/profile_screen.dart';
import 'orders_screen.dart';
import 'cakes_screen.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../chat/chat_list_screen.dart';


class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  static final List<Widget> _widgetOptions = <Widget>[
    const CustomerProductsView(),
    ProfileScreen(),
    CustomerOrdersScreen(),
    CustomerWishlistScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerCartScreen()));
        },
        backgroundColor: const Color(0xFFE63946),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFFE63946),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(icon: Icon(_selectedIndex == 0 ? Icons.home : Icons.home_outlined, color: Colors.white, size: 28), onPressed: () => _onItemTapped(0)),
              IconButton(icon: Icon(_selectedIndex == 1 ? Icons.person : Icons.person_outline, color: Colors.white, size: 28), onPressed: () => _onItemTapped(1)),
              const SizedBox(width: 48), // Space for FAB
              IconButton(icon: Icon(_selectedIndex == 2 ? Icons.list_alt : Icons.list_alt_outlined, color: Colors.white, size: 28), onPressed: () => _onItemTapped(2)),
              IconButton(icon: Icon(_selectedIndex == 3 ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 28), onPressed: () => _onItemTapped(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerProductsView extends StatefulWidget {
  const CustomerProductsView({super.key});

  @override
  State<CustomerProductsView> createState() => _CustomerProductsViewState();
}

class _CustomerProductsViewState extends State<CustomerProductsView> {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedOrdering = '';
  List<String> _categories = ['All'];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final Set<int> _wishlistedIds = {};
  int _currentCarouselIndex = 0;

  bool _isDrawerOpen = false;
  int _tickerIndex = 0;
  Timer? _tickerTimer;
  Timer? _simulationTimer1;
  Timer? _simulationTimer2;
  Timer? _simulationTimer3;

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'init-1',
      'title': 'Welcome to BakeEase! 🍰',
      'description': 'Discover delicious sweets from verified local bakers. Order now!',
      'type': 'system',
      'time': 'Just now',
      'isRead': false,
    },
    {
      'id': 'init-2',
      'title': 'Special Promo Code Inside 🥳',
      'description': 'Enjoy ordering fresh home bakes directly from local passion kitchen artisans.',
      'type': 'promo',
      'time': '1 hour ago',
      'isRead': true,
    }
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();

    // Rotate alert ticker every 4 seconds
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

    // Simulated customer alerts
    _simulationTimer1 = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _notifications.insert(0, {
            'id': 'sim-1',
            'title': '🍰 Welcome to BakeEase!',
            'description': 'Explore custom tiered cakes, fresh pastries, and authentic home bakeries in your area!',
            'type': 'system',
            'time': 'Just now',
            'isRead': false,
          });
        });
      }
    });

    _simulationTimer2 = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _notifications.insert(0, {
            'id': 'sim-2',
            'title': '🎉 Code BAKE10 Active!',
            'description': 'Unlock a sweet 10% discount on any artisan dessert using discount code BAKE10 at checkout.',
            'type': 'promo',
            'time': 'Just now',
            'isRead': false,
          });
        });
      }
    });

    _simulationTimer3 = Timer(const Duration(seconds: 14), () {
      if (mounted) {
        setState(() {
          _notifications.insert(0, {
            'id': 'sim-3',
            'title': '🚴‍♂️ Order #33 Dispatched!',
            'description': 'Your Strawberry Gateau from Baker Hasna is out for delivery. Hot & fresh on the way!',
            'type': 'order_update',
            'time': 'Just now',
            'isRead': false,
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _simulationTimer1?.cancel();
    _simulationTimer2?.cancel();
    _simulationTimer3?.cancel();
    _simulationTimer3?.cancel();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
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
      if (_searchController.text.isNotEmpty) {
        query += 'search=${_searchController.text}&';
      }
      if (_locationController.text.isNotEmpty) {
        query += 'location=${_locationController.text}&';
      }
      if (_selectedOrdering.isNotEmpty) {
        query += 'ordering=$_selectedOrdering&';
      }
      
      final response = await _apiService.get(query);
      setState(() {
        _products = response.data;
        _wishlistedIds.clear();
        for (var p in _products) {
          if (p['is_wishlisted'] == true) {
            _wishlistedIds.add(p['id']);
          }
        }
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load products: ${e.message}')));
    }
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
      case 'promo':
        alertBg = const Color(0xFFFFF3CD);
        alertText = const Color(0xFF856404);
        alertBorder = const Color(0xFFFFEEBA);
        alertIcon = Icons.discount_outlined;
        break;
      case 'order_update':
        alertBg = const Color(0xFFD1ECF1);
        alertText = const Color(0xFF0C5460);
        alertBorder = const Color(0xFFBEE5EB);
        alertIcon = Icons.local_shipping_outlined;
        break;
      case 'system':
        alertBg = const Color(0xFFFFF8F5);
        alertText = const Color(0xFF4A3022);
        alertBorder = const Color(0xFFEFE8E0);
        alertIcon = Icons.cake_outlined;
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
              color: alertText.withValues(alpha: 0.05),
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
                      Expanded(
                        child: Text(
                          alert['title'] ?? '',
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.bold,
                            color: alertText,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alert['time'] ?? '',
                        style: TextStyle(
                          color: alertText.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert['description'] ?? '',
                    style: GoogleFonts.quicksand(
                      color: alertText.withValues(alpha: 0.9),
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
              icon: Icon(Icons.close, color: alertText.withValues(alpha: 0.6), size: 16),
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
      top: 80, // Positioned right under the header row overlaying the carousel
      left: 20,
      right: 20,
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
                color: Colors.black.withValues(alpha: 0.06),
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
                        color: const Color(0xFFE63946).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notifications.where((n) => !n['isRead']).length} New',
                        style: GoogleFonts.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE63946),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (var n in _notifications) {
                            n['isRead'] = true;
                          }
                        });
                      },
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
                            case 'promo':
                              iconColor = const Color(0xFFF5B041);
                              iconData = Icons.discount_outlined;
                              break;
                            case 'order_update':
                              iconColor = const Color(0xFF3498DB);
                              iconData = Icons.local_shipping_outlined;
                              break;
                            case 'system':
                              iconColor = const Color(0xFF8D6E63);
                              iconData = Icons.cake_outlined;
                              break;
                            default:
                              iconColor = const Color(0xFFE63946);
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
                                       color: iconColor.withValues(alpha: 0.1),
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
                                                   color: Color(0xFFE63946),
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
    return _isLoading 
        ? const SafeArea(child: Center(child: CircularProgressIndicator()))
        : Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        // BACKGROUND CAROUSEL
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 520.0,
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 4),
                            viewportFraction: 1.0,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _currentCarouselIndex = index;
                              });
                            },
                          ),
                          items: [
                            'assets/images/carousel_1.jpg',
                            'assets/images/carousel_2.jpg',
                            'assets/images/carousel_3.jpg',
                            'assets/images/carousel_4.jpg'
                          ].map((imagePath) {
                            return SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Image.asset(imagePath, fit: BoxFit.cover),
                            );
                          }).toList(),
                        ),
                        
                        // FOREGROUND GRADIENT & UI
                        Container(
                          height: 520.0,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black54, Colors.transparent, Colors.black87],
                              stops: [0.0, 0.4, 1.0],
                            ),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Image.asset('assets/images/logo.png', height: 40),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Order your favourite bake!',
                                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      // Premium Header Action Bell Widget
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 26,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => const ChatListScreen(),
                                                ),
                                              );
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
                                                  color: Colors.white,
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
                                                  color: Color(0xFFE63946),
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
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // 2. Search & Filter
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(25),
                                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                          ),
                                          child: TextField(
                                            controller: _searchController,
                                            onSubmitted: (_) => _fetchProducts(),
                                            textInputAction: TextInputAction.search,
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Search for \'Desserts\'',
                                              hintStyle: TextStyle(color: Colors.grey.shade600),
                                              prefixIcon: const Icon(Icons.search, color: Colors.black54),
                                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(25),
                                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                          ),
                                          child: TextField(
                                            controller: _locationController,
                                            onSubmitted: (_) => _fetchProducts(),
                                            textInputAction: TextInputAction.search,
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'City / Location',
                                              hintStyle: TextStyle(color: Colors.grey.shade600),
                                              prefixIcon: const Icon(Icons.location_on, color: Colors.black54),
                                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        height: 50,
                                        width: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE63946),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.tune, color: Colors.white),
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                              builder: (context) {
                                                return SafeArea(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(20.0),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3022))),
                                                        const SizedBox(height: 16),
                                                        ListTile(
                                                          title: const Text('Price: Low to High'),
                                                          trailing: _selectedOrdering == 'base_price' ? const Icon(Icons.check, color: Color(0xFFE63946)) : null,
                                                          onTap: () { setState(() => _selectedOrdering = 'base_price'); Navigator.pop(context); _fetchProducts(); },
                                                        ),
                                                        ListTile(
                                                          title: const Text('Price: High to Low'),
                                                          trailing: _selectedOrdering == '-base_price' ? const Icon(Icons.check, color: Color(0xFFE63946)) : null,
                                                          onTap: () { setState(() => _selectedOrdering = '-base_price'); Navigator.pop(context); _fetchProducts(); },
                                                        ),
                                                        ListTile(
                                                          title: const Text('Name (A-Z)'),
                                                          trailing: _selectedOrdering == 'name' ? const Icon(Icons.check, color: Color(0xFFE63946)) : null,
                                                          onTap: () { setState(() => _selectedOrdering = 'name'); Navigator.pop(context); _fetchProducts(); },
                                                        ),
                                                        ListTile(
                                                          title: const Text('Clear Filters', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                          onTap: () { setState(() => _selectedOrdering = ''); Navigator.pop(context); _fetchProducts(); },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Typography Overlay
                                Center(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'NEVER STOP WISHING',
                                        style: TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.white),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'CLASSIC CAKES',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => CakesScreen()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFFE63946),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        child: const Text('ORDER NOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      const SizedBox(height: 48),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // CAROUSEL DOTS
                        Positioned(
                          bottom: 16.0,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [0, 1, 2, 3].map((index) {
                              return Container(
                                width: 10.0,
                                height: 10.0,
                                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentCarouselIndex == index ? Colors.white : Colors.white.withValues(alpha: 0.4),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Horizontal Live Ticker Alert Bar
                    _buildAlertTicker(),
                    
                    // 3. Categories
                    SizedBox(
                      height: 40,
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
                                color: isSelected ? const Color(0xFFE63946) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFFE63946).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
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
                    const SizedBox(height: 24),

                    // 4. Products Grid
                    _products.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No products available.')))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Image
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                              child: product['image'] != null
                                                  ? Image.network(
                                                      product['image'].toString().startsWith('http') ? product['image'].toString().replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000')
                                                          : 'http://172.20.10.6:8000${product['image']}',
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.cake, size: 50, color: Colors.grey)),
                                                    )
                                                  : const Center(child: Icon(Icons.cake, size: 50, color: Colors.grey)),
                                            ),
                                          ),
                                          // Texts
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
                                                        color: _wishlistedIds.contains(product['id']) ? Colors.red : const Color(0xFF4A3022)
                                                      ),
                                                      onPressed: () async {
                                                        final int pId = product['id'];
                                                        final bool wasWishlisted = _wishlistedIds.contains(pId);
                                                        setState(() {
                                                          if (wasWishlisted) {
                                                            _wishlistedIds.remove(pId);
                                                          } else {
                                                            _wishlistedIds.add(pId);
                                                          }
                                                        });
                                                        try {
                                                          if (!wasWishlisted) {
                                                            await _apiService.post('orders/wishlist/add_item/', {'product_id': pId});
                                                            if (!context.mounted) return;
                                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Wishlist!')));
                                                          } else {
                                                            await _apiService.delete('orders/wishlist/remove_item/', data: {'product_id': pId});
                                                            if (!context.mounted) return;
                                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Wishlist')));
                                                          }
                                                        } catch (e) {
                                                          setState(() {
                                                            if (wasWishlisted) {
                                                              _wishlistedIds.add(pId);
                                                            } else {
                                                              _wishlistedIds.remove(pId);
                                                            }
                                                          });
                                                          if (!context.mounted) return;
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
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
              _buildNotificationDrawer(),
            ],
          );
  }
}


