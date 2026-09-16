import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:upi_india/upi_india.dart';
import '../../services/api_service.dart';
import 'qr_scanner_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final List<int> orderIds;
  final double totalAmount;

  const PaymentMethodScreen({
    Key? key,
    required this.orderIds,
    required this.totalAmount,
  }) : super(key: key);

  @override
  _PaymentMethodScreenState createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late Razorpay _razorpay;
  final UpiIndia _upiIndia = UpiIndia();
  List<UpiApp> _upiApps = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);
    _loadUpiApps();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _loadUpiApps() async {
    try {
      final apps = await _upiIndia.getAllUpiApps(mandatoryTransactionId: false);
      setState(() {
        _upiApps = apps;
      });
    } catch (e) {
      setState(() {
        _upiApps = [];
      });
    }
  }

  // --- Razorpay Handlers ---
  void _startRazorpayPayment() async {
    setState(() => _isLoading = true);
    try {
      final rzpRes = await ApiService().post('orders/list/create_razorpay_order/', {
        'order_ids': widget.orderIds
      });

      if (rzpRes.statusCode == 200) {
        var data = rzpRes.data;
        if (data['key'] == 'rzp_test_YOUR_KEY_ID') {
          // Bypass Razorpay for local testing
          final verifyRes = await ApiService().post('orders/list/verify_razorpay_payment/', {
            'razorpay_order_id': data['razorpay_order_id'],
            'razorpay_payment_id': 'pay_dummy_rzp',
            'razorpay_signature': 'sig_dummy_rzp',
            'order_ids': widget.orderIds,
          });
          if (verifyRes.statusCode == 200 && mounted) {
            _showSuccessDialog("Razorpay Test Mode");
          } else if (mounted) {
            _showErrorSnackBar('Test Verification Failed: ${verifyRes.data}');
          }
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        var options = {
          'key': data['key'],
          'amount': data['amount'],
          'name': 'BakeEase Checkout',
          'order_id': data['razorpay_order_id'],
          'description': 'Order Payment',
        };
        _razorpay.open(options);
      } else {
        _showErrorSnackBar('Failed to initialize Razorpay API');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().post('orders/list/verify_razorpay_payment/', {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'order_ids': widget.orderIds,
      });
      if (res.statusCode == 200) {
        _showSuccessDialog("Razorpay");
      } else {
        _showErrorSnackBar('Verification Failed: ${res.data}');
      }
    } catch (e) {
      _showErrorSnackBar('Verification error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    _showErrorSnackBar('Payment Failed: ${response.message}');
    setState(() => _isLoading = false);
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    _showErrorSnackBar('External Wallet selected: ${response.walletName}');
  }

  // --- UPI Intent Handlers ---
  void _startUpiPayment(UpiApp app) async {
    setState(() => _isLoading = true);
    String txId = "upi_tx_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
    try {
      final response = await _upiIndia.startTransaction(
        app: app,
        receiverUpiId: "bakeease@upi",
        receiverName: "BakeEase Bakery",
        transactionRefId: txId,
        transactionNote: "BakeEase Order Payment",
        amount: widget.totalAmount,
      );

      if (response.status == UpiPaymentStatus.SUCCESS) {
        _verifyUpiPaymentOnBackend(txId, 'UPI_INTENT');
      } else {
        _showErrorSnackBar('UPI status: ${response.status?.toString() ?? "Failed"}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Fallback/Cancelled
      _showErrorSnackBar('UPI app launch failed. Opening simulation mode...');
      setState(() => _isLoading = false);
      _showSimulationDialog(app.name);
    }
  }

  void _verifyUpiPaymentOnBackend(String transactionId, String method) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().post('orders/list/verify_upi_payment/', {
        'transaction_id': transactionId,
        'order_ids': widget.orderIds,
        'payment_method': method,
      });

      if (res.statusCode == 200) {
        _showSuccessDialog(method);
      } else {
        _showErrorSnackBar('UPI verification failed: ${res.data}');
      }
    } catch (e) {
      _showErrorSnackBar('UPI Verification error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Simulation Dialog for Easy Testing ---
  void _showSimulationDialog(String providerName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Simulate $providerName Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This dialog lets you simulate a successful UPI transaction of ₹${widget.totalAmount.toStringAsFixed(2)} for testing.',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payee:'),
                  Text('BakeEase Bakery', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown[800])),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount:'),
                  Text('₹${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close simulation dialog
                String mockTx = "mock_upi_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
                _verifyUpiPaymentOnBackend(mockTx, 'GOOGLE_PAY_SIMULATION');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('Simulate Success', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Success dialog ---
  void _showSuccessDialog(String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline, color: Colors.green[700], size: 70),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payment Completed!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your order has been verified and confirmed. Paid via $method.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.popUntil(context, (route) => route.isFirst); // Back to Home
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[800]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if Google Pay is in the detected UPI apps
    UpiApp? gpayApp;
    for (var app in _upiApps) {
      if (app.name.toLowerCase().contains("google pay") || app.name.toLowerCase().contains("gpay")) {
        gpayApp = app;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Select Payment Method', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.brown),
                  SizedBox(height: 16),
                  Text('Processing transaction, please wait...', style: TextStyle(color: Colors.brown, fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Order Summary Card (Glassmorphism-styled)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.brown[800]!, Colors.brown[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AMOUNT TO PAY',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${widget.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${widget.orderIds.length} Order(s)',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        Text(
                          'Order ID: #${widget.orderIds.join(", #")}',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'PAYMENT OPTIONS',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Native Google Pay (UPI)
                  _buildPaymentOptionTile(
                    title: 'Google Pay (UPI)',
                    subtitle: gpayApp != null ? 'Pay directly via Google Pay' : 'Pay using UPI Apps on device',
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.blue[700]!,
                    onTap: () {
                      if (gpayApp != null) {
                        _startUpiPayment(gpayApp);
                      } else if (_upiApps.isNotEmpty) {
                        _showUpiAppSelector();
                      } else {
                        _showErrorSnackBar("No UPI apps found. Launching simulated mode.");
                        _showSimulationDialog("Google Pay");
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Option 2: Google Pay Simulated (For testing)
                  _buildPaymentOptionTile(
                    title: 'Google Pay (Simulated)',
                    subtitle: 'Quick simulated test payment (immediate completion)',
                    icon: Icons.developer_mode,
                    iconColor: Colors.green[700]!,
                    onTap: () => _showSimulationDialog("Google Pay"),
                  ),
                  const SizedBox(height: 12),

                  // Option 3: Razorpay (Cards, Netbanking, etc)
                  _buildPaymentOptionTile(
                    title: 'Razorpay',
                    subtitle: 'Cards, Netbanking, UPI, and Wallets',
                    icon: Icons.payment,
                    iconColor: Colors.indigo[800]!,
                    onTap: _startRazorpayPayment,
                  ),
                  const SizedBox(height: 12),

                  // Option 4: Scan QR Code
                  _buildPaymentOptionTile(
                    title: 'Scan QR Code to Pay',
                    subtitle: 'Scan merchant/bakery UPI code to authorize',
                    icon: Icons.qr_code_scanner,
                    iconColor: Colors.orange[800]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QrScannerScreen(
                            orderIds: widget.orderIds,
                            totalAmount: widget.totalAmount,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.brown, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Show list of UPI apps if GPay not directly matched ---
  void _showUpiAppSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose UPI Application',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _upiApps.length,
                  itemBuilder: (context, index) {
                    final app = _upiApps[index];
                    return ListTile(
                      leading: Image.memory(app.icon, width: 40, height: 40),
                      title: Text(app.name),
                      onTap: () {
                        Navigator.pop(context);
                        _startUpiPayment(app);
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
