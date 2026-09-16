import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'chat_page.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      final response = await _apiService.get('chats/conversations/');
      if (mounted) {
        setState(() {
          _conversations = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load conversations.')),
        );
      }
    }
  }

  String _formatDateTime(String? timestampStr) {
    if (timestampStr == null) return '';
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final now = DateTime.now();

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $ampm';
      } else {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
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
        title: Text(
          'Chats',
          style: GoogleFonts.playfairDisplay(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchConversations,
              color: brandRed,
              child: _conversations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined, color: Colors.grey.shade400, size: 80),
                              const SizedBox(height: 16),
                              Text(
                                'No conversations yet',
                                style: GoogleFonts.playfairDisplay(
                                  color: textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your active messages will appear here.',
                                style: GoogleFonts.quicksand(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _conversations.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5EFE9)),
                      itemBuilder: (context, index) {
                        final convo = _conversations[index];
                        final otherUser = convo['other_user'];
                        final lastMessage = convo['last_message'];
                        final unreadCount = convo['unread_count'] ?? 0;

                        final String name = otherUser['username'] ?? 'User';
                        final String role = otherUser['role'] ?? 'CUSTOMER';
                        final String lastMsgText = lastMessage['message'] ?? '';
                        final String lastMsgTime = _formatDateTime(lastMessage['created_at']);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: brandRed.withOpacity(0.08),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.quicksand(
                                color: brandRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.quicksand(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: brandRed.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: brandRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lastMsgText,
                                    style: GoogleFonts.quicksand(
                                      fontSize: 13,
                                      color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lastMsgTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: brandRed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            // Navigate to individual chat screen
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  recipientId: otherUser['id'],
                                  recipientName: name,
                                  recipientRole: role,
                                ),
                              ),
                            );
                            // Refresh list when user returns (in case unread status/messages changed)
                            _fetchConversations();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
