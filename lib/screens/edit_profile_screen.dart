import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

/// Obrazovka pro úpravu profilu partnera
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _jmenoController;
  late TextEditingController _firmaController;
  late TextEditingController _telefonController;
  late TextEditingController _adresaController;
  String _kategorie = 'zamecnik';
  bool _saving = false;
  bool _initialized = false;

  static const _categories = [
    ('zamecnik', 'Zámečník'),
    ('odtahovka', 'Odtahovka'),
    ('servis', 'Servisy'),
    ('instalater', 'Hav. Instalatér'),
  ];

  @override
  void initState() {
    super.initState();
    _jmenoController = TextEditingController();
    _firmaController = TextEditingController();
    _telefonController = TextEditingController();
    _adresaController = TextEditingController();
  }

  @override
  void dispose() {
    _jmenoController.dispose();
    _firmaController.dispose();
    _telefonController.dispose();
    _adresaController.dispose();
    super.dispose();
  }

  void _initFromPartner(Partner partner) {
    if (_initialized) return;
    _initialized = true;
    _jmenoController.text = partner.jmeno;
    _firmaController.text = partner.firma ?? '';
    _telefonController.text = partner.telefon;
    _adresaController.text = partner.adresa ?? '';
    _kategorie = partner.kategorie;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final partner = ref.read(partnerProfileProvider).valueOrNull;
      if (partner == null) throw Exception('Profil nenalezen');

      final updates = <String, dynamic>{
        'jmeno': _jmenoController.text.trim(),
        'telefon': _telefonController.text.trim(),
        'kategorie': _kategorie,
      };
      // Volitelné pole — přidáme jen pokud nejsou prázdné
      final firma = _firmaController.text.trim();
      if (firma.isNotEmpty) {
        updates['firma'] = firma;
      }
      final adresa = _adresaController.text.trim();
      if (adresa.isNotEmpty) {
        updates['adresa'] = adresa;
      }

      debugPrint('Ukládám profil: $updates');

      await SupabaseService.instance.updatePartnerProfile(partner.id, updates);

      // Refresh the profile provider
      ref.invalidate(partnerProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil úspěšně uložen'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final partnerAsync = ref.watch(partnerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravit profil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Uložit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
          ),
        ],
      ),
      body: partnerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Chyba: $e')),
        data: (partner) {
          if (partner == null) {
            return const Center(child: Text('Profil nenalezen'));
          }

          _initFromPartner(partner);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey[200]!,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Jméno
                _buildField(
                  controller: _jmenoController,
                  label: 'Jméno a příjmení',
                  icon: Icons.person_rounded,
                  isDark: isDark,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Zadejte jméno' : null,
                ),
                const SizedBox(height: 14),

                // Firma
                _buildField(
                  controller: _firmaController,
                  label: 'Firma (nepovinné)',
                  icon: Icons.business_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Telefon
                _buildField(
                  controller: _telefonController,
                  label: 'Telefon',
                  icon: Icons.phone_rounded,
                  isDark: isDark,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Zadejte telefon' : null,
                ),
                const SizedBox(height: 14),

                // Adresa
                _buildField(
                  controller: _adresaController,
                  label: 'Adresa (nepovinné)',
                  icon: Icons.location_on_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // Kategorie
                _buildDropdown(isDark),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Uložit změny',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : Colors.grey[500],
        ),
        prefixIcon: Icon(icon,
            size: 20, color: isDark ? Colors.white38 : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF3B82F6),
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _kategorie,
        decoration: InputDecoration(
          labelText: 'Kategorie',
          labelStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey[500],
          ),
          prefixIcon: Icon(Icons.category_rounded,
              size: 20, color: isDark ? Colors.white38 : Colors.grey[400]),
          border: InputBorder.none,
        ),
        dropdownColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        items: _categories
            .map((c) => DropdownMenuItem(
                  value: c.$1,
                  child: Text(c.$2),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _kategorie = v);
        },
      ),
    );
  }
}
