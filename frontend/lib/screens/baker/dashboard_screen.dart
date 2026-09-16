import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_provider.dart';
import '../auth/login_screen.dart';
import 'products_screen.dart';
import 'orders_screen.dart';
import 'finance_screen.dart';
import '../common/profile_screen.dart';
import 'add_product_screen.dart';

class BakerDashboardScreen extends StatefulWidget {
  @override
  _BakerDashboardScreenState createState() => _BakerDashboardScreenState();
}

class _BakerDashboardScreenState extends State<BakerDashboardScreen> {
  int _selectedIndex = 0;
  bool _isRefreshing = false;
  
  static final List<Widget> _widgetOptions = <Widget>[
    BakerProductsScreen(),
    BakerOrdersScreen(),
    BakerFinanceScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _refreshStatus() async {
    setState(() => _isRefreshing = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.fetchUserRole();
    if (mounted) {
      setState(() => _isRefreshing = false);
      if (auth.isApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Congratulations! Your account is approved and activated!',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification still in progress. Please check back later.',
              style: GoogleFonts.quicksand(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPendingVerificationView(BuildContext context, AuthProvider auth) {
    const Color brandRed = Color(0xFFED3F47);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), // Soft creamy white background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'BakeEase Portal',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF4A3022),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF4A3022)),
            onPressed: () async {
              await auth.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.hourglass_empty, color: Colors.orange, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Registration Completed!',
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A3022),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VERIFICATION PENDING',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Checklist',
                        style: GoogleFonts.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A3022),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildChecklistItem(true, 'Baker Registration Completed'),
                      _buildChecklistItem(true, 'Profile & Credentials Submitted'),
                      _buildChecklistItem(false, 'FSSAI License Number Verification', subtitle: 'Checking regulatory compliance'),
                      _buildChecklistItem(false, 'Payment Setup QR Code Validation', subtitle: 'Checking payments settlement parameters'),
                      _buildChecklistItem(false, 'Platform Authorization & Activation', subtitle: 'Administrative activation'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'To ensure platform security, authenticity, and premium service quality, our administrative team manually reviews every baker registration. This process typically takes 1-2 business days. Once approved, all bakery features will instantly unlock!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: _isRefreshing
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _refreshStatus,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View Profile Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A3022),
                    side: const BorderSide(color: Color(0xFF4A3022)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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

  Widget _buildChecklistItem(bool completed, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: completed ? FontWeight.bold : FontWeight.w500,
                    color: completed ? const Color(0xFF4A3022) : Colors.grey.shade600,
                  ),
                ),
                if (subtitle != null && !completed) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    // Check if the baker profile is not approved yet
    if (!auth.isApproved) {
      return _buildPendingVerificationView(context, auth);
    }

    const Color brandRed = Color(0xFFED3F47); // Extracted from mockup

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF9F9F9), // Light background for the dashboard
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Semantics(
        label: 'Add New Product',
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddProductScreen()),
            );
          },
          backgroundColor: brandRed,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: brandRed,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // Left Side
              _buildNavItem(Icons.home_outlined, 0),    // Home (Products)
              _buildNavItem(Icons.person_outline, 3),   // User (Profile)
              
              const SizedBox(width: 40), // Spacer for central FAB notch
              
              // Right Side
              _buildNavItem(Icons.receipt_long_outlined, 1),             // Orders
              _buildNavItem(Icons.bar_chart, 2),                         // Finance / Report
            ],
          ),
        ),
      ),
    );
  }
}
