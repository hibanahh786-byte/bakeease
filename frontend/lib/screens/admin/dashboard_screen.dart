import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../common/profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;
  bool _isLoading = false;
  List<dynamic> _bakers = [];
  List<dynamic> _users = [];
  List<dynamic> _orders = [];
  Map<String, dynamic>? _payoutsData;
  List<dynamic> _complaints = [];
  List<dynamic> _withdrawals = [];

  String _userRoleFilter = 'All'; 
  String _escrowFilter = 'All';
  String _escrowStatusFilter = 'ALL';
  String _escrowSearchQuery = '';
  Map<String, dynamic>? _reportsData = {'pending_payouts': 0.0, 'baker_earnings': []};

  List<dynamic> monthlyStats = [];
  List<dynamic> topProducts = [];
  TextEditingController _escrowSearchController = TextEditingController();

  void _confirmPayout(dynamic id) async {
    try { await _apiService.post('orders/admin/payouts/$id/confirm_payout/', {}); _loadTabCurrentData(); } catch(e) { print(e); }
  }
  void _confirmDeliveryPayout(dynamic id) async {
    try { await _apiService.post('orders/admin/payouts/$id/confirm_delivery_payout/', {}); _loadTabCurrentData(); } catch(e) { print(e); }
  }
  void _fetchPayouts() async {
    _loadTabCurrentData();
  }
  
  void _approveWithdrawal(dynamic id) async {
    try {
      await _apiService.post('finance/withdrawals/$id/approve/', {});
      _loadTabCurrentData();
    } catch (e) {
      print('Error approving withdrawal: $e');
    }
  }
  void _resolveComplaint(dynamic id) async {
    try { await _apiService.patch('users/admin/complaints/$id/resolve/', {}); _loadTabCurrentData(); } catch(e) { print(e); }
  }
  void _verifyBaker(dynamic id, bool approve) async {
    try { await _apiService.patch('users/admin/bakers/$id/approve/', {'is_approved': approve}); _loadTabCurrentData(); } catch(e) { print(e); }
  }
  void _toggleUserActive(dynamic id, bool active) async {
    try { await _apiService.patch('users/admin/users/$id/toggle_active/', {'is_active': active}); _loadTabCurrentData(); } catch(e) { print(e); }
  }

 

  @override
  void initState() {
    super.initState();
    _loadTabCurrentData();
  }

  Future<void> _loadTabCurrentData() async {
    setState(() => _isLoading = true);
    try {
      if (_selectedIndex == 0) { // Overview
        final rPayouts = await _apiService.get('orders/admin/payouts/');
        final rReports = await _apiService.get('orders/admin/payouts/reports/');
        final rBakers = await _apiService.get('users/admin/bakers/');
        final rUsers = await _apiService.get('users/admin/users/');
        
        _payoutsData = rPayouts.data;
        _reportsData = rReports.data;
        _bakers = rBakers.data;
        _users = rUsers.data;
        
        monthlyStats = List.from(_reportsData?['monthly_stats'] ?? []);
        topProducts = List.from(_reportsData?['top_products'] ?? []);
      } else if (_selectedIndex == 1) { // Approvals
        final res = await _apiService.get('users/admin/bakers/');
        _bakers = res.data;
      } else if (_selectedIndex == 2) { // Users
        final res = await _apiService.get('users/admin/users/');
        _users = res.data;
      } else if (_selectedIndex == 3) { // Orders
        final res = await _apiService.get('orders/list/');
        _orders = res.data;
      } else if (_selectedIndex == 4) { // Payments
        final res = await _apiService.get('orders/admin/payouts/');
        _payoutsData = res.data;
        try {
          final res2 = await _apiService.get('finance/withdrawals/');
          _withdrawals = res2.data;
        } catch (e) { print(e); }
      } else if (_selectedIndex == 5) { // Complaints
        final res = await _apiService.get('users/admin/complaints/');
        _complaints = res.data;
      }
    } catch (e) {
      print('Error loading tab data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _logout() async {
    await AuthProvider().logout();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  Widget _buildReportsTab() {
    // Calculate dynamic alerts & counts
    final int pendingApprovalsCount = _bakers.where((b) => !(b['is_approved'] ?? false)).length;
    final int blockedAccountsCount = _users.where((u) => !(u['is_active'] ?? true)).length;
    final int activeUsersCount = _users.where((u) => u['is_active'] ?? true).length;
    final double escrowHoldings = _payoutsData?['pending_payouts'] ?? 0.0;
    final Map<String, dynamic> r = _reportsData ?? {};


    // Leaderboard of Top Performing Bakers

    final List<dynamic> bakerEarnings = List.from(_payoutsData?['baker_earnings'] ?? []);

    bakerEarnings.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));

    final List<dynamic> topBakers = bakerEarnings.take(3).toList();



    return ListView(

      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),

      children: [

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(

              'Platform Overview',

              style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

            ),

            IconButton(

              icon: const Icon(Icons.refresh, color: Color(0xFFE63946)),

              onPressed: _loadTabCurrentData,

              tooltip: 'Refresh Dashboard',

            )

          ],

        ),

        const SizedBox(height: 12),



        // Beautiful System Alert Banner if there are pending actions

        if (pendingApprovalsCount > 0 || blockedAccountsCount > 0) ...[

          Container(

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(

              color: const Color(0xFFFFF8F5),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: const Color(0xFFE63946).withOpacity(0.2)),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity(0.02),

                  blurRadius: 10,

                  offset: const Offset(0, 4),

                )

              ]

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    const Icon(Icons.notification_important, color: Color(0xFFE63946), size: 22),

                    const SizedBox(width: 8),

                    Text(

                      'Action Required',

                      style: GoogleFonts.quicksand(

                        fontWeight: FontWeight.bold, 

                        color: const Color(0xFF4A3022),

                        fontSize: 15

                      ),

                    ),

                  ],

                ),

                const Divider(height: 16),

                if (pendingApprovalsCount > 0)

                  ListTile(

                    dense: true,

                    contentPadding: EdgeInsets.zero,

                    leading: CircleAvatar(

                      backgroundColor: Colors.orange.shade50,

                      radius: 14,

                      child: const Icon(Icons.storefront, color: Colors.orange, size: 14),

                    ),

                    title: Text(

                      '$pendingApprovalsCount Baker accounts awaiting registration review.', 

                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)

                    ),

                    trailing: TextButton(

                      onPressed: () => setState(() => _selectedIndex = 1),

                      child: const Text('Verify Now', style: TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.bold, fontSize: 11)),

                    ),

                  ),

                if (blockedAccountsCount > 0)

                  ListTile(

                    dense: true,

                    contentPadding: EdgeInsets.zero,

                    leading: CircleAvatar(

                      backgroundColor: Colors.red.shade50,

                      radius: 14,

                      child: const Icon(Icons.block, color: Colors.red, size: 14),

                    ),

                    title: Text(

                      '$blockedAccountsCount accounts are blocked / inactive.', 

                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)

                    ),

                    trailing: TextButton(

                      onPressed: () => setState(() => _selectedIndex = 2),

                      child: const Text('Manage Users', style: TextStyle(color: Color(0xFF4A3022), fontWeight: FontWeight.bold, fontSize: 11)),

                    ),

                  ),

              ],

            ),

          ),

          const SizedBox(height: 16),

        ],



        // Comprehensive Stat Metrics Grid (9 Cards)

        GridView.count(

          crossAxisCount: 2,

          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          crossAxisSpacing: 12,

          mainAxisSpacing: 12,

          childAspectRatio: 1.35,

          children: [

            _buildStatMetricCard('Gross Revenue', '₹${r['gross_revenue']}', Icons.payments, Colors.teal),

            _buildStatMetricCard('Commissions', '₹${r['total_commission']}', Icons.percent, const Color(0xFFE63946)),

            _buildStatMetricCard('Total Orders', '${r['total_orders']}', Icons.shopping_bag, Colors.blue),

            _buildStatMetricCard('Bakers Registered', '${r['total_bakers']}', Icons.storefront, Colors.orange),

            _buildStatMetricCard('Customers', '${r['total_customers']}', Icons.people, Colors.purple),

            _buildStatMetricCard('Delivery Partners', '${r['total_delivery_persons']}', Icons.delivery_dining, Colors.indigo),

            _buildStatMetricCard('Complaints & Tickets', '${_complaints.length}', Icons.support_agent, Colors.redAccent),

            _buildStatMetricCard('Payments Holdings', '₹$escrowHoldings', Icons.account_balance_wallet, Colors.teal.shade800),

            _buildStatMetricCard('Active Users', '$activeUsersCount', Icons.person_pin_outlined, Colors.green),

            _buildStatMetricCard('Blocked Accounts', '$blockedAccountsCount', Icons.block_flipped, Colors.blueGrey),

          ],

        ),

        const SizedBox(height: 24),



        // Monthly revenue & commission trend

        Card(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          color: Colors.white,

          elevation: 2,

          child: Padding(

            padding: const EdgeInsets.all(16.0),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text('Monthly Revenue & Commission Trend', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

                const SizedBox(height: 20),

                if (monthlyStats.isEmpty)

                  const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No historical data available yet')))

                else

                  Row(

                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: monthlyStats.map<Widget>((stat) {

                      double rev = (stat['revenue'] as num).toDouble();

                      double com = (stat['commission'] as num).toDouble();

                      

                      // Normalize heights

                      double maxVal = 50000.0;

                      double revHeight = (rev / maxVal * 100).clamp(10, 100);

                      double comHeight = (com / maxVal * 100).clamp(5, 70);



                      return Column(

                        children: [

                          Row(

                            crossAxisAlignment: CrossAxisAlignment.end,

                            children: [

                              Container(

                                width: 12,

                                height: revHeight,

                                decoration: BoxDecoration(

                                  color: Colors.teal.shade300,

                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),

                                ),

                              ),

                              const SizedBox(width: 4),

                              Container(

                                width: 12,

                                height: comHeight,

                                decoration: BoxDecoration(

                                  color: const Color(0xFFE63946).withOpacity(0.8),

                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),

                                ),

                              ),

                            ],

                          ),

                          const SizedBox(height: 8),

                          Text(stat['month'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),

                        ],

                      );

                    }).toList(),

                  ),

                const SizedBox(height: 12),

                Row(

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [

                    Container(width: 12, height: 12, color: Colors.teal.shade300),

                    const SizedBox(width: 4),

                    const Text('Revenue', style: TextStyle(fontSize: 12, color: Colors.grey)),

                    const SizedBox(width: 16),

                    Container(width: 12, height: 12, color: const Color(0xFFE63946).withOpacity(0.8)),

                    const SizedBox(width: 4),

                    const Text('Commission', style: TextStyle(fontSize: 12, color: Colors.grey)),

                  ],

                )

              ],

            ),

          ),

        ),

        const SizedBox(height: 24),



        // Leaderboard of Top Performing Bakers

        Text('Top Performing Bakers', style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

        const SizedBox(height: 8),

        Card(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          color: Colors.white,

          elevation: 2,

          child: Padding(

            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),

            child: topBakers.isEmpty

                ? const ListTile(title: Text('No baker sales recorded yet'))

                : Column(

                    children: [

                      ...topBakers.asMap().entries.map<Widget>((entry) {

                        final idx = entry.key;

                        final baker = entry.value;

                        

                        IconData prizeIcon = Icons.star;

                        Color prizeColor = Colors.grey;

                        if (idx == 0) {

                          prizeIcon = Icons.emoji_events;

                          prizeColor = Colors.amber.shade700;

                        } else if (idx == 1) {

                          prizeIcon = Icons.military_tech;

                          prizeColor = Colors.blueGrey;

                        } else if (idx == 2) {

                          prizeIcon = Icons.military_tech_outlined;

                          prizeColor = Colors.orange.shade800;

                        }



                        return ListTile(

                          leading: CircleAvatar(

                            backgroundColor: const Color(0xFFFFF8F5),

                            child: Icon(prizeIcon, color: prizeColor),

                          ),

                          title: Text(

                            baker['username'] ?? 'Baker',

                            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

                          ),

                          subtitle: Text('Released: ₹${baker['completed']} | Pending: ₹${baker['pending']}'),

                          trailing: Container(

                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

                            decoration: BoxDecoration(

                              color: Colors.teal.shade50,

                              borderRadius: BorderRadius.circular(8),

                            ),

                            child: Text(

                              '₹${baker['total']}',

                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),

                            ),

                          ),

                        );

                      }).toList(),

                    ],

                  ),

          ),

        ),

        const SizedBox(height: 24),



        // Popular Products

        Text('Top Selling Products', style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

        const SizedBox(height: 8),

        Card(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

          color: Colors.white,

          elevation: 2,

          child: Padding(

            padding: const EdgeInsets.symmetric(vertical: 8.0),

            child: topProducts.isEmpty

                ? const ListTile(title: Text('No order items recorded yet'))

                : Column(

                    children: topProducts.map<Widget>((prod) {

                      return ListTile(

                        leading: const CircleAvatar(

                          backgroundColor: Color(0xFFFFF8F5),

                          child: Icon(Icons.cake, color: Color(0xFFE63946)),

                        ),

                        title: Text(prod['name'], style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),

                        subtitle: Text('${prod['total_sold']} units sold'),

                        trailing: Text('₹${prod['total_revenue']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),

                      );

                    }).toList(),

                  ),

          ),

        ),

      ],

    );

  }



  Widget _buildStatMetricCard(String title, String val, IconData icon, Color color) {

    return Card(

      elevation: 2,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      child: Padding(

        padding: const EdgeInsets.all(12.0),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Row(

              children: [

                Icon(icon, color: color, size: 24),

                const Spacer(),

                const Icon(Icons.trending_up, color: Colors.green, size: 16),

              ],

            ),

            const SizedBox(height: 12),

            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A3022))),

            const SizedBox(height: 4),

            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),

          ],

        ),

      ),

    );

  }



  // --- TAB 2: APPROVALS ---

  Widget _buildApprovalsTab() {

    final pendingBakers = _bakers.where((b) => !b['is_approved']).toList();



    if (pendingBakers.isEmpty) {

      return Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),

            const SizedBox(height: 16),

            Text(

              'All Caught Up!',

              style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

            ),

            const SizedBox(height: 8),

            const Text('No pending baker approval requests.', style: TextStyle(color: Colors.grey)),

          ],

        ),

      );

    }



    return ListView.builder(

      itemCount: pendingBakers.length,

      padding: const EdgeInsets.only(bottom: 100, top: 12),

      itemBuilder: (ctx, index) {

        final baker = pendingBakers[index];

        final user = baker['user'] ?? {};



        return Card(

          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          color: Colors.white,

          elevation: 3,

          child: Padding(

            padding: const EdgeInsets.all(16.0),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    CircleAvatar(

                      backgroundColor: const Color(0xFFFFF8F5),

                      radius: 24,

                      child: const Icon(Icons.store, color: Color(0xFFE63946), size: 28),

                    ),

                    const SizedBox(width: 12),

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            user['username'] ?? 'Baker ID: ${baker['id']}',

                            style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

                          ),

                          Text(

                            'Email: ${user['email'] ?? 'N/A'}',

                            style: const TextStyle(fontSize: 12, color: Colors.grey),

                          ),

                        ],

                      ),

                    ),

                    Container(

                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

                      decoration: BoxDecoration(

                        color: Colors.orange.shade50,

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(color: Colors.orange.shade200),

                      ),

                      child: Text(

                        'PENDING',

                        style: TextStyle(color: Colors.orange.shade800, fontSize: 9, fontWeight: FontWeight.bold),

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 16),

                const Divider(),

                const SizedBox(height: 8),

                

                Text(

                  'Baker Details & Document Verification',

                  style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

                ),

                const SizedBox(height: 12),

                

                _buildDetailRow(Icons.phone_android, 'Contact Number', baker['contact_number'] ?? 'Not Provided'),

                _buildDetailRow(Icons.badge, 'FSSAI License Number', baker['fssai_number'] ?? 'Not Provided'),

                _buildDetailRow(Icons.location_on, 'Profile Address', 'BakeEase Registered Baker Outlet'),

                

                if (baker['fssai_document'] != null) ...[

                  const SizedBox(height: 12),

                  _buildDocumentRow(Icons.description, 'FSSAI Registration Certificate', baker['fssai_document']),

                ],

                

                if (baker['qr_code_image'] != null) ...[

                  const SizedBox(height: 12),

                  _buildDocumentRow(Icons.qr_code, 'Payment Setup QR Code', baker['qr_code_image']),

                ],

                

                const SizedBox(height: 16),

                const Divider(),

                const SizedBox(height: 8),

                

                Row(

                  mainAxisAlignment: MainAxisAlignment.end,

                  children: [

                    OutlinedButton.icon(

                      onPressed: () => _verifyBaker(baker['id'], false),

                      icon: const Icon(Icons.close, size: 16),

                      label: const Text('Reject'),

                      style: OutlinedButton.styleFrom(

                        foregroundColor: Colors.red,

                        side: const BorderSide(color: Colors.red),

                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

                      ),

                    ),

                    const SizedBox(width: 12),

                    ElevatedButton.icon(

                      onPressed: () => _verifyBaker(baker['id'], true),

                      icon: const Icon(Icons.check, size: 16),

                      label: const Text('Approve Baker'),

                      style: ElevatedButton.styleFrom(

                        backgroundColor: Colors.green,

                        foregroundColor: Colors.white,

                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

                      ),

                    ),

                  ],

                )

              ],

            ),

          ),

        );

      },

    );

  }



  Widget _buildDetailRow(IconData icon, String label, String value) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4.0),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Icon(icon, size: 16, color: Colors.grey.shade600),

          const SizedBox(width: 8),

          Expanded(

            child: RichText(

              text: TextSpan(

                style: const TextStyle(fontSize: 13, color: Colors.black87),

                children: [

                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3022))),

                  TextSpan(text: value),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildDocumentRow(IconData icon, String label, String fileUrl) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4.0),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Icon(icon, size: 16, color: const Color(0xFFE63946)),

          const SizedBox(width: 8),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  label,

                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A3022)),

                ),

                const SizedBox(height: 4),

                InkWell(

                  onTap: () {

                    _showDocumentViewerDialog(label, fileUrl);

                  },

                  borderRadius: BorderRadius.circular(8),

                  child: Container(

                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                    decoration: BoxDecoration(

                      color: const Color(0xFFFFF8F5),

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(color: const Color(0xFFE63946).withOpacity(0.2)),

                    ),

                    child: Row(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        const Icon(Icons.open_in_new, size: 14, color: Color(0xFFE63946)),

                        const SizedBox(width: 6),

                        Flexible(

                          child: Text(

                            fileUrl.split('/').last,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(

                              fontSize: 11,

                              color: Color(0xFFE63946),

                              fontWeight: FontWeight.bold,

                            ),

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  void _showDocumentViewerDialog(String title, String url) {

    showDialog(

      context: context,

      builder: (ctx) {

        String fullUrl = url;

        if (!url.startsWith('http://') && !url.startsWith('https://')) {

          fullUrl = 'http://172.20.10.6:8000' + url;

        } else {

          fullUrl = fullUrl.replaceAll('127.0.0.1:8000', '172.20.10.6:8000').replaceAll('localhost:8000', '172.20.10.6:8000');

        }

        

        bool isImage = fullUrl.toLowerCase().endsWith('.png') || 

                      fullUrl.toLowerCase().endsWith('.jpg') || 

                      fullUrl.toLowerCase().endsWith('.jpeg') || 

                      fullUrl.toLowerCase().endsWith('.gif');

                      

        return AlertDialog(

          backgroundColor: const Color(0xFFFFF8F5),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          title: Text(title, style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

          content: Container(

            width: double.maxFinite,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                if (isImage)

                  ClipRRect(

                    borderRadius: BorderRadius.circular(12),

                    child: Image.network(

                      fullUrl,

                      errorBuilder: (context, error, stackTrace) {

                        return Container(

                          padding: const EdgeInsets.all(24),

                          color: Colors.grey.shade100,

                          child: Column(

                            children: [

                              const Icon(Icons.broken_image, size: 48, color: Colors.grey),

                              const SizedBox(height: 12),

                              Text('Failed to load image preview.', style: TextStyle(color: Colors.grey.shade600)),

                              const SizedBox(height: 8),

                              Text(fullUrl, style: const TextStyle(fontSize: 8, color: Colors.grey), textAlign: TextAlign.center),

                            ],

                          ),

                        );

                      },

                    ),

                  )

                else

                  Container(

                    padding: const EdgeInsets.all(24),

                    width: double.maxFinite,

                    decoration: BoxDecoration(

                      color: Colors.grey.shade100,

                      borderRadius: BorderRadius.circular(12),

                    ),

                    child: Column(

                      children: [

                        const Icon(Icons.picture_as_pdf, size: 48, color: Color(0xFFE63946)),

                        const SizedBox(height: 12),

                        const Text('Verification Certificate Document', style: TextStyle(fontWeight: FontWeight.bold)),

                        const SizedBox(height: 8),

                        Text(fullUrl.split('/').last, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),

                      ],

                    ),

                  ),

                const SizedBox(height: 16),

                Text(

                  'Administrative verification of platform credentials. Ensure compliance before approval.',

                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),

                  textAlign: TextAlign.center,

                ),

              ],

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(ctx),

              child: Text('Close', style: GoogleFonts.quicksand(color: const Color(0xFF4A3022), fontWeight: FontWeight.bold)),

            ),

          ],

        );

      },

    );

  }



  // --- TAB 3: USERS ---

  Widget _buildUsersTab() {

    List<dynamic> filteredUsers = _users.where((user) {

      if (_userRoleFilter == 'ALL') return true;

      return user['role'] == _userRoleFilter;

    }).toList();



    return Column(

      children: [

        // Role filters

        Container(

          height: 50,

          margin: const EdgeInsets.only(top: 12),

          child: ListView(

            scrollDirection: Axis.horizontal,

            padding: const EdgeInsets.symmetric(horizontal: 16),

            children: [

              _buildRoleFilterChip('ALL', 'All Users'),

              _buildRoleFilterChip('BAKER', 'Bakers'),

              _buildRoleFilterChip('CUSTOMER', 'Customers'),

              _buildRoleFilterChip('DELIVERY_PERSON', 'Delivery'),

            ],

          ),

        ),

        Expanded(

          child: filteredUsers.isEmpty

              ? const Center(child: Text('No users matching criteria.'))

              : ListView.builder(

                  itemCount: filteredUsers.length,

                  padding: const EdgeInsets.only(bottom: 100, top: 8),

                  itemBuilder: (ctx, index) {

                    final user = filteredUsers[index];

                    bool active = user['is_active'] ?? true;

                    String role = user['role'] ?? 'CUSTOMER';



                    Color pillColor = Colors.blue.shade100;

                    Color pillText = Colors.blue.shade800;

                    if (role == 'BAKER') {

                      pillColor = Colors.purple.shade100;

                      pillText = Colors.purple.shade800;

                    } else if (role == 'DELIVERY_PERSON') {

                      pillColor = Colors.orange.shade100;

                      pillText = Colors.orange.shade800;

                    } else if (role == 'ADMIN') {

                      pillColor = Colors.red.shade100;

                      pillText = Colors.red.shade800;

                    }



                    return Card(

                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                      child: ListTile(

                        leading: CircleAvatar(

                          backgroundColor: const Color(0xFFFFF8F5),

                          child: Icon(

                            role == 'BAKER' ? Icons.storefront : (role == 'DELIVERY_PERSON' ? Icons.delivery_dining : Icons.person),

                            color: const Color(0xFF4A3022),

                          ),

                        ),

                        title: Text(user['username'], style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),

                        subtitle: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            const SizedBox(height: 4),

                            Row(

                              children: [

                                Container(

                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                                  decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(12)),

                                  child: Text(role, style: TextStyle(color: pillText, fontSize: 10, fontWeight: FontWeight.bold)),

                                ),

                                const SizedBox(width: 8),

                                Expanded(

                                  child: Text(

                                    user['email'] ?? '',

                                    style: const TextStyle(fontSize: 12, color: Colors.grey),

                                    overflow: TextOverflow.ellipsis,

                                  ),

                                ),

                              ],

                            )

                          ],

                        ),

                        trailing: Switch(

                          value: active,

                          activeColor: const Color(0xFFE63946),

                          onChanged: (val) => _toggleUserActive(user['id'], val),

                        ),

                      ),

                    );

                  },

                ),

        )

      ],

    );

  }



  Widget _buildRoleFilterChip(String role, String label) {

    bool selected = _userRoleFilter == role;

    return GestureDetector(

      onTap: () => setState(() => _userRoleFilter = role),

      child: Container(

        margin: const EdgeInsets.only(right: 8),

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        decoration: BoxDecoration(

          color: selected ? const Color(0xFF4A3022) : Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: const Color(0xFF4A3022).withOpacity(0.2)),

        ),

        child: Center(

          child: Text(

            label,

            style: GoogleFonts.quicksand(

              color: selected ? Colors.white : const Color(0xFF4A3022),

              fontWeight: FontWeight.bold,

              fontSize: 12,

            ),

          ),

        ),

      ),

    );

  }



  // --- TAB 4: ORDERS ---

  Widget _buildOrdersTab() {

    if (_orders.isEmpty) {

      return Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey),

            const SizedBox(height: 16),

            Text('No orders in the system.', style: GoogleFonts.quicksand(fontSize: 18, color: const Color(0xFF4A3022))),

          ],

        ),

      );

    }



    return ListView.builder(

      itemCount: _orders.length,

      padding: const EdgeInsets.only(bottom: 100, top: 12),

      itemBuilder: (ctx, index) {

        final order = _orders[index];

        final String status = order['status'] ?? 'PENDING';

        

        Color badgeBg = Colors.amber.shade100;

        Color badgeTxt = Colors.amber.shade800;

        if (status == 'DELIVERED') {

          badgeBg = Colors.green.shade100;

          badgeTxt = Colors.green.shade800;

        } else if (status == 'REJECTED') {

          badgeBg = Colors.red.shade100;

          badgeTxt = Colors.red.shade800;

        } else if (status == 'CONFIRMED' || status == 'ORDER_IN_PROGRESS') {

          badgeBg = Colors.blue.shade100;

          badgeTxt = Colors.blue.shade800;

        }



        return Card(

          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

          child: Padding(

            padding: const EdgeInsets.all(12.0),

            child: Column(

              children: [

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    Text('Order #${order['id']}', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16)),

                    Container(

                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),

                      child: Text(status, style: TextStyle(color: badgeTxt, fontSize: 11, fontWeight: FontWeight.bold)),

                    ),

                  ],

                ),

                const SizedBox(height: 12),

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text('Customer: ${order['customer']?['user']?['username'] ?? 'Customer'}', style: const TextStyle(fontSize: 13)),

                        const SizedBox(height: 4),

                        Text('Baker: ${order['baker']?['user']?['username'] ?? 'Baker'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),

                      ],

                    ),

                    Text('₹${order['total_amount']}', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),

                  ],

                ),

              ],

            ),

          ),

        );

      },

    );

  }



  // --- TAB 5: PAYMENTS WALLET ---

  Widget _buildEscrowTab() {

    if (_payoutsData == null) return const Center(child: Text('Failed to load payments data. Ensure backend is running.', style: TextStyle(color: Color(0xFF4A3022))));



    final d = _payoutsData!;

    final List<dynamic> orders = d['orders'] ?? [];

    final pendingPayoutOrders = orders.where((o) => o['payment_status'] == 'PENDING_BAKER_SETTLEMENT').toList();

    final pendingDeliveryOrders = orders.where((o) => o['delivery_payment_status'] == 'PENDING_DELIVERY_SETTLEMENT').toList();



    return SingleChildScrollView(

      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text('Payments Financial Ledger', style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

          const SizedBox(height: 16),

          

          // Gorgeous grid of metrics

          GridView.count(

            crossAxisCount: 2,

            shrinkWrap: true,

            physics: const NeverScrollableScrollPhysics(),

            crossAxisSpacing: 12,

            mainAxisSpacing: 12,

            childAspectRatio: 1.35,

            children: [

              _buildEscrowCard('Gross Volume', '₹${d['total_received']}', Icons.account_balance, Colors.teal),

              _buildEscrowCard('Reserve Hold', '₹${d['pending_payouts']}', Icons.hourglass_empty, Colors.orange),

              _buildEscrowCard('Payouts Released', '₹${d['completed_payouts']}', Icons.check_circle_outline, Colors.green),

              _buildEscrowCard('Admin Commissions', '₹${d['total_commission']}', Icons.percent, const Color(0xFFE63946)),

              _buildEscrowCard('Refunds Processed', '₹${d['total_refunded']}', Icons.assignment_return_outlined, Colors.deepPurple),

              _buildEscrowCard('Financial Report', 'Generate', Icons.summarize_outlined, const Color(0xFF4A3022), onTap: () => _showFinancialReportDialog(context)),

            ],

          ),

          const SizedBox(height: 28),



          // Baker-wise earnings ledger

          Card(

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

            color: Colors.white,

            elevation: 2,

            child: Padding(

              padding: const EdgeInsets.all(16.0),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      const Icon(Icons.storefront, color: Color(0xFF4A3022)),

                      const SizedBox(width: 8),

                      Text(

                        'Baker-Wise Earnings Ledger',

                        style: GoogleFonts.quicksand(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                          color: const Color(0xFF4A3022),

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 12),

                  const Divider(),

                  if (d['baker_earnings'] == null || (d['baker_earnings'] as List).isEmpty)

                    const Padding(

                      padding: EdgeInsets.symmetric(vertical: 16.0),

                      child: Center(

                        child: Text(

                          'No baker earnings records found.',

                          style: TextStyle(color: Colors.grey),

                        ),

                      ),

                    )

                  else

                    ... (d['baker_earnings'] as List).map<Widget>((baker) {

                      return Padding(

                        padding: const EdgeInsets.symmetric(vertical: 8.0),

                        child: Row(

                          children: [

                            CircleAvatar(

                              backgroundColor: const Color(0xFFFFF8F5),

                              radius: 18,

                              child: Text(

                                baker['username'].toString().isNotEmpty 

                                    ? baker['username'].toString().substring(0, 1).toUpperCase() 

                                    : 'B',

                                style: const TextStyle(

                                  color: Color(0xFFE63946),

                                  fontWeight: FontWeight.bold,

                                ),

                              ),

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    baker['username'] ?? 'Baker',

                                    style: GoogleFonts.quicksand(

                                      fontWeight: FontWeight.bold,

                                      color: const Color(0xFF4A3022),

                                    ),

                                  ),

                                  Text(

                                    'Pending Payout: ₹${baker['pending']}',

                                    style: TextStyle(

                                      fontSize: 11,

                                      color: Colors.orange.shade700,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                            Column(

                              crossAxisAlignment: CrossAxisAlignment.end,

                              children: [

                                Text(

                                  '₹${baker['total']}',

                                  style: GoogleFonts.quicksand(

                                    fontWeight: FontWeight.bold,

                                    color: Colors.teal,

                                  ),

                                ),

                                Text(

                                  'Released: ₹${baker['completed']}',

                                  style: TextStyle(

                                    fontSize: 11,

                                    color: Colors.grey.shade600,

                                  ),

                                ),

                              ],

                            ),

                          ],

                        ),

                      );

                    }).toList(),

                ],

              ),

            ),

          ),

          const SizedBox(height: 28),



          // Delivery-wise earnings ledger

          Card(

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

            color: Colors.white,

            elevation: 2,

            child: Padding(

              padding: const EdgeInsets.all(16.0),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      const Icon(Icons.delivery_dining, color: Color(0xFF4A3022)),

                      const SizedBox(width: 8),

                      Text(

                        'Delivery-Wise Earnings Ledger',

                        style: GoogleFonts.quicksand(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                          color: const Color(0xFF4A3022),

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 12),

                  const Divider(),

                  if (d['delivery_earnings'] == null || (d['delivery_earnings'] as List).isEmpty)

                    const Padding(

                      padding: EdgeInsets.symmetric(vertical: 16.0),

                      child: Center(

                        child: Text(

                          'No delivery earnings records found.',

                          style: TextStyle(color: Colors.grey),

                        ),

                      ),

                    )

                  else

                    ... (d['delivery_earnings'] as List).map<Widget>((delivery) {

                      return Padding(

                        padding: const EdgeInsets.symmetric(vertical: 8.0),

                        child: Row(

                          children: [

                            CircleAvatar(

                              backgroundColor: const Color(0xFFFFF8F5),

                              radius: 18,

                              child: Text(

                                delivery['username'].toString().isNotEmpty 

                                    ? delivery['username'].toString().substring(0, 1).toUpperCase() 

                                    : 'D',

                                style: const TextStyle(

                                  color: Color(0xFFE63946),

                                  fontWeight: FontWeight.bold,

                                ),

                              ),

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    delivery['username'] ?? 'Delivery Person',

                                    style: GoogleFonts.quicksand(

                                      fontWeight: FontWeight.bold,

                                      color: const Color(0xFF4A3022),

                                    ),

                                  ),

                                  Text(

                                    'Pending Payout: ₹${delivery['pending']}',

                                    style: TextStyle(

                                      fontSize: 11,

                                      color: Colors.orange.shade700,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                            Column(

                              crossAxisAlignment: CrossAxisAlignment.end,

                              children: [

                                Text(

                                  '₹${delivery['total']}',

                                  style: GoogleFonts.quicksand(

                                    fontWeight: FontWeight.bold,

                                    color: Colors.teal,

                                  ),

                                ),

                                Text(

                                  'Released: ₹${delivery['completed']}',

                                  style: TextStyle(

                                    fontSize: 11,

                                    color: Colors.grey.shade600,

                                  ),

                                ),

                              ],

                            ),

                          ],

                        ),

                      );

                    }).toList(),

                ],

              ),

            ),

          ),

          const SizedBox(height: 28),



          // Search & Filters Title

          Text('Search & Transaction Ledger', style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

          const SizedBox(height: 12),



          // Search field

          Container(

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(16),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity(0.04),

                  blurRadius: 8,

                  offset: const Offset(0, 2),

                ),

              ],

            ),

            child: TextField(

              controller: _escrowSearchController,

              onChanged: (val) {

                setState(() {

                  _escrowSearchQuery = val;

                });

                _fetchPayouts();

              },

              decoration: InputDecoration(

                hintText: 'Search by Order ID, Baker, or Customer...',

                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A3022)),

                suffixIcon: _escrowSearchQuery.isNotEmpty

                    ? IconButton(

                        icon: const Icon(Icons.clear, color: Colors.grey),

                        onPressed: () {

                          _escrowSearchController.clear();

                          setState(() {

                            _escrowSearchQuery = '';

                          });

                          _fetchPayouts();

                        },

                      )

                    : null,

                border: InputBorder.none,

                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

              ),

            ),

          ),

          const SizedBox(height: 12),



          // Filter chips

          Container(

            height: 42,

            child: ListView(

              scrollDirection: Axis.horizontal,

              children: [

                _buildEscrowFilterChip('ALL', 'All Payments'),

                _buildEscrowFilterChip('PENDING_PAYMENT', 'Pending Customer'),

                _buildEscrowFilterChip('PAID_BY_CUSTOMER', 'Paid by Customer'),

                _buildEscrowFilterChip('PENDING_BAKER_SETTLEMENT', 'Pending Settlement'),

                _buildEscrowFilterChip('PAID_TO_BAKER', 'Disbursed to Baker'),

              ],

            ),

          ),

          const SizedBox(height: 20),



          // Pending baker payouts section (quick actions)

          if (pendingPayoutOrders.isNotEmpty && _escrowStatusFilter == 'ALL') ...[

            Text('Pending Baker Payout Actions', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

            const SizedBox(height: 10),

            ...pendingPayoutOrders.map<Widget>((order) {

              return Card(

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                margin: const EdgeInsets.symmetric(vertical: 6),

                child: ListTile(

                  leading: const CircleAvatar(

                    backgroundColor: Color(0xFFFFF8F5),

                    child: Icon(Icons.hourglass_empty, color: Colors.orange),

                  ),

                  title: Text('Order #${order['id']} (Baker: ${order['baker']?['user']?['username'] ?? order['baker']})', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),

                  subtitle: Text('Total Amount: ₹${order['total_amount']}\nPayable Baker Share: ₹${order['baker_payable']}'),

                  trailing: ElevatedButton(

                    onPressed: () => _confirmPayout(order['id']),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: const Color(0xFFE63946),

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                    ),

                    child: const Text('Disburse'),

                  ),

                ),

              );

            }).toList(),

            const SizedBox(height: 24),

          ],



          // Pending delivery payouts section (quick actions)

          if (pendingDeliveryOrders.isNotEmpty && _escrowStatusFilter == 'ALL') ...[

            Text('Pending Delivery Payout Actions', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

            const SizedBox(height: 10),

            ...pendingDeliveryOrders.map<Widget>((order) {

              return Card(

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                margin: const EdgeInsets.symmetric(vertical: 6),

                child: ListTile(

                  leading: const CircleAvatar(

                    backgroundColor: Color(0xFFFFF8F5),

                    child: Icon(Icons.delivery_dining, color: Colors.orange),

                  ),

                  title: Text('Order #${order['id']} (Delivery: ${order['delivery_person']?['user']?['username'] ?? 'N/A'})', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),

                  subtitle: Text('Delivery Charge: ₹${order['delivery_charge']}\nPayable Share: ₹${order['delivery_person_payable']}'),

                  trailing: ElevatedButton(

                    onPressed: () => _confirmDeliveryPayout(order['id']),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: const Color(0xFFE63946),

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                    ),

                    child: const Text('Disburse'),

                  ),

                ),

              );

            }).toList(),

            const SizedBox(height: 24),

          ],



          // Transaction ledger orders

          Text(

            _escrowStatusFilter == 'ALL' && _escrowSearchQuery.isEmpty ? 'Recent Transactions' : 'Search Results',

            style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))

          ),

          const SizedBox(height: 10),

          orders.isEmpty

              ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No matching transactions found.', style: TextStyle(color: Colors.grey))))

              : ListView.builder(

                  shrinkWrap: true,

                  physics: const NeverScrollableScrollPhysics(),

                  itemCount: orders.length,

                  itemBuilder: (context, i) {

                    final order = orders[i];

                    final String paymentStatus = order['payment_status'] ?? 'PENDING_PAYMENT';

                    final String orderStatus = order['status'] ?? 'PENDING';

                    final bool isRefunded = orderStatus == 'REJECTED' && paymentStatus != 'PENDING_PAYMENT';



                    Color statusBg = Colors.grey.shade100;

                    Color statusTxt = Colors.grey.shade800;

                    String statusLabel = paymentStatus;



                    if (isRefunded) {

                      statusBg = Colors.purple.shade100;

                      statusTxt = Colors.purple.shade800;

                      statusLabel = 'REFUNDED';

                    } else if (paymentStatus == 'PENDING_PAYMENT') {

                      statusBg = Colors.amber.shade100;

                      statusTxt = Colors.amber.shade800;

                      statusLabel = 'PENDING CUSTOMER';

                    } else if (paymentStatus == 'PAID_BY_CUSTOMER') {

                      statusBg = Colors.blue.shade100;

                      statusTxt = Colors.blue.shade800;

                      statusLabel = 'PAID BY CUSTOMER';

                    } else if (paymentStatus == 'PENDING_BAKER_SETTLEMENT') {

                      statusBg = Colors.orange.shade100;

                      statusTxt = Colors.orange.shade800;

                      statusLabel = 'PENDING BAKER SETTLEMENT';

                    } else if (paymentStatus == 'PAID_TO_BAKER') {

                      statusBg = Colors.green.shade100;

                      statusTxt = Colors.green.shade800;

                      statusLabel = 'DISBURSED TO BAKER';

                    }



                    return Card(

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                      margin: const EdgeInsets.symmetric(vertical: 6),

                      child: Padding(

                        padding: const EdgeInsets.all(12.0),

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Row(

                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [

                                Text('Order #${order['id']}', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 15)),

                                Container(

                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),

                                  child: Text(statusLabel, style: TextStyle(color: statusTxt, fontSize: 10, fontWeight: FontWeight.bold)),

                                ),

                              ],

                            ),

                            const SizedBox(height: 8),

                            Row(

                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [

                                Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    Text('Customer: ${order['customer']?['user']?['username'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),

                                    const SizedBox(height: 2),

                                    Text('Baker: ${order['baker']?['user']?['username'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),

                                  ],

                                ),

                                Text('₹${order['total_amount']}', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),

                              ],

                            ),

                            const Divider(height: 16),

                            Row(

                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [

                                Text(

                                  'Commission (10%): ₹${order['admin_commission'] ?? (double.parse(order['total_amount'].toString()) * 0.1).toStringAsFixed(1)}',

                                  style: const TextStyle(fontSize: 11, color: Colors.grey)

                                ),

                                Text(

                                  'Baker Share: ₹${order['baker_payable'] ?? (double.parse(order['total_amount'].toString()) * 0.9).toStringAsFixed(1)}',

                                  style: const TextStyle(fontSize: 11, color: Colors.grey)

                                ),

                              ],

                            ),

                            if (paymentStatus == 'PENDING_BAKER_SETTLEMENT' && !isRefunded) ...[

                              const SizedBox(height: 8),

                              Align(

                                alignment: Alignment.centerRight,

                                child: ElevatedButton.icon(

                                  onPressed: () => _confirmPayout(order['id']),

                                  icon: const Icon(Icons.send, size: 14),

                                  label: const Text('Disburse Baker Share', style: TextStyle(fontSize: 11)),

                                  style: ElevatedButton.styleFrom(

                                    backgroundColor: const Color(0xFFE63946),

                                    foregroundColor: Colors.white,

                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                                  ),

                                ),

                              ),

                            ]

                          ],

                        ),

                      ),

                    );

                  },

                )

        ],

      ),

    );

  }



  Widget _buildEscrowCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {

    return InkWell(

      onTap: onTap,

      borderRadius: BorderRadius.circular(20),

      child: Container(

        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(20),

          boxShadow: [

            BoxShadow(

              color: color.withOpacity(0.04),

              blurRadius: 8,

              offset: const Offset(0, 3),

            ),

          ],

          border: Border.all(color: color.withOpacity(0.12), width: 1.5),

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Container(

                  padding: const EdgeInsets.all(6),

                  decoration: BoxDecoration(

                    color: color.withOpacity(0.08),

                    shape: BoxShape.circle,

                  ),

                  child: Icon(icon, color: color, size: 18),

                ),

                if (onTap != null)

                  Icon(Icons.arrow_forward, color: color.withOpacity(0.6), size: 14),

              ],

            ),

            const SizedBox(height: 8),

            Text(

              value,

              style: GoogleFonts.quicksand(

                fontSize: 18,

                fontWeight: FontWeight.bold,

                color: const Color(0xFF4A3022),

              ),

            ),

            const SizedBox(height: 2),

            Text(

              title,

              style: TextStyle(

                color: Colors.grey.shade600,

                fontSize: 10,

                fontWeight: FontWeight.w600,

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildEscrowFilterChip(String status, String label) {

    bool selected = _escrowStatusFilter == status;

    return GestureDetector(

      onTap: () {

        setState(() {

          _escrowStatusFilter = status;

        });

        _fetchPayouts();

      },

      child: Container(

        margin: const EdgeInsets.only(right: 8),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        decoration: BoxDecoration(

          color: selected ? const Color(0xFFE63946) : Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(

            color: selected ? const Color(0xFFE63946) : const Color(0xFF4A3022).withOpacity(0.15),

          ),

        ),

        child: Center(

          child: Text(

            label,

            style: GoogleFonts.quicksand(

              color: selected ? Colors.white : const Color(0xFF4A3022),

              fontWeight: FontWeight.bold,

              fontSize: 11,

            ),

          ),

        ),

      ),

    );

  }



  void _showFinancialReportDialog(BuildContext context) {

    if (_reportsData == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Reports data not available. Please wait...')),

      );

      return;

    }

    final r = _reportsData!;

    final List<dynamic> monthlyStats = r['monthly_stats'] ?? [];

    final List<dynamic> topProducts = r['top_products'] ?? [];



    showDialog(

      context: context,

      builder: (ctx) {

        return AlertDialog(

          backgroundColor: const Color(0xFFFFF8F5),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

          title: Row(

            children: [

              const Icon(Icons.summarize, color: Color(0xFFE63946)),

              const SizedBox(width: 8),

              Text(

                'Financial Statement',

                style: GoogleFonts.quicksand(

                  fontWeight: FontWeight.bold,

                  color: const Color(0xFF4A3022),

                  fontSize: 18,

                ),

              ),

            ],

          ),

          content: Container(

            width: double.maxFinite,

            child: ListView(

              shrinkWrap: true,

              children: [

                Text(

                  'BakeEase Platform Financial Statement',

                  style: GoogleFonts.quicksand(

                    fontSize: 13,

                    fontWeight: FontWeight.w600,

                    color: Colors.grey.shade700,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  'Generated on: ${DateTime.now().toLocal().toString().split(' ').first}',

                  style: const TextStyle(fontSize: 11, color: Colors.grey),

                ),

                const Divider(height: 24),

                

                // Key summaries

                _buildReportRow('Gross Platform Sales', '₹${r['gross_revenue']}', Colors.teal.shade700, isBold: true),

                _buildReportRow('Admin Commission Share', '₹${r['total_commission']}', const Color(0xFFE63946), isBold: true),

                _buildReportRow('Total Completed Orders', '${r['total_orders']}', Colors.blue.shade700),

                if (_payoutsData != null) ...[

                  _buildReportRow('Total Payouts Released', '₹${_payoutsData!['completed_payouts']}', Colors.green.shade700),

                  _buildReportRow('Active Payments Holdings', '₹${_payoutsData!['pending_payouts']}', Colors.orange.shade700),

                  _buildReportRow('Refunded Customer Sales', '₹${_payoutsData!['total_refunded']}', Colors.red.shade700),

                ],

                const Divider(height: 24),



                Text(

                  'Monthly Revenue Trend',

                  style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

                ),

                const SizedBox(height: 8),

                if (monthlyStats.isEmpty)

                  const Text('No historical monthly records.', style: TextStyle(color: Colors.grey, fontSize: 12))

                else

                  Table(

                    border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade200)),

                    children: [

                      TableRow(

                        decoration: BoxDecoration(color: const Color(0xFF4A3022).withOpacity(0.05)),

                        children: [

                          Padding(padding: const EdgeInsets.all(6.0), child: Text('Month', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 12))),

                          Padding(padding: const EdgeInsets.all(6.0), child: Text('Revenue', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 12))),

                          Padding(padding: const EdgeInsets.all(6.0), child: Text('Commission', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 12))),

                        ],

                      ),

                      ...monthlyStats.map((stat) {

                        return TableRow(

                          children: [

                            Padding(padding: const EdgeInsets.all(6.0), child: Text(stat['month'], style: const TextStyle(fontSize: 12))),

                            Padding(padding: const EdgeInsets.all(6.0), child: Text('₹${stat['revenue']}', style: const TextStyle(fontSize: 12, color: Colors.teal))),

                            Padding(padding: const EdgeInsets.all(6.0), child: Text('₹${stat['commission']}', style: const TextStyle(fontSize: 12, color: Color(0xFFE63946)))),

                          ],

                        );

                      }).toList(),

                    ],

                  ),

                const SizedBox(height: 16),



                Text(

                  'Top Performing Products',

                  style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),

                ),

                const SizedBox(height: 8),

                if (topProducts.isEmpty)

                  const Text('No sales records to evaluate.', style: TextStyle(color: Colors.grey, fontSize: 12))

                else

                  Column(

                    children: topProducts.map((p) {

                      return Padding(

                        padding: const EdgeInsets.symmetric(vertical: 4.0),

                        child: Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            Text(p['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),

                            Text('${p['total_sold']} units (₹${p['total_revenue']})', style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),

                          ],

                        ),

                      );

                    }).toList(),

                  ),

              ],

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(ctx),

              child: Text(

                'Done',

                style: GoogleFonts.quicksand(

                  color: const Color(0xFF4A3022),

                  fontWeight: FontWeight.bold,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  Widget _buildReportRow(String label, String val, Color valColor, {bool isBold = false}) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4.0),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(

            label,

            style: TextStyle(

              fontSize: 12,

              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,

              color: const Color(0xFF4A3022),

            ),

          ),

          Text(

            val,

            style: GoogleFonts.quicksand(

              fontSize: 13,

              fontWeight: FontWeight.bold,

              color: valColor,

            ),

          ),

        ],

      ),

    );

  }



  // --- TAB 6: COMPLAINTS ---

  Widget _buildComplaintsTab() {

    if (_complaints.isEmpty) {

      return Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(Icons.support_agent, size: 72, color: Colors.grey),

            const SizedBox(height: 16),

            Text('No active complaints or tickets.', style: GoogleFonts.quicksand(fontSize: 18, color: const Color(0xFF4A3022))),

          ],

        ),

      );

    }



    return ListView.builder(

      itemCount: _complaints.length,

      padding: const EdgeInsets.only(bottom: 100, top: 12),

      itemBuilder: (ctx, index) {

        final ticket = _complaints[index];

        final String status = ticket['status'] ?? 'PENDING';

        final bool resolved = status == 'RESOLVED';



        return Card(

          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

          child: Padding(

            padding: const EdgeInsets.all(16.0),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    Container(

                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                      decoration: BoxDecoration(

                        color: resolved ? Colors.green.shade100 : Colors.red.shade100,

                        borderRadius: BorderRadius.circular(12),

                      ),

                      child: Text(

                        status,

                        style: TextStyle(

                          color: resolved ? Colors.green.shade800 : Colors.red.shade800,

                          fontSize: 10,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                    ),

                    Text(

                      ticket['created_at'].toString().split('T').first,

                      style: const TextStyle(fontSize: 12, color: Colors.grey),

                    ),

                  ],

                ),

                const SizedBox(height: 10),

                Text(ticket['subject'], style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022))),

                const SizedBox(height: 6),

                Text(ticket['description'], style: const TextStyle(fontSize: 13, color: Colors.black87)),

                const Divider(),

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    Row(

                      children: [

                        const Icon(Icons.person, size: 16, color: Colors.grey),

                        const SizedBox(width: 4),

                        Text(

                          '${ticket['username']} (${ticket['user_role']})',

                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),

                        ),

                      ],

                    ),

                    if (!resolved)

                      TextButton.icon(

                        onPressed: () => _resolveComplaint(ticket['id']),

                        icon: const Icon(Icons.check_circle, size: 16, color: Colors.green),

                        label: const Text('Resolve', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),

                      )

                    else

                      const Icon(Icons.check_circle, color: Colors.green),

                  ],

                ),

              ],

            ),

          ),

        );

      },

    );

  }



  // --- CUSTOM CAPSULE CHIPS NAVIGATION ---

  Widget _buildNavChip(IconData icon, String label, int index) {

    bool isSelected = _selectedIndex == index;

    return GestureDetector(

      onTap: () {
        setState(() => _selectedIndex = index);
        _loadTabCurrentData();
      },

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 250),

        margin: const EdgeInsets.only(right: 8),

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

        decoration: BoxDecoration(

          color: isSelected ? const Color(0xFFE63946) : const Color(0xFF4A3022).withOpacity(0.15),

          borderRadius: BorderRadius.circular(20),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(

              icon,

              color: isSelected ? Colors.white : const Color(0xFF4A3022),

              size: 18,

            ),

            const SizedBox(width: 8),

            Text(

              label,

              style: GoogleFonts.quicksand(

                color: isSelected ? Colors.white : const Color(0xFF4A3022),

                fontWeight: FontWeight.bold,

                fontSize: 12,

              ),

            ),

          ],

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      extendBody: true,

      backgroundColor: const Color(0xFFFFF8F5), // Premium Creamy Cream background

      appBar: PreferredSize(

        preferredSize: const Size.fromHeight(70),

        child: AppBar(

          elevation: 0,

          backgroundColor: Colors.transparent,

          flexibleSpace: Container(

            decoration: const BoxDecoration(

              color: Color(0xFF4A3022),

              borderRadius: BorderRadius.only(

                bottomLeft: Radius.circular(28),

                bottomRight: Radius.circular(28),

              ),

              boxShadow: [

                BoxShadow(

                  color: Colors.black12,

                  blurRadius: 10,

                  offset: Offset(0, 4),

                )

              ]

            ),

          ),

          iconTheme: const IconThemeData(color: Colors.white),

          title: Row(

            children: [

              Container(

                decoration: const BoxDecoration(

                  shape: BoxShape.circle,

                  color: Colors.white,

                ),

                padding: const EdgeInsets.all(4),

                child: Image.asset(

                  'assets/images/logo.png',

                  height: 28,

                  errorBuilder: (_, __, ___) => const Icon(Icons.cake, color: Color(0xFFE63946)),

                ),

              ),

              const SizedBox(width: 12),

              Text(

                'Admin Hub',

                style: GoogleFonts.quicksand(

                  color: Colors.white,

                  fontWeight: FontWeight.bold,

                  fontSize: 20,

                ),

              ),

            ],

          ),

          actions: [

            IconButton(

              icon: const Icon(Icons.person, color: Color(0xFFE63946)), 

              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()))

            ),

            IconButton(

              icon: const Icon(Icons.logout, color: Color(0xFFE63946)), 

              onPressed: _logout

            ),

            const SizedBox(width: 8),

          ],

        ),

      ),

      body: Column(

        children: [

          // Scrollable navigation chips bar

          Container(

            height: 52,

            margin: const EdgeInsets.only(top: 16, bottom: 8),

            child: ListView(

              scrollDirection: Axis.horizontal,

              padding: const EdgeInsets.symmetric(horizontal: 16),

              children: [

                _buildNavChip(Icons.insert_chart, 'Overview', 0),

                _buildNavChip(Icons.storefront, 'Approvals', 1),

                _buildNavChip(Icons.people, 'Users', 2),

                _buildNavChip(Icons.shopping_bag, 'Orders', 3),

                _buildNavChip(Icons.account_balance_wallet, 'Payments', 4),

                _buildNavChip(Icons.support_agent, 'Complaints', 5),

              ],

            ),

          ),

          Expanded(

            child: _isLoading

                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE63946))))

                : RefreshIndicator(

                    onRefresh: () async {

                      _loadTabCurrentData();

                    },

                    color: const Color(0xFFE63946),

                    child: AnimatedSwitcher(

                      duration: const Duration(milliseconds: 300),

                      switchInCurve: Curves.easeIn,

                      switchOutCurve: Curves.easeOut,

                      child: _selectedIndex == 0

                          ? _buildReportsTab()

                          : _selectedIndex == 1

                              ? _buildApprovalsTab()

                              : _selectedIndex == 2

                                  ? _buildUsersTab()

                                  : _selectedIndex == 3

                                      ? _buildOrdersTab()

                                      : _selectedIndex == 4

                                          ? _buildEscrowTab()

                                          : _buildComplaintsTab(),

                    ),

                  ),

          ),

        ],

      ),

    );

  }

}

