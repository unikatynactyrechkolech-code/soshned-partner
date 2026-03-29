import 'package:flutter/material.dart';

/// Podmínky služby
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Podmínky služby'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Podmínky používání služby SOS HNED',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Poslední aktualizace: 1. ledna 2026',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),

          _TermsSection(
            isDark: isDark,
            number: '1',
            title: 'Obecná ustanovení',
            text:
                'Tyto podmínky upravují práva a povinnosti uživatelů aplikace SOS HNED '
                '(dále jen „Aplikace"), kterou provozuje společnost SOS HNED s.r.o. '
                'se sídlem v Praze (dále jen „Provozovatel").\n\n'
                'Používáním Aplikace souhlasíte s těmito podmínkami.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '2',
            title: 'Registrace a partnerský účet',
            text:
                'Pro využívání služeb Aplikace jako partner je nutné vytvořit partnerský účet '
                'a poskytnout pravdivé a aktuální údaje včetně jména, telefonu, e-mailu a kategorie služby.\n\n'
                'Partner je povinen udržovat své kontaktní údaje aktuální.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '3',
            title: 'Poskytování služeb',
            text:
                'Partner se zavazuje poskytovat služby profesionálně, včas a v souladu s platnými '
                'právními předpisy. Partner je odpovědný za kvalitu poskytovaných služeb.\n\n'
                'Přijetím SOS požadavku se partner zavazuje dostavit se na místo v přiměřené době.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '4',
            title: 'Hodnocení a recenze',
            text:
                'Zákazníci mohou hodnotit služby partnerů prostřednictvím systému hodnocení. '
                'Hodnocení je veřejné a slouží k zajištění kvality služeb.\n\n'
                'Provozovatel si vyhrazuje právo odstranit účty partnerů s opakovaně nízkým hodnocením.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '5',
            title: 'Poloha a soukromí',
            text:
                'Partner souhlasí se sdílením své polohy při aktivním (online) stavu. '
                'Poloha je zobrazena zákazníkům na mapě pro účely poskytování služeb.\n\n'
                'Zpracování osobních údajů se řídí zásadami ochrany osobních údajů Provozovatele.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '6',
            title: 'Komunikace',
            text:
                'Veškerá komunikace mezi partnerem a zákazníkem prostřednictvím chatu Aplikace '
                'je zaznamenávána pro účely řešení sporů a zajištění kvality.\n\n'
                'Partner se zavazuje komunikovat se zákazníky profesionálně a slušně.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '7',
            title: 'Omezení odpovědnosti',
            text:
                'Provozovatel neodpovídá za škody vzniklé v souvislosti s poskytováním služeb '
                'partnerů zákazníkům. Provozovatel poskytuje pouze platformu pro propojení '
                'zákazníků a partnerů.\n\n'
                'Aplikace je poskytována „jak je" bez záruky nepřetržitého provozu.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '8',
            title: 'Ukončení účtu',
            text:
                'Partner může svůj účet kdykoli zrušit kontaktováním podpory. '
                'Provozovatel si vyhrazuje právo zrušit účet partnera při porušení těchto podmínek.\n\n'
                'Po zrušení účtu budou osobní údaje smazány v souladu s platnými předpisy.',
          ),
          _TermsSection(
            isDark: isDark,
            number: '9',
            title: 'Závěrečná ustanovení',
            text:
                'Tyto podmínky se řídí právním řádem České republiky. '
                'Provozovatel si vyhrazuje právo tyto podmínky kdykoli změnit. '
                'O změnách bude partner informován prostřednictvím Aplikace.\n\n'
                'V případě sporů je příslušný soud v Praze.',
          ),

          const SizedBox(height: 24),
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
                        'Máte dotaz k podmínkám?',
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
                        'pravni@soshned.cz',
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

class _TermsSection extends StatelessWidget {
  final bool isDark;
  final String number;
  final String title;
  final String text;

  const _TermsSection({
    required this.isDark,
    required this.number,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
      ),
    );
  }
}
