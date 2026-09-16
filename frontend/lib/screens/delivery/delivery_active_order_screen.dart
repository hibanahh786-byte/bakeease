import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class DeliveryActiveOrderScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DeliveryActiveOrderScreen({Key? key, required this.order}) : super(key: key);

  @override
  _DeliveryActiveOrderScreenState createState() => _DeliveryActiveOrderScreenState();
}

class _DeliveryActiveOrderScreenState extends State<DeliveryActiveOrderScreen> {
  final ApiService _apiService = ApiService();
  late Map<String, dynamic> _currentOrder;
  bool _isLoading = false;
  Timer? _locationTimer;

  // Dummy location values for MVP polling
  double _currentLat = 12.9716;
  double _currentLng = 77.5946;

  // Interactive Touch Signature Canvas points
  final List<Offset?> _signaturePoints = [];

  // Chat Simulation State
  bool _showChatDrawer = false;
  String _chatChannel = 'CUSTOMER'; // 'CUSTOMER' or 'BAKER'
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  late List<MockMessage> _customerMessages;
  late List<MockMessage> _bakerMessages;

  // Handover Verification State
  final TextEditingController _pinController = TextEditingController();
  bool _photoCaptured = false;
  bool _isShutterFlashing = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;

    // Prepopulate chat messages with simulated history
    _customerMessages = [
      MockMessage(
        sender: _currentOrder['customer']['user']['username'],
        text: "Hi! Is my cake on the way?",
        time: DateTime.now().subtract(const Duration(minutes: 15)),
        isMe: false,
      ),
    ];

    _bakerMessages = [
      MockMessage(
        sender: _currentOrder['baker']['user']['username'],
        text: "The cake is freshly baked and packaged in the cooling box. Ready for pick up!",
        time: DateTime.now().subtract(const Duration(minutes: 20)),
        isMe: false,
      ),
    ];

