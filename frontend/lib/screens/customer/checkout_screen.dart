import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_method_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final dynamic product;
  final String flavor;
  final String size;
  final int quantity;

  const CheckoutScreen({
    Key? key,
    required this.product,
    required this.flavor,
    required this.size,
    required this.quantity,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _customDesignImage;
  final _instructionsController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  bool _isLoading = false;
  late Razorpay _razorpay;
  List<int> _pendingOrderIds = [];

  @override
  void initState() {
    super.initState();
    _fetchAddress();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().post('orders/list/verify_razorpay_payment/', {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'order_ids': _pendingOrderIds,
      });
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!')));
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${res.data}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error verifying payment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
      setState(() => _isLoading = false);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External Wallet: ${response.walletName}')));
    }
  }

  Future<void> _fetchAddress() async {
    try {
      final response = await ApiService().get('users/me/');
      if (response.statusCode == 200) {
        final cp = response.data['customer_profile'];
        if (cp != null && cp['address'] != null) {
          setState(() {
            _deliveryAddressController.text = cp['address'];
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  bool _isValidDeliveryTime(DateTime date, TimeOfDay time) {
    final now = DateTime.now();
    final deliveryDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final minDeliveryTime = now.add(const Duration(hours: 2));
    return !deliveryDateTime.isBefore(minDeliveryTime);
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery date first.')),
      );
      return;
    }
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (!_isValidDeliveryTime(_selectedDate!, picked)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery time must be at least 2 hours from the current time.'),
          ),
        );
        return;
      }
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      if (_selectedTime != null && !_isValidDeliveryTime(picked, _selectedTime!)) {
        setState(() {
          _selectedDate = picked;
          _selectedTime = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected delivery time was reset because it must be at least 2 hours from the current time.'),
          ),
        );
      } else {
        setState(() => _selectedDate = picked);
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _customDesignImage = File(pickedFile.path));
    }
  }

  void _proceedToPayment(double total) async {
    if (_deliveryAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a delivery address.')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a delivery date and time.')));
      return;
    }
    if (!_isValidDeliveryTime(_selectedDate!, _selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery time must be at least 2 hours from the current time.'),
        ),
      );
      return;
    }

    final orderIds = await _placeOrderFromPayment();
    if (orderIds == null || orderIds.isEmpty) return;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          orderIds: orderIds,
          totalAmount: total,
        ),
      ),
    );
  }

  Future<List<int>?> _placeOrderFromPayment() async {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isLoading = true);
      });
    }
    try {
      FormData formData = FormData.fromMap({
         'baker_id': widget.product['baker']['id'], 
         'total_amount': widget.quantity * double.parse(widget.product['base_price'].toString()),
         'items[0]product_id': widget.product['id'],
         'items[0]flavor': widget.flavor,
         'items[0]size': widget.size,
         'items[0]quantity': widget.quantity,
         'items[0]price': widget.product['base_price'],
         'special_instructions': _instructionsController.text,
         'delivery_address': _deliveryAddressController.text.trim(),
         'requested_delivery_date': "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
         'delivery_time': DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute).toIso8601String(),
         if (_customDesignImage != null) 
           'custom_design_image': await MultipartFile.fromFile(_customDesignImage!.path, filename: 'design.jpg'),
      });
      
      final response = await ApiService().post('orders/list/', formData);
      return [response.data['id']];
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: ${e.response?.data}')));
      }
      return null;
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    }
  }

  void _placeOrder() async {
    if (_deliveryAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a delivery address.')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a delivery date and time.')));
      return;
    }
    if (!_isValidDeliveryTime(_selectedDate!, _selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery time must be at least 2 hours from the current time.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create Custom Request (if any image/instruction)
      int? customRequestId;
      if (_customDesignImage != null || _instructionsController.text.isNotEmpty) {
        FormData reqData = FormData.fromMap({
          if (_customDesignImage != null) 'custom_design_image': await MultipartFile.fromFile(_customDesignImage!.path, filename: 'design.jpg'),
          'special_instructions': _instructionsController.text,
          'requested_delivery_date': "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
        });
      }

      final orderData = {
         'baker_id': widget.product['baker']['id'], 
         'total_amount': widget.quantity * double.parse(widget.product['base_price'].toString()),
         'delivery_time': DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute).toIso8601String(),
         'delivery_address': _deliveryAddressController.text.trim(),
         'items': [
           {
             'product_id': widget.product['id'],
             'flavor': widget.flavor,
             'size': widget.size,
             'quantity': widget.quantity,
             'price': widget.product['base_price'],
           }
         ],
      };
      
      await ApiService().post('orders/list/', orderData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order placed successfully!')));
      Navigator.popUntil(context, (route) => route.isFirst); // Back to home

    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to place order: ${e.response?.data}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double cakeAmount = widget.quantity * double.parse(widget.product['base_price'].toString());
    double deliveryCharge = 50.0;
    double total = cakeAmount + deliveryCharge;

    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ListTile(
              title: Text('${widget.product['name']} (x${widget.quantity})'),
              subtitle: Text('Flavor: ${widget.flavor}, Size: ${widget.size}'),
              trailing: Text('₹$cakeAmount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              title: Text('Delivery Charge'),
              trailing: Text('₹$deliveryCharge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Divider(),
            ListTile(
              title: Text('Total Payable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              trailing: Text('₹$total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Divider(),
            SizedBox(height: 20),
            Text('Customization & Delivery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextField(
              controller: _deliveryAddressController,
              decoration: InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text(_selectedDate == null ? 'Select Delivery Date' : '${_selectedDate!.toLocal()}'.split(' ')[0]),
              onTap: _pickDate,
            ),
            ListTile(
              leading: Icon(Icons.access_time),
              title: Text(_selectedTime == null ? 'Select Delivery Time' : _selectedTime!.format(context)),
              onTap: _pickTime,
            ),
            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(labelText: 'Special Instructions (e.g., Happy Birthday Text)'),
              maxLines: 3,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  label: Text('Upload Reference Image'),
                  icon: Icon(Icons.image)
                ),
                SizedBox(width: 10),
                _customDesignImage != null ? Icon(Icons.check, color: Colors.green) : Container(),
              ],
            ),
            SizedBox(height: 40),
            _isLoading 
              ? Center(child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Processing... Please wait.')
                  ],
                ))
              : ElevatedButton(
                  onPressed: () => _proceedToPayment(total),
                  child: Text('Proceed to Payment (₹$total)'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.brown, foregroundColor: Colors.white),
                )
          ],
        ),
      ),
    );
  }
}
