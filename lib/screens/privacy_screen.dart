import 'package:flutter/material.dart';

/// Soukromí a zabezpečení
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soukromí a zabezpečení'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            isDark: isDark,
            icon: Icons.lock_rounded,
            iconColor: const Color(0xFF22C55E),
            title: 'Zabezpečení účtu',
            children: [
              _InfoRow(
                isDark: isDark,
                label: 'Přihlášení',
                value: 'E-mail + heslo / Google OAuth',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Šifrování',
                value: 'TLS 1.3 (HTTPS)',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Databáze',
                value: 'Supabase (PostgreSQL) s RLS',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            isDark: isDark,
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: 'Poloha',
            children: [
              _InfoRow(
                isDark: isDark,
                label: 'Sledování polohy',
                value: 'Pouze když jste online',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Účel',
                value: 'Zobrazení na mapě pro zákazníky',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Sdílení',
                value: 'Pouze registrovaným uživatelům',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            isDark: isDark,
            icon: Icons.storage_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Data a úložiště',
            children: [
              _InfoRow(
                isDark: isDark,
                label: 'Osobní údaje',
                value: 'Jméno, telefon, e-mail, adresa',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Účel zpracování',
                value: 'Poskytování služeb SOS HNED',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Doba uložení',
                value: 'Po dobu existence účtu',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Právo na výmaz',
                value: 'Kontaktujte podporu',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            isDark: isDark,
            icon: Icons.notifications_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Oprávnění aplikace',
            children: [
              _InfoRow(
                isDark: isDark,
                label: 'Poloha (GPS)',
                value: 'Zobrazení na mapě zákazníků',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Push notifikace',
                value: 'Upozornění na nové SOS požadavky',
              ),
              _InfoRow(
                isDark: isDark,
                label: 'Internet',
                value: 'Komunikace se serverem',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.blue[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.blue[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.email_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Máte dotaz ohledně soukromí?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'podpora@soshned.cz',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;

  const _InfoRow({
    required this.isDark,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
