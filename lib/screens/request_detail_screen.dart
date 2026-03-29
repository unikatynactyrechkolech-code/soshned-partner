import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/status_badge.dart';

/// Detail SOS požadavku — zobrazí info o zákazníkovi,
/// akce (přijmout, na cestě, dokončit), kontakt a **chat v reálném čase**.
class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  SosRequest? _request;
  bool _loading = true;
  bool _actionLoading = false;

  // Chat state
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _chatChannel;
  bool _chatLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequest();
    _loadMessages();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    if (_chatChannel != null) {
      SupabaseService.instance.unsubscribeChannel(_chatChannel!);
    }
    super.dispose();
  }

  Future<void> _loadRequest() async {
    // V reálu bychom měli single fetch by ID
    setState(() => _loading = false);
  }

  Future<void> _loadMessages() async {
    final msgs = await SupabaseService.instance.getMessages(widget.requestId);
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
        _chatLoading = false;
      });
      _scrollToBottom();
    }

    // Subscribe to new messages
    _chatChannel = SupabaseService.instance.subscribeMessages(
      sosRequestId: widget.requestId,
      onMessage: (msg) {
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    // Get current user id (partner)
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'partner-anon';

    await SupabaseService.instance.sendMessage(
      sosRequestId: widget.requestId,
      senderType: 'partner',
      senderId: userId,
      text: text,
    );
  }

  Future<void> _updateStatus(SosStatus newStatus) async {
    if (_request == null) return;
    setState(() => _actionLoading = true);

    try {
      SosRequest updated;
      switch (newStatus) {
        case SosStatus.inProgress:
          updated = await SupabaseService.instance.startRequest(_request!.id);
          break;
        case SosStatus.completed:
          updated =
              await SupabaseService.instance.completeRequest(_request!.id);
          break;
        default:
          return;
      }

      setState(() {
        _request = updated;
        _actionLoading = false;
      });

      if (mounted && newStatus == SosStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Výjezd dokončen!'),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _actionLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Detail požadavku'),
        actions: [
          // Online indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info section (collapsed)
          _buildInfoHeader(theme, isDark),

          // Chat messages
          Expanded(
            child: _chatLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyChat(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildMessageBubble(_messages[index], isDark),
                      ),
          ),

          // Chat input
          _buildChatInput(isDark),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emergency_rounded,
                    size: 20, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS Požadavek',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${widget.requestId.substring(0, 8)}…',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionChip(
                    icon: Icons.phone_rounded,
                    color: const Color(0xFF22C55E),
                    isDark: isDark,
                    onTap: () async {
                      final uri = Uri(scheme: 'tel', path: '+420777111222');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                  const SizedBox(width: 6),
                  _ActionChip(
                    icon: Icons.navigation_rounded,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'Zatím žádné zprávy',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Napište zákazníkovi první zprávu',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white12 : Colors.grey[350],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isDark) {
    final isMe = msg['sender_type'] == 'partner';
    final text = msg['text'] ?? '';
    final createdAt = msg['created_at'] != null
        ? DateTime.tryParse(msg['created_at'].toString())
        : null;
    final timeStr = createdAt != null
        ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey[200],
              child: Icon(Icons.person_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.grey[500]),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF3B82F6)
                    : isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.grey[200]!,
                      ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? Colors.white
                          : isDark
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey[800],
                      height: 1.3,
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withOpacity(0.5)
                            : isDark
                                ? Colors.white24
                                : Colors.grey[400],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF3B82F6).withOpacity(0.15),
              child: const Icon(Icons.handyman_rounded,
                  size: 14, color: Color(0xFF3B82F6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatInput(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D18) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey[200]!,
                ),
              ),
              child: TextField(
                controller: _chatController,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
                decoration: InputDecoration(
                  hintText: 'Napište zprávu…',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey[400],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(SosStatus status) {
    switch (status) {
      case SosStatus.pending:
        return const Color(0xFFF59E0B);
      case SosStatus.accepted:
        return const Color(0xFF3B82F6);
      case SosStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case SosStatus.completed:
        return const Color(0xFF22C55E);
      case SosStatus.cancelled:
        return Colors.grey;
    }
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Center(
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
