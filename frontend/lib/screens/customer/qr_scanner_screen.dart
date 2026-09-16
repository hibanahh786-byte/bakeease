import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';

class QrScannerScreen extends StatefulWidget {
  final List<int> orderIds;
  final double totalAmount;

  const QrScannerScreen({
    Key? key,
    required this.orderIds,
    required this.totalAmount,
  }) : super(key: key);

  @override
  _QrScannerScreenState createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(_animationController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onQrCodeScanned(String rawValue) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _controller.stop(); // Stop scanning

    // Parse UPI parameters if it's a UPI URL
    // e.g. upi://pay?pa=merchant@upi&pn=MerchantName&am=100.00
    String name = "BakeEase Baker";
    String upiId = "bakeease@upi";
    double amount = widget.totalAmount;

    if (rawValue.startsWith("upi://pay")) {
      try {
        Uri uri = Uri.parse(rawValue);
        upiId = uri.queryParameters['pa'] ?? upiId;
        name = uri.queryParameters['pn'] ?? name;
        if (uri.queryParameters['am'] != null) {
          amount = double.tryParse(uri.queryParameters['am']!) ?? amount;
        }
      } catch (e) {
        // ignore parsing error, use defaults
      }
    }

    _showPaymentDetailsSheet(name, upiId, amount);
  }

  void _showPaymentDetailsSheet(String name, String upiId, double amount) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'UPI Payee Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.brown[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.brown[800],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(upiId),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:', style: TextStyle(fontSize: 16)),
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _confirmPayment(upiId, amount),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Confirm & Authorize Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isProcessing = false;
                  });
                  _controller.start(); // Resume camera scanning
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.brown[800]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.brown[800], fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmPayment(String upiId, double amount) async {
    Navigator.pop(context); // Close bottom sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.brown),
      ),
    );

    try {
      String txId = "upi_tx_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
      final res = await ApiService().post('orders/list/verify_upi_payment/', {
        'transaction_id': txId,
        'order_ids': widget.orderIds,
        'payment_method': 'QR_SCAN',
      });

      Navigator.pop(context); // Dismiss loading spinner

      if (res.statusCode == 200) {
        _showSuccessAnimation();
      } else {
        _showErrorSnackBar('Verification failed: ${res.data}');
        _resumeScanning();
      }
    } catch (e) {
      Navigator.pop(context); // Dismiss loading spinner
      _showErrorSnackBar('Payment error: $e');
      _resumeScanning();
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your order has been confirmed.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close success dialog
                    Navigator.popUntil(context, (route) => route.isFirst); // Go to Home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text('Back to Home', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
    });
    _controller.start();
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[800]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan QR Code to Pay', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _flashOn = !_flashOn;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _onQrCodeScanned(barcodes.first.rawValue!);
              }
            },
          ),

          // Scanner Overlay Window
          Center(
            child: Stack(
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                // Pulse scanning laser line
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _pulseAnimation.value * 280,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Instruction and Simulator overlay
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Align the QR code within the frame to pay',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                // Simulator button
                ElevatedButton.icon(
                  onPressed: () {
                    // Simulate scanning a UPI QR code
                    _onQrCodeScanned(
                      'upi://pay?pa=bakeease@upi&pn=BakeEase%20Bakery&am=${widget.totalAmount}&cu=INR&tn=BakeEase%20Order'
                    );
                  },
                  icon: const Icon(Icons.videogame_asset, color: Colors.white),
                  label: const Text('Simulate QR Code Scan', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
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
}
