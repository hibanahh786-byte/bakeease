import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BakerFinanceScreen extends StatefulWidget {
  @override
  _BakerFinanceScreenState createState() => _BakerFinanceScreenState();
}

class _BakerFinanceScreenState extends State<BakerFinanceScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _expenses = [];
  List<dynamic> _invoices = [];
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _escrow;
  bool _isLoading = true;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Wallet / Withdrawal Controllers
  final _withdrawAmountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  List<dynamic> _withdrawals = [];
  
  String _selectedCategory = 'OTHER';
  String _reportPeriod = 'weekly';

  final Map<String, String> _categories = {
    'ELECTRICITY': 'Electricity',
    'GAS': 'Gas',
    'FUEL': 'Fuel',
    'RAW_MATERIALS': 'Raw Materials',
    'WAGES': 'Employee Wages',
    'OTHER': 'Other',
  };

  final Map<String, IconData> _categoryIcons = {
    'ELECTRICITY': Icons.flash_on,
    'GAS': Icons.local_fire_department,
    'FUEL': Icons.local_gas_station,
    'RAW_MATERIALS': Icons.shopping_basket,
    'WAGES': Icons.people,
    'OTHER': Icons.receipt_long,
  };

  final Map<String, Color> _categoryColors = {
    'ELECTRICITY': Colors.amber,
    'GAS': Colors.orange,
    'FUEL': Colors.blue,
    'RAW_MATERIALS': Colors.teal,
    'WAGES': Colors.purple,
    'OTHER': Colors.grey,
  };

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _withdrawAmountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchFinanceData();
    _fetchBankDetails();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final res = await _apiService.get('users/profile/baker/');
      final profile = res.data;
      setState(() {
        _bankNameController.text = profile['bank_name'] ?? '';
        _accountNumberController.text = profile['account_number'] ?? '';
        _ifscCodeController.text = profile['ifsc_code'] ?? '';
        _accountHolderNameController.text = profile['account_holder_name'] ?? '';
      });
    } catch (e) {
      print('Error fetching profile: $e');
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
      await _apiService.patch('users/profile/baker/', {
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
      _fetchFinanceData(); // Refreshes balance and withdrawals list
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
              _buildTextField(_withdrawAmountController, 'Amount (₹)', '₹'),
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

  Future<void> _fetchFinanceData() async {
    try {
      final dbRes = await _apiService.get('finance/dashboard/');
      final expRes = await _apiService.get('finance/expenses/');
      final escrowRes = await _apiService.get('orders/list/finance_stats/');
      final wRes = await _apiService.get('finance/withdrawals/');
      
      setState(() {
        _dashboardData = dbRes.data;
        _expenses = expRes.data;
        _escrow = escrowRes.data;
        _withdrawals = wRes.data;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load finance data.')));
    }
  }

  void _addExpense() async {
    if (_amountController.text.isEmpty || _descriptionController.text.isEmpty) return;

    try {
      await _apiService.post('finance/expenses/', {
        'title': _descriptionController.text,
        'description': _descriptionController.text,
        'amount': _amountController.text,
        'category': _selectedCategory,
        'date_incurred': DateTime.now().toIso8601String().split('T')[0],
      });
      _amountController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = 'OTHER';
      });
      _fetchFinanceData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add expense. \${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_dashboardData == null || _escrow == null) {
      return const Center(child: Text('Failed to load finance data. Please try again.'));
    }

    final d = _dashboardData!;
    final e = _escrow!;
    const Color brandRed = Color(0xFFED3F47);
    const Color textDark = Color(0xFF333333);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Financial Overview',
                      style: GoogleFonts.lobster(fontSize: 32, color: textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: brandRed, size: 28),
                    tooltip: 'Export Report',
                    onPressed: () => _exportPdfReport(d, e),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Low Stock Alerts
              if (d['low_stock_alerts'] != null && (d['low_stock_alerts'] as List).isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                          const SizedBox(width: 8),
                          Text('Low Stock Alerts!', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(d['low_stock_alerts'] as List).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '• ${item['ingredient_name']}: ${item['quantity']} ${item['unit']} remaining (Threshold: ${item['threshold']})',
                            style: GoogleFonts.quicksand(fontSize: 14, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Top Row Stats
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Orders', '${d['total_orders']}', brandRed)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Top Cake', '${d['best_selling_cake']}', Colors.indigo)),
                ],
              ),
              const SizedBox(height: 32),
              Text('Payments Earnings', style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              Container(
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(20),
                   boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                   ]
                 ),
                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                 child: Row(
                   children: [
                      Expanded(child: _buildPaymentInd('Lifetime', e['total_earnings'], Colors.black87)),
                      Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2)),
                      Expanded(child: _buildPaymentInd('Paid', e['paid_amount'], Colors.green.shade600)),
                      Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2)),
                      Expanded(child: _buildPaymentInd('Pending', e['pending_amount'], Colors.orange.shade600)),
                   ]
                 )
              ),
              const SizedBox(height: 32),
              Text('My Baker Wallet', style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              Container(
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
                            Text('₹${d['wallet_balance']?.toStringAsFixed(2) ?? '0.00'}', style: GoogleFonts.quicksand(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
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
                            Text('₹${d['wallet_withdrawn']?.toStringAsFixed(2) ?? '0.00'}', style: GoogleFonts.quicksand(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Pending Approval', style: GoogleFonts.quicksand(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('₹${d['wallet_pending_withdrawal']?.toStringAsFixed(2) ?? '0.00'}', style: GoogleFonts.quicksand(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Business Analysis Reports Card
              Text('Business Analysis Reports', style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              _buildAnalysisCard(d),
              const SizedBox(height: 32),

              Text('Add Daily Expense', style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(20),
                   boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                   ]
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_descriptionController, 'Description', null)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_amountController, 'Amount', '₹')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Dropdown for Category
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          style: GoogleFonts.quicksand(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
                          items: _categories.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Row(
                                children: [
                                  Icon(_categoryIcons[entry.key], color: _categoryColors[entry.key], size: 20),
                                  const SizedBox(width: 12),
                                  Text(entry.value),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategory = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _addExpense,
                        child: Text('Record Expense', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_expenses.isNotEmpty) ...[
                Text('Recent Expenses', style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _expenses.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final exp = _expenses[i];
                    final cat = exp['category'] ?? 'OTHER';
                    final icon = _categoryIcons[cat] ?? Icons.receipt_long;
                    final color = _categoryColors[cat] ?? Colors.grey;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                         ]
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${exp['title']}', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _categories[cat] ?? 'Other',
                                          style: GoogleFonts.quicksand(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${exp['date_incurred']}', style: GoogleFonts.quicksand(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text('-₹${exp['amount']}', style: GoogleFonts.quicksand(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    );
                  }
                ),
                const SizedBox(height: 32),
              ],
              Text('Payout History', style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: e['history'].length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final order = e['history'][i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       boxShadow: [
                         BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                       ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: brandRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.account_balance_wallet, color: brandRed, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order #${order['id']} Payout', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                              const SizedBox(height: 4),
                              Text('${order['payment_status']}', style: GoogleFonts.quicksand(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text('₹${order['baker_payable']}', style: GoogleFonts.quicksand(color: order['payment_status'] == 'PAID_TO_BAKER' ? Colors.green.shade600 : Colors.orange.shade600, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  );
                }
              ),
              const SizedBox(height: 32),
              Text('Registered Bank Details', style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(20),
                   boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                   ]
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_accountHolderNameController, 'Account Holder Name', null),
                    const SizedBox(height: 12),
                    _buildTextField(_bankNameController, 'Bank Name', null),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_accountNumberController, 'Account Number', null)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_ifscCodeController, 'IFSC Code', null)),
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
              if (_withdrawals.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text('Withdrawal Requests', style: GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _withdrawals.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final req = _withdrawals[i];
                    final String status = req['status'] ?? 'PENDING';
                    final double amount = double.tryParse(req['amount']?.toString() ?? '') ?? 0.0;
                    
                    Color statusColor = Colors.orange;
                    if (status == 'APPROVED') statusColor = Colors.green;
                    if (status == 'REJECTED') statusColor = Colors.red;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                         ]
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(
                              status == 'APPROVED' 
                                  ? Icons.check_circle_outline 
                                  : status == 'REJECTED' 
                                      ? Icons.error_outline 
                                      : Icons.hourglass_empty, 
                              color: statusColor, 
                              size: 24
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Withdrawal Request', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: GoogleFonts.quicksand(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      req['requested_at'] != null 
                                          ? req['requested_at'].split('T')[0] 
                                          : '', 
                                      style: GoogleFonts.quicksand(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text('₹${amount.toStringAsFixed(2)}', style: GoogleFonts.quicksand(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    );
                  }
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> d) {
    final double sales = _toDouble(d['total_sales']);
    final double expenses = _toDouble(d['total_expenses']);
    final double profit = _toDouble(d['profit']);
    final double commission = _toDouble(d['delivery_commission']);
    final double profitPercent = sales > 0 ? (profit / sales) : 0.0;
    
    final Color textDark = const Color(0xFF333333);
    const Color brandRed = Color(0xFFED3F47);

    // Weekly/Monthly report selector
    final reportData = (_reportPeriod == 'weekly' ? d['weekly_report'] : d['monthly_report']) as Map<String, dynamic>?;
    final List<dynamic> labels = reportData?['labels'] ?? [];
    final List<dynamic> salesList = reportData?['sales'] ?? [];
    final List<dynamic> expensesList = reportData?['expenses'] ?? [];

    double maxVal = 100.0;
    for (var s in salesList) {
      final double val = _toDouble(s);
      if (val > maxVal) maxVal = val;
    }
    for (var e in expensesList) {
      final double val = _toDouble(e);
      if (val > maxVal) maxVal = val;
    }

    final breakdown = d['expense_breakdown'] as Map<String, dynamic>? ?? {};
    double totalExpBreakdown = 0.0;
    breakdown.forEach((k, v) {
      totalExpBreakdown += _toDouble(v);
    });

    return Container(
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(24),
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
         ]
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net Profit', style: GoogleFonts.quicksand(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₹${profit.toStringAsFixed(2)}', style: GoogleFonts.quicksand(fontSize: 24, color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (profit >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(profitPercent * 100).toStringAsFixed(1)}% Margin',
                  style: GoogleFonts.quicksand(color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Sales', style: GoogleFonts.quicksand(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₹${sales.toStringAsFixed(2)}', style: GoogleFonts.quicksand(fontSize: 18, color: Colors.green.shade600, fontWeight: FontWeight.w800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Expenses', style: GoogleFonts.quicksand(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₹${expenses.toStringAsFixed(2)}', style: GoogleFonts.quicksand(fontSize: 18, color: Colors.red.shade600, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: profitPercent.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(profit >= 0 ? Colors.green : Colors.red),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Commissions (10%):', style: GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              Text('₹${commission.toStringAsFixed(2)}', style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
            ],
          ),
          const SizedBox(height: 28),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Performance Trend', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: textDark), overflow: TextOverflow.ellipsis),
              ),
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _reportPeriod = 'weekly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _reportPeriod == 'weekly' ? brandRed.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Weekly', style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.bold, color: _reportPeriod == 'weekly' ? brandRed : Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _reportPeriod = 'monthly'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _reportPeriod == 'monthly' ? brandRed.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Monthly', style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.bold, color: _reportPeriod == 'monthly' ? brandRed : Colors.grey.shade600)),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          if (labels.isNotEmpty)
            Container(
              height: 160,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(labels.length, (idx) {
                  final double dSales = _toDouble(salesList[idx]);
                  final double dExpenses = _toDouble(expensesList[idx]);
                  
                  final double salesHeight = (dSales / maxVal) * 110;
                  final double expensesHeight = (dExpenses / maxVal) * 110;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                            height: salesHeight.clamp(2.0, 110.0),
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 10,
                            height: expensesHeight.clamp(2.0, 110.0),
                            decoration: BoxDecoration(
                              color: brandRed.withOpacity(0.8),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${labels[idx]}', style: GoogleFonts.quicksand(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    ],
                  );
                }),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green.shade400, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('Sales', style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(width: 24),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: brandRed.withOpacity(0.8), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('Expenses', style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 28),
          Text('Expenses by Category', style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 12),
          ...breakdown.entries.map((entry) {
            final String cat = entry.key;
            final double amount = _toDouble(entry.value);
            final String name = _categories[cat] ?? 'Other';
            final Color color = _categoryColors[cat] ?? Colors.grey;
            final IconData icon = _categoryIcons[cat] ?? Icons.receipt_long;
            
            final double percentage = totalExpBreakdown > 0 ? (amount / totalExpBreakdown) : 0.0;
            if (amount == 0.0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(name, style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                  ),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w900, color: textDark), textAlign: TextAlign.end),
                  ),
                ],
              ),
            );
          }).toList(),
          if (totalExpBreakdown == 0.0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No expenses recorded yet.', style: GoogleFonts.quicksand(color: Colors.grey.shade500, fontSize: 14, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Future<void> _exportPdfReport(Map<String, dynamic> d, Map<String, dynamic> e) async {
    final pdf = pw.Document();
    
    final double sales = _toDouble(d['total_sales']);
    final double expenses = _toDouble(d['total_expenses']);
    final double profit = _toDouble(d['profit']);
    final double commission = _toDouble(d['delivery_commission']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BakeEase - Financial Performance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Date Generated: ${DateTime.now().toLocal().toString().split('.')[0]}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),
                
                pw.Text('Summary Overview', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount (INR)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Sales')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${sales.toStringAsFixed(2)}')),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Platform/Delivery Commissions')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${commission.toStringAsFixed(2)}')),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Expenses')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${expenses.toStringAsFixed(2)}')),
                    ]),
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Net Profit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${profit.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ]),
                  ]
                ),
                
                pw.SizedBox(height: 30),
                pw.Text('Recent Recorded Expenses', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                if (_expenses.isEmpty)
                  pw.Text('No expenses recorded.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ]),
                      ..._expenses.map((exp) {
                        return pw.TableRow(children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${exp['title']}')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${exp['category'] ?? 'OTHER'}')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${exp['date_incurred']}')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${exp['amount']}')),
                        ]);
                      }).toList()
                    ]
                  ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'bakeease_financial_report.pdf',
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, String? prefix) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: prefix != null ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixText: prefix,
          hintText: hint,
          hintStyle: GoogleFonts.quicksand(color: Colors.black45, fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.trending_up, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.quicksand(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.quicksand(color: color, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPaymentInd(String label, dynamic amount, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text('₹$amount', style: GoogleFonts.quicksand(color: color, fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
