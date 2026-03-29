import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../models/sos_request.dart';

/// Obrazovka se zprávami — seznam SOS požadavků s posledními zprávami
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final partner = ref.read(partnerProfileProvider).valueOrNull;
      if (partner == null) {
        setState(() => _loading = false);
        return;
      }

      // Get all requests for this partner (active + completed)
      final active = await SupabaseService.instance.getMyActiveRequests(partner.id);
      final completed = await SupabaseService.instance.getCompletedRequests(partner.id);
      final allRequests = [...active, ...completed];

      final conversations = <Map<String, dynamic>>[];

      for (final request in allRequests) {
        try {
          final messages = await SupabaseService.instance.getMessages(request.id);
          if (messages.isNotEmpty) {
            final lastMsg = messages.last;
            conversations.add({
              'request': request,
              'lastMessage': lastMsg,
              'messageCount': messages.length,
            });
          }
        } catch (_) {}
      }

      // Sort by last message time (newest first)
      conversations.sort((a, b) {
        final aTime = DateTime.tryParse(a['lastMessage']?['created_at'] ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['lastMessage']?['created_at'] ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.tryParse(isoTime);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Právě teď';
    if (diff.inMinutes < 60) return 'Před ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Před ${diff.inHours} hod';
    if (diff.inDays < 7) return 'Před ${diff.inDays} dny';
    return '${local.day}. ${local.month}. ${local.year}';
  }

  String _statusLabel(SosStatus status) {
    return status.label;
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
        return const Color(0xFFEF4444);
    }
  }

  IconData _categoryIcon(String kategorie) {
    switch (kategorie) {
      case 'zamecnik':
        return Icons.key_rounded;
      case 'odtahovka':
        return Icons.local_shipping_rounded;
      case 'servis':
        return Icons.build_rounded;
      case 'instalater':
        return Icons.water_drop_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zprávy'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Žádné zprávy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Zprávy se zobrazí po přijetí SOS požadavku',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white30 : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final request = conv['request'] as SosRequest;
                      final lastMsg = conv['lastMessage'] as Map<String, dynamic>;
                      final msgCount = conv['messageCount'] as int;
                      final isPartnerMsg = lastMsg['sender_type'] == 'partner';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/request/${request.id}'),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF8B5CF6)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _categoryIcon(request.kategorie),
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Text
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'SOS #${request.id.substring(0, 8)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF111827),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatTime(
                                                  lastMsg['created_at']),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark
                                                    ? Colors.white30
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                isPartnerMsg
                                                    ? 'Vy: ${lastMsg['text']}'
                                                    : lastMsg['text'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _statusColor(
                                                        request.status)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _statusLabel(request.status),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: _statusColor(
                                                      request.status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (msgCount > 1)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              '$msgCount zpráv',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark
                                                    ? Colors.white24
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
