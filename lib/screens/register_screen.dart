import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';

/// Registrační obrazovka — multi-step wizard (3 kroky).
/// Krok 1: E-mail + heslo (účet)
/// Krok 2: Osobní údaje (jméno, telefon, firma/IČO)
/// Krok 3: Profesní údaje (kategorie, adresa)
/// Všechna pole jsou povinná.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // ── Form keys per step ────────────────────────────────────────────
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();
  final _jmenoController = TextEditingController();
  final _telefonController = TextEditingController();
  final _firmaController = TextEditingController();
  final _adresaController = TextEditingController();

  String _kategorie = 'zamecnik';
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscurePassword2 = true;
  int _currentStep = 0; // 0, 1, 2

  static const _kategorieOptions = {
    'zamecnik': 'Zámečník',
    'odtahovka': 'Odtahovka',
    'servis': 'Servisy',
    'instalater': 'Hav. Instalatér',
  };

  // ── Step titles & icons ───────────────────────────────────────────
  static const _stepInfo = [
    ('Účet', Icons.email_outlined),
    ('Osobní údaje', Icons.person_outline_rounded),
    ('Profesní údaje', Icons.work_outline_rounded),
  ];

  // ── Navigation ────────────────────────────────────────────────────
  void _nextStep() {
    final isValid = switch (_currentStep) {
      0 => _formKey1.currentState?.validate() ?? false,
      1 => _formKey2.currentState?.validate() ?? false,
      _ => false,
    };
    if (!isValid) return;
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  // ── Submit (final step) ───────────────────────────────────────────
  Future<void> _register() async {
    if (!(_formKey3.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      // 1) Vytvoř Supabase auth účet
      final authResponse = await SupabaseService.instance.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (authResponse.user == null) {
        throw Exception('Registrace selhala — zkontrolujte údaje');
      }

      // 2) Vytvoř partner profil v DB
      await SupabaseService.instance.createPartnerProfile(
        jmeno: _jmenoController.text.trim(),
        firma: _firmaController.text.trim(),
        telefon: _telefonController.text.trim(),
        email: _emailController.text.trim(),
        kategorie: _kategorie,
        adresa: _adresaController.text.trim(),
        // Výchozí poloha Praha — partner si ji poté nastaví na mapě
        lat: 50.0755,
        lng: 14.4378,
      );

      // 3) Refresh providery a přesměruj na dashboard
      ref.invalidate(partnerProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Registrace úspěšná! Vítejte.'),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('already registered') ||
            msg.contains('already been registered')) {
          msg = 'Tento e-mail je již registrovaný. Zkuste se přihlásit.';
        } else if (msg.contains('weak_password') ||
            msg.contains('at least 6')) {
          msg = 'Heslo musí mít alespoň 6 znaků.';
        } else if (msg.contains('invalid') && msg.contains('email')) {
          msg = 'Neplatný e-mail.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    _jmenoController.dispose();
    _telefonController.dispose();
    _firmaController.dispose();
    _adresaController.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _prevStep,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Registrace partnera',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    'Krok ${_currentStep + 1}/3',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Step indicator ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(3, (i) {
                  final isActive = i == _currentStep;
                  final isDone = i < _currentStep;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: isDone
                                  ? const Color(0xFF22C55E)
                                  : isActive
                                      ? const Color(0xFF3B82F6)
                                      : isDark
                                          ? Colors.white12
                                          : Colors.grey[200],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isDone
                                    ? Icons.check_circle_rounded
                                    : _stepInfo[i].$2,
                                size: 14,
                                color: isDone
                                    ? const Color(0xFF22C55E)
                                    : isActive
                                        ? const Color(0xFF3B82F6)
                                        : isDark
                                            ? Colors.white38
                                            : Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _stepInfo[i].$1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDone
                                      ? const Color(0xFF22C55E)
                                      : isActive
                                          ? const Color(0xFF3B82F6)
                                          : isDark
                                              ? Colors.white38
                                              : Colors.grey[400],
                                  fontWeight: isActive || isDone
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: SingleChildScrollView(
                  key: ValueKey(_currentStep),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: switch (_currentStep) {
                    0 => _buildStep1(theme, isDark),
                    1 => _buildStep2(theme, isDark),
                    2 => _buildStep3(theme, isDark),
                    _ => const SizedBox(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  STEP 1 — Účet (email, heslo, potvrzení hesla)
  // ═════════════════════════════════════════════════════════════════
  Widget _buildStep1(ThemeData theme, bool isDark) {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBox(
            theme,
            isDark,
            icon: Icons.lock_outline_rounded,
            text: 'Zadejte přihlašovací údaje pro váš partnerský účet.',
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 24),

          // E-mail
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDeco('E-mail', Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Povinné pole';
              if (!v.contains('@') || !v.contains('.')) return 'Neplatný e-mail';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Heslo
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: _inputDeco('Heslo', Icons.lock_outline_rounded).copyWith(
              hintText: 'Minimálně 6 znaků',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Povinné pole';
              if (v.length < 6) return 'Minimálně 6 znaků';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Potvrzení hesla
          TextFormField(
            controller: _password2Controller,
            obscureText: _obscurePassword2,
            textInputAction: TextInputAction.done,
            decoration:
                _inputDeco('Potvrzení hesla', Icons.lock_outline_rounded)
                    .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword2
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword2 = !_obscurePassword2),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Povinné pole';
              if (v != _passwordController.text) return 'Hesla se neshodují';
              return null;
            },
          ),
          const SizedBox(height: 32),

          _navButton('Pokračovat', onPressed: _nextStep),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  STEP 2 — Osobní údaje (jméno, telefon, firma/IČO)
  // ═════════════════════════════════════════════════════════════════
  Widget _buildStep2(ThemeData theme, bool isDark) {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBox(
            theme,
            isDark,
            icon: Icons.person_outline_rounded,
            text: 'Vyplňte své osobní a firemní údaje. Všechna pole jsou povinná.',
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 24),

          // Jméno a příjmení
          TextFormField(
            controller: _jmenoController,
            textInputAction: TextInputAction.next,
            decoration: _inputDeco('Jméno a příjmení', Icons.person_outline_rounded),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Povinné pole' : null,
          ),
          const SizedBox(height: 16),

          // Telefon
          TextFormField(
            controller: _telefonController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _inputDeco('Telefon', Icons.phone_outlined)
                .copyWith(hintText: '+420 ...'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Povinné pole' : null,
          ),
          const SizedBox(height: 16),

          // Firma / IČO
          TextFormField(
            controller: _firmaController,
            textInputAction: TextInputAction.done,
            decoration: _inputDeco('Firma / IČO', Icons.business_rounded),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Povinné pole' : null,
          ),
          const SizedBox(height: 32),

          _navButton('Pokračovat', onPressed: _nextStep),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  STEP 3 — Profesní údaje (kategorie, adresa) + submit
  // ═════════════════════════════════════════════════════════════════
  Widget _buildStep3(ThemeData theme, bool isDark) {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoBox(
            theme,
            isDark,
            icon: Icons.work_outline_rounded,
            text:
                'Zvolte kategorii služeb a vyplňte adresu provozovny. Všechna pole jsou povinná.',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 24),

          // Kategorie
          DropdownButtonFormField<String>(
            value: _kategorie,
            decoration: _inputDeco('Kategorie', Icons.category_outlined),
            items: _kategorieOptions.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _kategorie = v);
            },
            validator: (v) =>
                v == null || v.isEmpty ? 'Vyberte kategorii' : null,
          ),
          const SizedBox(height: 16),

          // Adresa
          TextFormField(
            controller: _adresaController,
            textInputAction: TextInputAction.done,
            decoration: _inputDeco('Adresa / Město', Icons.location_on_outlined)
                .copyWith(hintText: 'např. Vinohradská 12, Praha 2'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Povinné pole' : null,
          ),
          const SizedBox(height: 32),

          // Summary preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shrnutí registrace',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _summaryRow('E-mail', _emailController.text),
                _summaryRow('Jméno', _jmenoController.text),
                _summaryRow('Telefon', _telefonController.text),
                _summaryRow('Firma/IČO', _firmaController.text),
                _summaryRow(
                    'Kategorie',
                    _kategorieOptions[_kategorie] ?? _kategorie),
                _summaryRow('Adresa', _adresaController.text),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Zaregistrovat se',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═════════════════════════════════════════════════════════════════

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: '$label *',
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _infoBox(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(String label, {required VoidCallback onPressed}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
