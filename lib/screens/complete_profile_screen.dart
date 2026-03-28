import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';

/// Obrazovka pro dokončení profilu po Google OAuth přihlášení.
/// Postupné zobrazování polí (ne dotazník) — jedno po druhém.
/// Všechna pole jsou povinná.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _jmenoController = TextEditingController();
  final _telefonController = TextEditingController();
  final _firmaController = TextEditingController();
  final _adresaController = TextEditingController();

  String _kategorie = 'zamecnik';
  bool _loading = false;

  /// Which fields are currently visible (progressive reveal)
  int _visibleFields = 1; // Start with just jméno

  static const _kategorieOptions = {
    'zamecnik': 'Zámečník',
    'odtahovka': 'Odtahovka',
    'servis': 'Servisy',
    'instalater': 'Hav. Instalatér',
  };

  /// Total number of field groups
  static const _totalFields = 5; // jméno, telefon, firma/IČO, kategorie, adresa

  /// Check if current visible field is filled and reveal next
  void _revealNext() {
    // Validate current field before proceeding
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_visibleFields < _totalFields) {
      setState(() => _visibleFields++);
    }
  }

  /// Submit the profile
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('Uživatel není přihlášen');

      await SupabaseService.instance.createPartnerProfile(
        jmeno: _jmenoController.text.trim(),
        firma: _firmaController.text.trim(),
        telefon: _telefonController.text.trim(),
        email: user.email ?? '',
        kategorie: _kategorie,
        adresa: _adresaController.text.trim(),
        lat: 50.0755, // Praha default
        lng: 14.4378,
      );

      // Refresh profile provider
      ref.invalidate(partnerProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Profil dokončen! Vítejte.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
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
    _jmenoController.dispose();
    _telefonController.dispose();
    _firmaController.dispose();
    _adresaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = SupabaseService.instance.currentUser;
    final allFieldsVisible = _visibleFields >= _totalFields;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  // Logo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Dokončete svůj profil',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? 'Přihlášen přes Google',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _visibleFields / _totalFields,
                      backgroundColor:
                          isDark ? Colors.white10 : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF22C55E),
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_visibleFields / $_totalFields',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Form ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. Jméno ──────────────────────────────────
                      _buildFieldEntry(
                        index: 1,
                        icon: Icons.person_outline_rounded,
                        label: 'Jméno a příjmení',
                        child: TextFormField(
                          controller: _jmenoController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDeco(
                            'Jméno a příjmení',
                            Icons.person_outline_rounded,
                          ),
                          onFieldSubmitted: (_) => _revealNext(),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Povinné pole'
                              : null,
                        ),
                      ),

                      // ── 2. Telefon ────────────────────────────────
                      if (_visibleFields >= 2)
                        _buildFieldEntry(
                          index: 2,
                          icon: Icons.phone_outlined,
                          label: 'Telefonní číslo',
                          child: TextFormField(
                            controller: _telefonController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDeco(
                              'Telefon',
                              Icons.phone_outlined,
                            ).copyWith(hintText: '+420 ...'),
                            onFieldSubmitted: (_) => _revealNext(),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Povinné pole'
                                : null,
                          ),
                        ),

                      // ── 3. Firma / IČO ────────────────────────────
                      if (_visibleFields >= 3)
                        _buildFieldEntry(
                          index: 3,
                          icon: Icons.business_rounded,
                          label: 'Firma / IČO',
                          child: TextFormField(
                            controller: _firmaController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDeco(
                              'Firma / IČO',
                              Icons.business_rounded,
                            ),
                            onFieldSubmitted: (_) => _revealNext(),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Povinné pole'
                                : null,
                          ),
                        ),

                      // ── 4. Kategorie ──────────────────────────────
                      if (_visibleFields >= 4)
                        _buildFieldEntry(
                          index: 4,
                          icon: Icons.category_outlined,
                          label: 'Kategorie služeb',
                          child: DropdownButtonFormField<String>(
                            value: _kategorie,
                            decoration: _inputDeco(
                              'Kategorie',
                              Icons.category_outlined,
                            ),
                            items: _kategorieOptions.entries
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _kategorie = v);
                                _revealNext();
                              }
                            },
                            validator: (v) => v == null || v.isEmpty
                                ? 'Vyberte kategorii'
                                : null,
                          ),
                        ),

                      // ── 5. Adresa ─────────────────────────────────
                      if (_visibleFields >= 5)
                        _buildFieldEntry(
                          index: 5,
                          icon: Icons.location_on_outlined,
                          label: 'Adresa provozovny',
                          child: TextFormField(
                            controller: _adresaController,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDeco(
                              'Adresa / Město',
                              Icons.location_on_outlined,
                            ).copyWith(
                              hintText: 'např. Vinohradská 12, Praha 2',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Povinné pole'
                                : null,
                          ),
                        ),

                      const SizedBox(height: 24),

                      // ── Next / Submit button ──────────────────────
                      if (!allFieldsVisible)
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _revealNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Pokračovat',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),

                      if (allFieldsVisible) ...[
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
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
                                      Icon(Icons.check_circle_rounded,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Dokončit registraci',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Sign out link
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await SupabaseService.instance.signOut();
                            if (mounted) context.go('/login');
                          },
                          child: Text(
                            'Odhlásit se',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═════════════════════════════════════════════════════════════════

  Widget _buildFieldEntry({
    required int index,
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field label with number
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  icon,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: '$label *',
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
