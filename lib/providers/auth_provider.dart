import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════════
//  Auth state provider
// ═══════════════════════════════════════════════════════════════════

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.instance.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.instance.currentUser;
});

// ═══════════════════════════════════════════════════════════════════
//  Partner profile provider
// ═══════════════════════════════════════════════════════════════════

final partnerProfileProvider = FutureProvider<Partner?>((ref) async {
  // Automaticky se refreshne když se změní auth state
  ref.watch(authStateProvider);
  return await SupabaseService.instance.getMyProfile();
});

// ═══════════════════════════════════════════════════════════════════
//  Online status provider
// ═══════════════════════════════════════════════════════════════════

final isOnlineProvider = StateNotifierProvider<OnlineStatusNotifier, bool>((ref) {
  return OnlineStatusNotifier(ref);
});

class OnlineStatusNotifier extends StateNotifier<bool> {
  final Ref _ref;

  OnlineStatusNotifier(this._ref) : super(false) {
    // Inicializuj z profilu
    _ref.listen(partnerProfileProvider, (_, next) {
      next.whenData((partner) {
        if (partner != null) state = partner.isOnline;
      });
    });
  }

  Future<void> toggle() async {
    final profile = _ref.read(partnerProfileProvider).valueOrNull;
    if (profile == null) return;

    final newState = !state;
    state = newState;

    try {
      await SupabaseService.instance.toggleOnline(profile.id, newState);
      // Refresh profil
      _ref.invalidate(partnerProfileProvider);
    } catch (e) {
      // Rollback on error
      state = !newState;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Pending SOS requests provider
// ═══════════════════════════════════════════════════════════════════

final pendingRequestsProvider = FutureProvider<List<SosRequest>>((ref) async {
  final partner = ref.watch(partnerProfileProvider).valueOrNull;
  if (partner == null) return [];

  return await SupabaseService.instance.getPendingRequests(partner.kategorie);
});

// ═══════════════════════════════════════════════════════════════════
//  My active requests provider (accepted + in_progress)
// ═══════════════════════════════════════════════════════════════════

final activeRequestsProvider = FutureProvider<List<SosRequest>>((ref) async {
  final partner = ref.watch(partnerProfileProvider).valueOrNull;
  if (partner == null) return [];

  return await SupabaseService.instance.getMyActiveRequests(partner.id);
});

// ═══════════════════════════════════════════════════════════════════
//  History provider
// ═══════════════════════════════════════════════════════════════════

final historyRequestsProvider = FutureProvider<List<SosRequest>>((ref) async {
  final partner = ref.watch(partnerProfileProvider).valueOrNull;
  if (partner == null) return [];

  return await SupabaseService.instance.getCompletedRequests(partner.id);
});
