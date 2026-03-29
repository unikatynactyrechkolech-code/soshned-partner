import 'package:flutter/material.dart';

/// O aplikaci — informace o SOS HNED
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('O aplikaci'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo & Name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SOS HNED',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Partnerská aplikace',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Verze 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // About text
          _InfoCard(
            isDark: isDark,
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: 'Co je SOS HNED?',
            text:
                'SOS HNED je platforma pro rychlé propojení zákazníků s poskytovateli havarijních služeb. '
                'Aplikace umožňuje zákazníkům okamžitě najít nejbližšího dostupného zámečníka, odtahovku, '
                'servis nebo instalatéra a kontaktovat ho v reálném čase.',
          ),
          const SizedBox(height: 12),

          _InfoCard(
            isDark: isDark,
            icon: Icons.handshake_rounded,
            iconColor: const Color(0xFF22C55E),
            title: 'Pro partnery',
            text:
                'Jako partner SOS HNED přijímáte SOS požadavky od zákazníků ve vaší zóně. '
                'Můžete komunikovat se zákazníky přes chat, sledovat svou polohu na mapě '
                'a spravovat své zakázky od přijetí až po dokončení.',
          ),
          const SizedBox(height: 12),

          _InfoCard(
            isDark: isDark,
            icon: Icons.rocket_launch_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Funkce aplikace',
            text:
                '• Přijímání a správa SOS požadavků\n'
                '• Real-time chat se zákazníky\n'
                '• Mapa s vaší polohou a požadavky\n'
                '• Online/offline přepínač\n'
                '• Historie dokončených zakázek\n'
                '• Hodnocení a recenze',
          ),
          const SizedBox(height: 12),

          // Company info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KONTAKT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white30 : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 12),
                _ContactRow(
                  isDark: isDark,
                  icon: Icons.business_rounded,
                  text: 'SOS HNED s.r.o.',
                ),
                _ContactRow(
                  isDark: isDark,
                  icon: Icons.email_rounded,
                  text: 'podpora@soshned.cz',
                ),
                _ContactRow(
                  isDark: isDark,
                  icon: Icons.language_rounded,
                  text: 'www.soshned.cz',
                ),
                _ContactRow(
                  isDark: isDark,
                  icon: Icons.location_city_rounded,
                  text: 'Praha, Česká republika',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              '© 2026 SOS HNED s.r.o. Všechna práva vyhrazena.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;

  const _InfoCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String text;

  const _ContactRow({
    required this.isDark,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: isDark ? Colors.white38 : Colors.grey[400]),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
