import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/status_badge.dart';

/// Detail SOS požadavku — zobrazí mapu, info o zákazníkovi,
/// akce (přijmout, na cestě, dokončit), kontakt.
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

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    // V reálu bychom měli single fetch by ID, ale pro teď načteme z pending/active
    // Pro demo: mock request
    setState(() => _loading = false);
  }

  Future<void> _updateStatus(SosStatus newStatus) async {
    if (_request == null) return;
    setState(() => _actionLoading = true);

    try {
      SosRequest updated;
      switch (newStatus) {
        case SosStatus.inProgress:
          updated =
              await SupabaseService.instance.startRequest(_request!.id);
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _request == null
              ? _buildPlaceholder(theme, isDark)
              : _buildDetail(theme, isDark),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Detail požadavku',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${widget.requestId}\n\n'
              'Tato obrazovka zobrazí kompletní detail\n'
              'SOS požadavku včetně mapy, kontaktu\n'
              'na zákazníka a akčních tlačítek.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.grey[500],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Placeholder action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigovat k zákazníkovi'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: '+420777111222');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Zavolat zákazníkovi'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Dokončit výjezd'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(ThemeData theme, bool isDark) {
    final r = _request!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Map placeholder
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_rounded,
                    size: 40,
                    color: isDark ? Colors.white24 : Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  '📍 ${r.lat.toStringAsFixed(4)}, ${r.lng.toStringAsFixed(4)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white38 : Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    r.kategorieLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(
                    label: r.status.label,
                    color: _statusColor(r.status),
                    isActive: r.status.isActive,
                  ),
                ],
              ),
              if (r.adresa != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      r.adresa!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
              if (r.popis != null) ...[
                const SizedBox(height: 12),
                Text(
                  r.popis!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                r.timeAgo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Actions
        if (r.status == SosStatus.accepted)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  _actionLoading ? null : () => _updateStatus(SosStatus.inProgress),
              icon: _actionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Vyrazit na cestu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
            ),
          ),
        if (r.status == SosStatus.inProgress)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  _actionLoading ? null : () => _updateStatus(SosStatus.completed),
              icon: _actionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Dokončit výjezd'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
              ),
            ),
          ),
      ],
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
