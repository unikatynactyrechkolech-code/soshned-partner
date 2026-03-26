import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_service.dart';

/// Registrační obrazovka — vytvoření profilu partnera.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jmenoController = TextEditingController();
  final _firmaController = TextEditingController();
  final _telefonController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresaController = TextEditingController();

  String _kategorie = 'zamecnik';
  bool _loading = false;

  static const _kategorie_options = {
    'zamecnik': 'Zámečník',
    'odtahovka': 'Odtahovka',
    'servis': 'Servisy',
    'instalater': 'Hav. Instalatér',
  };

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await SupabaseService.instance.createPartnerProfile(
        jmeno: _jmenoController.text.trim(),
        firma: _firmaController.text.trim().isEmpty
            ? null
            : _firmaController.text.trim(),
        telefon: _telefonController.text.trim(),
        email: _emailController.text.trim(),
        kategorie: _kategorie,
        adresa: _adresaController.text.trim().isEmpty
            ? null
            : _adresaController.text.trim(),
      );

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba registrace: $e'),
            backgroundColor: Colors.red,
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
    _firmaController.dispose();
    _telefonController.dispose();
    _emailController.dispose();
    _adresaController.dispose();
    super.dispose();
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
        title: const Text('Registrace partnera'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF3B82F6), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vyplňte údaje pro vytvoření partnerského účtu. '
                          'Po ověření budete moci přijímat SOS požadavky.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF3B82F6),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Jméno
                TextFormField(
                  controller: _jmenoController,
                  decoration: const InputDecoration(
                    labelText: 'Jméno a příjmení *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Povinné pole' : null,
                ),
                const SizedBox(height: 16),

                // Firma
                TextFormField(
                  controller: _firmaController,
                  decoration: const InputDecoration(
                    labelText: 'Firma / IČO (nepovinné)',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Telefon
                TextFormField(
                  controller: _telefonController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+420 ...',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Povinné pole' : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Povinné pole';
                    if (!v.contains('@')) return 'Neplatný e-mail';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Kategorie
                DropdownButtonFormField<String>(
                  value: _kategorie,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _kategorie_options.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _kategorie = v);
                  },
                ),
                const SizedBox(height: 16),

                // Adresa
                TextFormField(
                  controller: _adresaController,
                  decoration: const InputDecoration(
                    labelText: 'Adresa / Město (nepovinné)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Zaregistrovat se'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
