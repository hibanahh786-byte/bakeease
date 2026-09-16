import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class ChatPage extends StatefulWidget {
  final int recipientId;
  final String recipientName;
  final String recipientRole;

  const ChatPage({
    Key? key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages(initial: true);
    
    // Set up a background timer to poll for new messages every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages(initial: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final response = await _apiService.get('chats/messages/?user_id=${widget.recipientId}');
      if (mounted) {
        setState(() {
          _messages = response.data;
          if (initial) {
            _isLoading = false;
            // Scroll to bottom after the UI has updated
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
          }
        });
      }
    } catch (e) {
      if (initial && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final response = await _apiService.post('chats/send/', {
        'receiver': widget.recipientId,
        'message': text,
      });

      if (mounted) {
        setState(() {
          _messages.add(response.data);
        });
        // Scroll to the bottom to show the newly sent message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  String _formatTime(String? timestampStr) {
    if (timestampStr == null) return '';
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color brandRed = const Color(0xFFED3F47);
    final Color textDark = const Color(0xFF4A3022);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), // Soft premium cream background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: brandRed.withOpacity(0.1),
              child: Text(
                widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
                style: GoogleFonts.quicksand(color: brandRed, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: GoogleFonts.playfairDisplay(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: brandRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.recipientRole,
                      style: GoogleFonts.quicksand(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: brandRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, color: Colors.grey.shade400, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Say hello to ${widget.recipientName}!',
                                style: GoogleFonts.quicksand(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final bool isReceived = msg['sender'] == widget.recipientId;

                            return Align(
                              alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isReceived ? Colors.white : brandRed,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: isReceived ? const Radius.circular(0) : const Radius.circular(16),
                                    bottomRight: isReceived ? const Radius.circular(16) : const Radius.circular(0),
                                  ),
                                  border: isReceived ? Border.all(color: const Color(0xFFEFE8E0)) : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      msg['message'] ?? '',
                                      style: GoogleFonts.quicksand(
                                        color: isReceived ? Colors.black87 : Colors.white,
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(msg['created_at']),
                                      style: TextStyle(
                                        color: isReceived ? Colors.grey.shade400 : Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFEFE8E0)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _messageController,
                              style: GoogleFonts.quicksand(fontSize: 14),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'Type your message...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: brandRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: brandRed.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
