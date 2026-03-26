import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/request_card.dart';
import '../widgets/status_badge.dart';

/// Dashboard — hlavní obrazovka partnera.
/// Zobrazuje: online/offline toggle, nové SOS požadavky (realtime),
/// aktivní výjezdy, statistiky.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  RealtimeChannel? _realtimeChannel;
  List<SosRequest> _pendingRequests = [];
  List<SosRequest> _activeRequests = [];
  bool _loadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      SupabaseService.instance.unsubscribeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    if (partner == null) return;

    setState(() => _loadingRequests = true);

    try {
      final pending =
          await SupabaseService.instance.getPendingRequests(partner.kategorie);
      final active =
          await SupabaseService.instance.getMyActiveRequests(partner.id);

      if (mounted) {
        setState(() {
          _pendingRequests = pending;
          _activeRequests = active;
          _loadingRequests = false;
        });
      }

      // Nastav realtime
      _setupRealtime(partner);
    } catch (e) {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  void _setupRealtime(Partner partner) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.instance.subscribeSosRequests(
      kategorie: partner.kategorie,
      onInsert: (request) {
        if (mounted && request.status == SosStatus.pending) {
          setState(() {
            _pendingRequests.insert(0, request);
          });
          // Vibrace / notifikace
          _showNewRequestSnackbar(request);
        }
      },
      onUpdate: (request) {
        if (!mounted) return;
        setState(() {
          // Odeber z pending pokud přijat
          _pendingRequests.removeWhere((r) => r.id == request.id);
          // Aktualizuj aktivní
          final idx = _activeRequests.indexWhere((r) => r.id == request.id);
          if (request.status.isActive && request.acceptedBy == partner.id) {
            if (idx >= 0) {
              _activeRequests[idx] = request;
            } else {
              _activeRequests.insert(0, request);
            }
          } else if (idx >= 0) {
            _activeRequests.removeAt(idx);
          }
        });
      },
    );
  }

  void _showNewRequestSnackbar(SosRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🚨 Nový SOS požadavek: ${request.kategorieLabel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Zobrazit',
          textColor: Colors.white,
          onPressed: () => context.push('/request/${request.id}'),
        ),
      ),
    );
  }

  Future<void> _acceptRequest(SosRequest request) async {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    if (partner == null) return;

    try {
      final updated =
          await SupabaseService.instance.acceptRequest(request.id, partner.id);
      setState(() {
        _pendingRequests.removeWhere((r) => r.id == request.id);
        _activeRequests.insert(0, updated);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Požadavek přijat!'),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final partnerAsync = ref.watch(partnerProfileProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_in_talk_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        title: RichText(
          text: TextSpan(
            style: theme.appBarTheme.titleTextStyle,
            children: const [
              TextSpan(text: 'SOS '),
              TextSpan(
                  text: 'HNED',
                  style: TextStyle(color: Color(0xFFEF4444))),
              TextSpan(
                text: ' Partner',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 20,
              color: isDark ? Colors.amber : Colors.grey[700],
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: partnerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Chyba: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(partnerProfileProvider),
                child: const Text('Zkusit znovu'),
              ),
            ],
          ),
        ),
        data: (partner) {
          if (partner == null) {
            // Partner nemá profil — redirect na registraci
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/register');
            });
            return const SizedBox.shrink();
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Online/Offline Toggle Card ──────────────────
                _OnlineToggleCard(
                  partner: partner,
                  isOnline: isOnline,
                  onToggle: () =>
                      ref.read(isOnlineProvider.notifier).toggle(),
                ),
                const SizedBox(height: 20),

                // ── Quick Stats ─────────────────────────────────
                _QuickStats(
                  pendingCount: _pendingRequests.length,
                  activeCount: _activeRequests.length,
                  rating: partner.hodnoceni,
                  reviewCount: partner.pocetRecenzi,
                ),
                const SizedBox(height: 24),

                // ── Active Requests ─────────────────────────────
                if (_activeRequests.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Aktivní výjezdy',
                    count: _activeRequests.length,
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(height: 8),
                  ..._activeRequests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RequestCard(
                          request: r,
                          type: RequestCardType.active,
                          onTap: () => context.push('/request/${r.id}'),
                        ),
                      )),
                  const SizedBox(height: 20),
                ],

                // ── Pending Requests ────────────────────────────
                _SectionHeader(
                  title: 'Nové SOS požadavky',
                  count: _pendingRequests.length,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(height: 8),

                if (_loadingRequests)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_pendingRequests.isEmpty)
                  _EmptyState(isOnline: isOnline)
                else
                  ..._pendingRequests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RequestCard(
                          request: r,
                          type: RequestCardType.pending,
                          onAccept: () => _acceptRequest(r),
                          onTap: () => context.push('/request/${r.id}'),
                        ),
                      )),

                const SizedBox(height: 80), // Space for bottom nav
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Local widgets
// ═══════════════════════════════════════════════════════════════════

class _OnlineToggleCard extends StatelessWidget {
  final Partner partner;
  final bool isOnline;
  final VoidCallback onToggle;

  const _OnlineToggleCard({
    required this.partner,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOnline
            ? LinearGradient(
                colors: [
                  const Color(0xFF22C55E).withOpacity(0.08),
                  const Color(0xFF22C55E).withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isOnline ? null : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? const Color(0xFF22C55E).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                partner.jmeno.isNotEmpty
                    ? partner.jmeno.substring(0, 1).toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isOnline
                      ? const Color(0xFF22C55E)
                      : (isDark ? Colors.white54 : Colors.grey[600]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.jmeno,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StatusBadge(
                      label: isOnline ? 'Online' : 'Offline',
                      color: isOnline
                          ? const Color(0xFF22C55E)
                          : Colors.grey,
                      isActive: isOnline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      partner.kategorieLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggle
          Transform.scale(
            scale: 1.1,
            child: Switch.adaptive(
              value: isOnline,
              onChanged: (_) => onToggle(),
              activeColor: const Color(0xFF22C55E),
              activeTrackColor: const Color(0xFF22C55E).withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final int pendingCount;
  final int activeCount;
  final double rating;
  final int reviewCount;

  const _QuickStats({
    required this.pendingCount,
    required this.activeCount,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        _StatItem(
          icon: Icons.warning_amber_rounded,
          label: 'Čeká',
          value: '$pendingCount',
          color: const Color(0xFFEF4444),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatItem(
          icon: Icons.directions_car_rounded,
          label: 'Aktivní',
          value: '$activeCount',
          color: const Color(0xFF3B82F6),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatItem(
          icon: Icons.star_rounded,
          label: 'Hodnocení',
          value: rating.toStringAsFixed(1),
          color: const Color(0xFFF59E0B),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatItem(
          icon: Icons.rate_review_rounded,
          label: 'Recenzí',
          value: '$reviewCount',
          color: const Color(0xFF8B5CF6),
          isDark: isDark,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isOnline;

  const _EmptyState({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            isOnline
                ? Icons.inbox_rounded
                : Icons.cloud_off_rounded,
            size: 48,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            isOnline
                ? 'Zatím žádné nové požadavky'
                : 'Jste offline',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOnline
                ? 'Nové SOS požadavky se zobrazí automaticky'
                : 'Přepněte se do online režimu pro příjem požadavků',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
