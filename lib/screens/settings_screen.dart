import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/supabase_service.dart';

/// Nastavení — theme toggle, odhlášení, about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Vzhled ──────────────────────────────────────────
          _SectionLabel(text: 'VZHLED', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            iconColor: isDark ? Colors.amber : Colors.indigo,
            title: 'Tmavý režim',
            subtitle: isDark ? 'Zapnuto' : 'Vypnuto',
            isDark: isDark,
            trailing: Switch.adaptive(
              value: isDark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              activeColor: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 20),

          // ── Notifikace ──────────────────────────────────────
          _SectionLabel(text: 'NOTIFIKACE', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Push notifikace',
            subtitle: 'Upozornění na nové SOS požadavky',
            isDark: isDark,
            trailing: Switch.adaptive(
              value: true,
              onChanged: (_) {},
              activeColor: const Color(0xFF22C55E),
            ),
          ),
          _SettingsTile(
            icon: Icons.volume_up_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Zvukové upozornění',
            subtitle: 'Zvuk při novém požadavku',
            isDark: isDark,
            trailing: Switch.adaptive(
              value: true,
              onChanged: (_) {},
              activeColor: const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 20),

          // ── Účet ────────────────────────────────────────────
          _SectionLabel(text: 'ÚČET', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.person_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: 'Upravit profil',
            subtitle: 'Jméno, telefon, kategorie',
            isDark: isDark,
            onTap: () {
              // TODO: Navigate to edit profile
            },
          ),
          _SettingsTile(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF22C55E),
            title: 'Soukromí a zabezpečení',
            subtitle: 'Správa oprávnění',
            isDark: isDark,
            onTap: () {},
          ),
          const SizedBox(height: 20),

          // ── O aplikaci ──────────────────────────────────────
          _SectionLabel(text: 'O APLIKACI', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.grey,
            title: 'SOS HNED Partner',
            subtitle: 'Verze 1.0.0 · © 2026 SOS HNED s.r.o.',
            isDark: isDark,
          ),
          _SettingsTile(
            icon: Icons.description_rounded,
            iconColor: Colors.grey,
            title: 'Podmínky služby',
            subtitle: 'Právní dokumenty',
            isDark: isDark,
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // ── Logout ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Odhlásit se?'),
                    content: const Text(
                        'Opravdu se chcete odhlásit z partnerského účtu?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Zrušit'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Odhlásit',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await SupabaseService.instance.signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 18),
              label: const Text(
                'Odhlásit se',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: isDark ? Colors.white38 : Colors.grey[500],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
