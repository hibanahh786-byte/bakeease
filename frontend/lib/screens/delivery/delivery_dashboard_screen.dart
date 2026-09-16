import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../auth/login_screen.dart';
import 'delivery_active_order_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({Key? key}) : super(key: key);

  @override
  _DeliveryDashboardScreenState createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _activeTab = 'ACTIVE'; // 'ACTIVE', 'EARNINGS', 'HISTORY'
  Map<String, dynamic>? _financeData;

  // Wallet / Withdrawal Controllers
  final _withdrawAmountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  List<dynamic> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _fetchBankDetails();
  }

  @override
  void dispose() {
    _withdrawAmountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final res = await _apiService.get('users/profile/delivery/');
      final profile = res.data;
      setState(() {
        _bankNameController.text = profile['bank_name'] ?? '';
        _accountNumberController.text = profile['account_number'] ?? '';
        _ifscCodeController.text = profile['ifsc_code'] ?? '';
        _accountHolderNameController.text = profile['account_holder_name'] ?? '';
      });
    } catch (e) {
      print('Error fetching delivery bank details: $e');
    }
  }

  Future<void> _updateBankDetails() async {
    if (_bankNameController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        _ifscCodeController.text.isEmpty ||
        _accountHolderNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All bank details are required.')),
      );
      return;
    }
    try {
      await _apiService.patch('users/profile/delivery/', {
        'bank_name': _bankNameController.text,
        'account_number': _accountNumberController.text,
        'ifsc_code': _ifscCodeController.text,
        'account_holder_name': _accountHolderNameController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank details updated successfully.')),
      );
      _fetchBankDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bank details: ${e.toString()}')),
      );
    }
  }

  Future<void> _requestWithdrawal() async {
    final amount = double.tryParse(_withdrawAmountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }
    try {
      await _apiService.post('finance/withdrawals/', {
        'amount': amount.toString(),
      });
      _withdrawAmountController.clear();
      _fetchOrders(); // Refreshes balance and withdrawals list
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to request withdrawal. Ensure bank details are set and balance is sufficient.')),
      );
    }
  }

  void _showWithdrawalDialog(BuildContext context) {
    if (_bankNameController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        _ifscCodeController.text.isEmpty ||
        _accountHolderNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please update and save your bank details first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Request Withdrawal',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Withdrawal will be sent to:',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                '${_bankNameController.text} (${_accountNumberController.text})',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _withdrawAmountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: '₹',
                    hintText: 'Amount (₹)',
                    hintStyle: GoogleFonts.quicksand(color: Colors.black45, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.quicksand(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: _requestWithdrawal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A3022),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Request',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('orders/list/');
      final financeRes = await _apiService.get('orders/list/delivery_finance_stats/');
      final wRes = await _apiService.get('finance/withdrawals/');
      setState(() {
        _orders = response.data;
        _financeData = financeRes.data;
        _withdrawals = wRes.data;
      });
    } catch (e, stack) {
      print('Error fetching orders: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load data',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFED3F47),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  // Get active assigned orders
  List<dynamic> get _activeOrders {
    return _orders.where((o) => o['status'] != 'DELIVERED' && o['status'] != 'REJECTED').toList();
  }

  // Get completed orders
  List<dynamic> get _completedOrders {
    return _orders.where((o) => o['status'] == 'DELIVERED').toList();
  }

  Widget _buildCapsuleTab(String label, String tabKey, IconData icon) {
    bool isSelected = _activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A3022) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF4A3022).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
          ],
          border: Border.all(
            color: isSelected ? const Color(0xFF4A3022) : const Color(0xFFEFE8E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF4A3022),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : const Color(0xFF4A3022),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandCream = Color(0xFFFFF8F5);
    const Color brandRed = Color(0xFFED3F47);

    return Scaffold(
      backgroundColor: brandCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Delivery Hub',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF4A3022),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A3022)),
            tooltip: 'Refresh tasks',
            onPressed: _fetchOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF4A3022)),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Elegant Header tab bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCapsuleTab('Active Tasks', 'ACTIVE', Icons.pedal_bike),
                _buildCapsuleTab('Earnings', 'EARNINGS', Icons.account_balance_wallet_outlined),
                _buildCapsuleTab('History', 'HISTORY', Icons.history),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: brandRed))
                : RefreshIndicator(
                    color: brandRed,
                    onRefresh: _fetchOrders,
                    child: _buildTabContent(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_activeTab == 'ACTIVE') {
      return _buildActiveTasksTab();
    } else if (_activeTab == 'EARNINGS') {
      return _buildEarningsTab();
    } else {
      return _buildHistoryTab();
    }
  }

  // Tab 1: Active Tasks
  Widget _buildActiveTasksTab() {
    const Color brandRed = Color(0xFFED3F47);
    final tasks = _activeOrders;
    if (tasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF1F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.assignment_turned_in_outlined, color: Colors.grey, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All Caught Up!',
                  style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'No new deliveries assigned at the moment. Keep an eye out for updates!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final order = tasks[index];
        final numItems = order['items']?.length ?? 0;
        final totalAmount = order['total_amount'] ?? '0.00';
        final orderStatus = order['status'];

        Color statusColor = Colors.orange;
        IconData statusIcon = Icons.pending_actions;
        if (orderStatus == 'OUT_FOR_DELIVERY') {
          statusColor = Colors.blue;
          statusIcon = Icons.motorcycle;
        } else if (orderStatus == 'CONFIRMED' || orderStatus == 'ORDER_IN_PROGRESS') {
          statusColor = Colors.green;
          statusIcon = Icons.hourglass_top;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeliveryActiveOrderScreen(order: order),
                ),
              );
              _fetchOrders();
            },
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A3022),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Order #${order['id']}',
                          style: GoogleFonts.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              orderStatus.replaceAll('_', ' '),
                              style: GoogleFonts.quicksand(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PICKUP FROM (BAKER)',
                              style: GoogleFonts.quicksand(
                                color: Colors.grey.shade500,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              order['baker']['user']['username'].toString().toUpperCase(),
                              style: GoogleFonts.quicksand(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4A3022),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Phone: ${order['baker']['contact_number'] ?? 'N/A'}',
                              style: GoogleFonts.quicksand(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DELIVER TO (CUSTOMER)',
                              style: GoogleFonts.quicksand(
                                color: Colors.grey.shade500,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              order['customer']['user']['username'].toString().toUpperCase(),
                              style: GoogleFonts.quicksand(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4A3022),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              order['customer']['address'] ?? 'No Address Listed',
                              style: GoogleFonts.quicksand(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF3EAE0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$numItems item(s) • ₹$totalAmount',
                        style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A3022),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryActiveOrderScreen(order: order),
                            ),
                          );
                          _fetchOrders();
                        },
                        icon: const Icon(Icons.directions_run_outlined, size: 16),
                        label: const Text('Start Task'),
                        style: TextButton.styleFrom(
                          foregroundColor: brandRed,
                          textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Tab 2: Earnings
  Widget _buildEarningsTab() {
    if (_financeData == null) return const Center(child: Text('Loading earnings...'));
    final double totalEarnings = double.tryParse(_financeData!['total_earnings']?.toString() ?? '') ?? 0.0;
    final double pendingAmount = double.tryParse(_financeData!['pending_amount']?.toString() ?? '') ?? 0.0;
    final double paidAmount = double.tryParse(_financeData!['paid_amount']?.toString() ?? '') ?? 0.0;
    final List<dynamic> history = _financeData!['history'] ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Premium Wallet Card
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A3022), Color(0xFF6B4C35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: const Color(0xFF4A3022).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
            ]
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Balance', style: GoogleFonts.quicksand(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('₹${(_financeData!['wallet_balance'] ?? 0.0).toStringAsFixed(2)}', style: GoogleFonts.quicksand(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showWithdrawalDialog(context),
                    icon: const Icon(Icons.send, size: 16),
                    label: Text('Withdraw', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A3022),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Withdrawn', style: GoogleFonts.quicksand(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('₹${(_financeData!['wallet_withdrawn'] ?? 0.0).toStringAsFixed(2)}', style: GoogleFonts.quicksand(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Pending Approval', style: GoogleFonts.quicksand(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('₹${(_financeData!['wallet_pending_withdrawal'] ?? 0.0).toStringAsFixed(2)}', style: GoogleFonts.quicksand(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Premium Earnings Card Grid
        Row(
          children: [
            Expanded(
              child: _buildEarningStatCard(
                'Total Payouts',
                '₹${totalEarnings.toStringAsFixed(2)}',
                Colors.teal.shade50,
                Colors.teal,
                Icons.account_balance_wallet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEarningStatCard(
                'Completed Jobs',
                '${_completedOrders.length} Jobs',
                Colors.blue.shade50,
                Colors.blue,
                Icons.assignment_turned_in,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEarningStatCard(
                'Pending Amount',
                '₹${pendingAmount.toStringAsFixed(2)}',
                Colors.orange.shade50,
                Colors.orange,
                Icons.hourglass_empty,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEarningStatCard(
                'Paid Amount',
                '₹${paidAmount.toStringAsFixed(2)}',
                Colors.purple.shade50,
                Colors.purple,
                Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Weekly Sales Bar Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Performance',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A3022),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 140,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildWeeklyBar('Mon', 0.4),
                      _buildWeeklyBar('Tue', 0.6),
                      _buildWeeklyBar('Wed', 0.8),
                      _buildWeeklyBar('Thu', 0.3),
                      _buildWeeklyBar('Fri', 0.9),
                      _buildWeeklyBar('Sat', 0.7),
                      _buildWeeklyBar('Sun', 0.5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Ledger Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earnings Details (Payout ₹65.00/job)',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A3022),
                  ),
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'No payout records found yet.',
                        style: GoogleFonts.quicksand(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...history.map((o) {
                    final double amount = double.tryParse((o['delivery_person_payable'] ?? o['delivery_charge'] ?? 50.0).toString()) ?? 50.0;
                    final status = o['delivery_payment_status'] ?? 'PENDING_DELIVERY_SETTLEMENT';
                    final isPaid = status == 'PAID_TO_DELIVERY_PERSON';
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.teal.shade50 : Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(isPaid ? Icons.check : Icons.hourglass_bottom, color: isPaid ? Colors.teal : Colors.orange, size: 18),
                          ),
                          title: Text(
                            'Order #${o['id']} Payout',
                            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            status.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.bold,
                              color: isPaid ? Colors.teal : Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Divider(height: 8, color: Color(0xFFF3EAE0)),
                      ],
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        // Registered Bank Details Setup
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registered Bank Details',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A3022),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFormTextField(_accountHolderNameController, 'Account Holder Name'),
                const SizedBox(height: 12),
                _buildFormTextField(_bankNameController, 'Bank Name'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildFormTextField(_accountNumberController, 'Account Number')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormTextField(_ifscCodeController, 'IFSC Code')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A3022),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _updateBankDetails,
                    child: Text('Save Bank Details', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Withdrawal requests history
        if (_withdrawals.isNotEmpty) ...[
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Withdrawal History',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A3022),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._withdrawals.map((req) {
                    final String status = req['status'] ?? 'PENDING';
                    final double amount = double.tryParse(req['amount']?.toString() ?? '') ?? 0.0;
                    
                    Color statusColor = Colors.orange;
                    if (status == 'APPROVED') statusColor = Colors.green;
                    if (status == 'REJECTED') statusColor = Colors.red;

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              status == 'APPROVED' 
                                  ? Icons.check 
                                  : status == 'REJECTED' 
                                      ? Icons.close 
                                      : Icons.hourglass_bottom, 
                              color: statusColor, 
                              size: 18
                            ),
                          ),
                          title: Text(
                            'Withdrawal Request',
                            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${status} • ${req['requested_at']?.split('T')[0] ?? ""}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.quicksand(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Divider(height: 8, color: Color(0xFFF3EAE0)),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEarningStatCard(String label, String value, Color bgColor, Color themeColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE8E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: themeColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color(0xFF4A3022),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.quicksand(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBar(String day, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 14,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE63946), Color(0xFFF07178)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.quicksand(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  // Tab 3: History
  Widget _buildHistoryTab() {
    final pastJobs = _completedOrders;
    if (pastJobs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF8F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.history_toggle_off, color: Colors.grey, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No History Yet',
                  style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your first delivery to see records in this history log.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.quicksand(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: pastJobs.length,
      itemBuilder: (context, index) {
        final order = pastJobs[index];
        final numItems = order['items']?.length ?? 0;
        final totalAmount = order['total_amount'] ?? '0.00';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['id']}',
                      style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.teal, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'DELIVERED',
                            style: GoogleFonts.quicksand(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Customer: ${order['customer']['user']['username'].toString().toUpperCase()}',
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Address: ${order['customer']['address'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Divider(height: 20, color: Color(0xFFF3EAE0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$numItems item(s) • ₹$totalAmount',
                      style: GoogleFonts.quicksand(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      'Earned: ₹${order['delivery_person_payable'] ?? order['delivery_charge'] ?? 50.0}',
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildFormTextField(TextEditingController controller, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFE8E0)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.quicksand(fontWeight: FontWeight.w600, color: const Color(0xFF4A3022)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.quicksand(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