    if (_currentOrder['status'] == 'OUT_FOR_DELIVERY') {
      _startLocationPolling();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _startLocationPolling() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      _currentLat += 0.0001;
      _currentLng += 0.0001;
      await _apiService.post('orders/list/${_currentOrder['id']}/location/', {
        'latitude': _currentLat,
        'longitude': _currentLng,
      });
      print("Location pushed: $_currentLat, $_currentLng");
    } catch (e) {
      print("Failed to push location: $e");
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.post('orders/list/${_currentOrder['id']}/status/', {
        'status': newStatus,
      });
      setState(() {
        _currentOrder['status'] = newStatus;
      });
      if (newStatus == 'OUT_FOR_DELIVERY') {
        _startLocationPolling();
      } else if (newStatus == 'DELIVERED') {
        _locationTimer?.cancel();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to $newStatus',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update status',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFED3F47),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Call utility
  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available.')),
      );
      return;
    }
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Simulation for emulator environment
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dialing contact $phoneNumber... (Simulated)'),
          backgroundColor: const Color(0xFF4A3022),
        ),
      );
    }
  }

  // Chat message send & simulated auto-response
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final userMsg = MockMessage(
      sender: "Me (Delivery)",
      text: text,
      time: DateTime.now(),
      isMe: true,
    );

    setState(() {
      if (_chatChannel == 'CUSTOMER') {
        _customerMessages.add(userMsg);
      } else {
        _bakerMessages.add(userMsg);
      }
    });
    _chatController.clear();
    _scrollToBottom();

    // Trigger auto simulated reply after 1.5 seconds
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      String replyText = "";
      String senderName = "";

      if (_chatChannel == 'CUSTOMER') {
        senderName = _currentOrder['customer']['user']['username'];
        final lowercaseText = text.toLowerCase();
        if (lowercaseText.contains('arrive') || lowercaseText.contains('way')) {
          replyText = "Awesome! Thank you so much, I am waiting downstairs! 🎂";
        } else if (lowercaseText.contains('delay') || lowercaseText.contains('traffic')) {
          replyText = "No worries at all! Please drive safely. Let me know when you reach.";
        } else {
          replyText = "Thank you for the update! See you soon.";
        }
      } else {
        senderName = _currentOrder['baker']['user']['username'];
        final lowercaseText = text.toLowerCase();
        if (lowercaseText.contains('arrive') || lowercaseText.contains('reached')) {
          replyText = "Excellent, I have kept the box ready at the dispatch counter!";
        } else if (lowercaseText.contains('pick') || lowercaseText.contains('take')) {
          replyText = "Perfect, please carry it carefully. It's a fresh cream design!";
        } else {
          replyText = "Great! Have a safe delivery run!";
        }
      }

      setState(() {
        final replyMsg = MockMessage(
          sender: senderName,
          text: replyText,
          time: DateTime.now(),
          isMe: false,
        );
        if (_chatChannel == 'CUSTOMER') {
          _customerMessages.add(replyMsg);
        } else {
          _bakerMessages.add(replyMsg);
        }
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }





  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.quicksand(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF4A3022),
        letterSpacing: 0.8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandCream = Color(0xFFFFF8F5);
    const Color brandRed = Color(0xFFED3F47);

    final status = _currentOrder['status'];
    final customer = _currentOrder['customer'];
    final baker = _currentOrder['baker'];
    final items = _currentOrder['items'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: brandCream,
      appBar: AppBar(
        title: Text(
          'Active Task Details',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF4A3022),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF4A3022)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandRed))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Tracker Banner
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DELIVERY TIMELINE PROGRESS',
                                style: GoogleFonts.quicksand(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildStatusStepper(status),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Order Items Breakdown Card
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER BASKET DETAILS',
                                style: GoogleFonts.quicksand(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                itemBuilder: (context, idx) {
                                  final item = items[idx];
                                  final name = item['product']['name'];
                                  final qty = item['quantity'];
                                  final flavor = item['flavor'] ?? '';
                                  final size = item['size'] ?? '';
                                  final price = item['price'];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.cake, color: Colors.orange, size: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$qty x $name',
                                                style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              if (flavor.isNotEmpty || size.isNotEmpty)
                                                Text(
                                                  '${flavor.isNotEmpty ? "Flavor: $flavor" : ""} ${size.isNotEmpty ? "• Size: $size" : ""}',
                                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹$price',
                                          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pickup Card (Baker)
                      _buildContactLocationCard(
                        title: 'PICKUP HUB (BAKER DETAILS)',
                        name: baker['user']['username'].toString().toUpperCase(),
                        phone: baker['contact_number'] ?? 'N/A',
                        locationLabel: 'Bakery Details',
                        locationDesc: 'Verified BakeEase Licensed Kitchen',
                        onCall: () => _makePhoneCall(baker['contact_number']),
                        onChat: () {
                          setState(() {
                            _chatChannel = 'BAKER';
                            _showChatDrawer = true;
                          });
                          _scrollToBottom();
                        },
                      ),
                      const SizedBox(height: 14),

                      // Dropoff Card (Customer)
                      _buildContactLocationCard(
                        title: 'DROPOFF POINT (CUSTOMER DETAILS)',
                        name: customer['user']['username'].toString().toUpperCase(),
                        phone: customer['contact_number'] ?? 'N/A',
                        locationLabel: 'Delivery Address',
                        locationDesc: customer['address'] ?? 'No delivery address recorded',
                        onCall: () => _makePhoneCall(customer['contact_number']),
                        onChat: () {
                          setState(() {
                            _chatChannel = 'CUSTOMER';
                            _showChatDrawer = true;
                          });
                          _scrollToBottom();
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom Action buttons
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (status == 'CONFIRMED' || status == 'ORDER_IN_PROGRESS')
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () => _updateStatus('OUT_FOR_DELIVERY'),
                          icon: const Icon(Icons.directions_run_outlined),
                          label: Text(
                            'Pick Up Cake & Start Journey',
                            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (status == 'OUT_FOR_DELIVERY')
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () async {
                            await _updateStatus('DELIVERED');
                            Navigator.pop(context); // Go back to dashboard
                          },
                          icon: const Icon(Icons.assignment_turned_in),
                          label: Text(
                            'Arrive & Complete Delivery Handoff',
                            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),

                // Simulated Interactive Chat Drawer overlay
                if (_showChatDrawer) _buildInteractiveChatDrawer(),
              ],
            ),
    );
  }

  Widget _buildStatusStepper(String status) {
    bool isStep1 = true; // Assigned
    bool isStep2 = status == 'OUT_FOR_DELIVERY' || status == 'DELIVERED'; // Out for delivery
    bool isStep3 = status == 'DELIVERED'; // Arrived

    return Column(
      children: [
        _buildStepperItem(isStep1, 'Assigned & Baker Confirmed', 'The cake recipe is locked and prepared for pickup.', true),
        _buildStepperLine(isStep2),
        _buildStepperItem(isStep2, 'Out for Delivery / Transit', 'Delivery agent is carrying the box. Location sharing active.', isStep2),
        _buildStepperLine(isStep3),
        _buildStepperItem(isStep3, 'Completed Handoff', 'Cake safely verified, signed, and delivered.', false),
      ],
    );
  }

  Widget _buildStepperItem(bool active, String title, String subtitle, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: active ? Colors.teal : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.check : Icons.radio_button_unchecked,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: active ? const Color(0xFF4A3022) : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepperLine(bool completed) {
    return Container(
      margin: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
      width: 2,
      height: 24,
      color: completed ? Colors.teal : Colors.grey.shade300,
    );
  }

  Widget _buildContactLocationCard({
    required String title,
    required String name,
    required String phone,
    required String locationLabel,
    required String locationDesc,
    required VoidCallback onCall,
    required VoidCallback onChat,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.quicksand(
                color: Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4A3022).withOpacity(0.05),
                  child: Text(
                    name.isNotEmpty ? name[0] : 'U',
                    style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Phone: $phone',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.teal),
                  onPressed: onCall,
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFED3F47)),
                  onPressed: onChat,
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF3EAE0)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationLabel,
                        style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        locationDesc,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
  }

  // Interactive Live Chat Drawer Layout
  Widget _buildInteractiveChatDrawer() {
    final activeList = _chatChannel == 'CUSTOMER' ? _customerMessages : _bakerMessages;
    final channelName = _chatChannel == 'CUSTOMER' ? 'Customer' : 'Baker';

    return Container(
      color: Colors.black.withOpacity(0.4),
      width: double.infinity,
      height: double.infinity,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chat Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF8F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, color: Color(0xFF4A3022)),
                      onPressed: () => setState(() => _showChatDrawer = false),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFFED3F47).withOpacity(0.1),
                      child: const Icon(Icons.person, color: Color(0xFFED3F47), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat with $channelName',
                            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Text('Live Connection', style: TextStyle(fontSize: 10, color: Colors.teal)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Chat Messages list
              Expanded(
                child: ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: activeList.length,
                  itemBuilder: (context, idx) {
                    final msg = activeList[idx];
                    return Align(
                      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: msg.isMe ? const Color(0xFF4A3022) : const Color(0xFFFFF1EF),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: msg.isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: msg.isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.sender,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: msg.isMe ? Colors.white60 : const Color(0xFFED3F47),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.text,
                              style: GoogleFonts.quicksand(
                                color: msg.isMe ? Colors.white : const Color(0xFF4A3022),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Presets templates bar
              Container(
                height: 44,
                color: Colors.grey.shade50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildTemplateChip("Arriving in 5 mins!"),
                    _buildTemplateChip("Picked up cake successfully!"),
                    _buildTemplateChip("Waiting outside your address."),
                    _buildTemplateChip("Unable to locate delivery point."),
                  ],
                ),
              ),

              // Input field bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: 'Type your update...',
                          hintStyle: GoogleFonts.quicksand(fontSize: 13),
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: const Color(0xFFED3F47),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 16),
                        onPressed: () => _sendMessage(_chatController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6D6C6)),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.quicksand(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4A3022)),
          ),
        ),
      ),
    );
  }
}

class MockMessage {
  final String sender;
  final String text;
  final DateTime time;
  final bool isMe;

  MockMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.isMe,
  });
}

// Touch Interactive Finger Drawing Signature pad Painter
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A3022) // Chocolate Brown signature
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => oldDelegate.points != points;
}
