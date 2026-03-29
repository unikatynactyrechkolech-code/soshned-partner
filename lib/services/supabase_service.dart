import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../config/app_config.dart';

/// Služba pro komunikaci se Supabase databází.
/// Handluje CRUD operace na tabulkách `partners` a `sos_requests`
/// + realtime subscriptions.
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════════════════════════════

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Přihlášení přes Google OAuth (Supabase provider).
  /// Na webu VŽDY přesměruje na produkční URL (musí být v Supabase Redirect URLs).
  /// Na mobilu na deep link.
  Future<bool> signInWithGoogle() async {
    // Redirect URL musí být whitelistovaná v Supabase Dashboard:
    //   Authentication → URL Configuration → Redirect URLs
    // Na webu vždy používáme produkční URL, aby Supabase callback fungoval.
    // Na localhost se po přihlášení přesměruje na produkci (kde uživatel už bude přihlášen).
    final redirectUrl = kIsWeb
        ? '${AppConfig.productionUrl}/'
        : 'io.supabase.soshned://login-callback/';

    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
  }

  /// Přihlášení přes email a heslo
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registrace přes email a heslo
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Odhlášení
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PARTNER PROFILE
  // ═══════════════════════════════════════════════════════════════════

  /// Získej profil přihlášeného partnera
  Future<Partner?> getMyProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('partners')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Partner.fromJson(data);
  }

  /// Vytvoř nový profil partnera (registrace)
  Future<Partner> createPartnerProfile({
    required String jmeno,
    String? firma,
    required String telefon,
    required String email,
    required String kategorie,
    String? adresa,
    double? lat,
    double? lng,
  }) async {
    final userId = currentUser?.id;

    final data = await _client.from('partners').insert({
      'user_id': userId,
      'jmeno': jmeno,
      'firma': firma,
      'telefon': telefon,
      'email': email,
      'kategorie': kategorie,
      'adresa': adresa,
      'lat': lat,
      'lng': lng,
      'zona': 'praha',
      'is_online': false,
    }).select().single();

    return Partner.fromJson(data);
  }

  /// Aktualizuj profil partnera
  Future<Partner> updatePartnerProfile(String partnerId, Map<String, dynamic> updates) async {
    final data = await _client
        .from('partners')
        .update(updates)
        .eq('id', partnerId)
        .select()
        .single();

    return Partner.fromJson(data);
  }

  /// Přepni online/offline stav
  Future<Partner> toggleOnline(String partnerId, bool isOnline) async {
    return await updatePartnerProfile(partnerId, {'is_online': isOnline});
  }

  /// Aktualizuj polohu partnera (+ last_seen_at pokud sloupec existuje)
  Future<void> updateLocation(String partnerId, double lat, double lng) async {
    // Nejdřív zkusíme s last_seen_at, pokud selže (sloupec neexistuje),
    // uložíme jen lat/lng.
    try {
      await _client.from('partners').update({
        'lat': lat,
        'lng': lng,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', partnerId);
    } catch (_) {
      await _client.from('partners').update({
        'lat': lat,
        'lng': lng,
      }).eq('id', partnerId);
    }
  }

  /// Získej VŠECHNY partnery s polohou (pro mapu — i offline, klient vidí všechny)
  Future<List<Partner>> getAllPartnersWithLocation() async {
    final data = await _client
        .from('partners')
        .select()
        .not('lat', 'is', null)
        .not('lng', 'is', null);

    return (data as List).map((e) => Partner.fromJson(e)).toList();
  }

  /// Získej všechny online partnery (pro mapu)
  Future<List<Partner>> getAllOnlinePartners() async {
    final data = await _client
        .from('partners')
        .select()
        .eq('is_online', true)
        .not('lat', 'is', null)
        .not('lng', 'is', null);

    return (data as List).map((e) => Partner.fromJson(e)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SOS REQUESTS
  // ═══════════════════════════════════════════════════════════════════

  /// Získej pending requesty pro moji kategorii
  Future<List<SosRequest>> getPendingRequests(String kategorie) async {
    final data = await _client
        .from('sos_requests')
        .select()
        .eq('kategorie', kategorie)
        .eq('status', AppConfig.statusPending)
        .order('created_at', ascending: false);

    return (data as List).map((e) => SosRequest.fromJson(e)).toList();
  }

  /// Získej moje přijaté requesty (accepted + in_progress)
  Future<List<SosRequest>> getMyActiveRequests(String partnerId) async {
    final data = await _client
        .from('sos_requests')
        .select()
        .eq('accepted_by', partnerId)
        .inFilter('status', [AppConfig.statusAccepted, AppConfig.statusInProgress])
        .order('accepted_at', ascending: false);

    return (data as List).map((e) => SosRequest.fromJson(e)).toList();
  }

  /// Získej historii dokončených requestů
  Future<List<SosRequest>> getCompletedRequests(String partnerId) async {
    final data = await _client
        .from('sos_requests')
        .select()
        .eq('accepted_by', partnerId)
        .eq('status', AppConfig.statusCompleted)
        .order('completed_at', ascending: false)
        .limit(50);

    return (data as List).map((e) => SosRequest.fromJson(e)).toList();
  }

  /// Přijmi SOS request
  Future<SosRequest> acceptRequest(String requestId, String partnerId) async {
    final data = await _client
        .from('sos_requests')
        .update({
          'status': AppConfig.statusAccepted,
          'accepted_by': partnerId,
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('status', AppConfig.statusPending) // Jen pokud je stále pending (race condition)
        .select()
        .single();

    return SosRequest.fromJson(data);
  }

  /// Označ request jako "na cestě"
  Future<SosRequest> startRequest(String requestId) async {
    final data = await _client
        .from('sos_requests')
        .update({'status': AppConfig.statusInProgress})
        .eq('id', requestId)
        .select()
        .single();

    return SosRequest.fromJson(data);
  }

  /// Dokonči request
  Future<SosRequest> completeRequest(String requestId) async {
    final data = await _client
        .from('sos_requests')
        .update({
          'status': AppConfig.statusCompleted,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .select()
        .single();

    return SosRequest.fromJson(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  REALTIME
  // ═══════════════════════════════════════════════════════════════════

  /// Poslouchej nové SOS requesty pro danou kategorii (realtime)
  RealtimeChannel subscribeSosRequests({
    required String kategorie,
    required void Function(SosRequest) onInsert,
    required void Function(SosRequest) onUpdate,
  }) {
    return _client
        .channel('sos-requests-$kategorie')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'kategorie',
            value: kategorie,
          ),
          callback: (payload) {
            final request = SosRequest.fromJson(payload.newRecord);
            onInsert(request);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'sos_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'kategorie',
            value: kategorie,
          ),
          callback: (payload) {
            final request = SosRequest.fromJson(payload.newRecord);
            onUpdate(request);
          },
        )
        .subscribe();
  }

  /// Poslouchej změny v tabulce partners (INSERT + UPDATE) — pro realtime mapu
  RealtimeChannel subscribePartnerChanges({
    required void Function(Map<String, dynamic>) onPartnerChange,
  }) {
    return _client
        .channel('partners-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'partners',
          callback: (payload) => onPartnerChange(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'partners',
          callback: (payload) => onPartnerChange(payload.newRecord),
        )
        .subscribe();
  }

  /// Odpoj realtime channel
  void unsubscribeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // ── CHAT / MESSAGES ───────────────────────────────────────────────

  /// Načti všechny zprávy pro daný SOS request
  Future<List<Map<String, dynamic>>> getMessages(String sosRequestId) async {
    try {
      final data = await _client
          .from('messages')
          .select()
          .eq('sos_request_id', sosRequestId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  /// Odešli zprávu
  Future<Map<String, dynamic>?> sendMessage({
    required String sosRequestId,
    required String senderType,
    required String senderId,
    required String text,
  }) async {
    try {
      final data = await _client.from('messages').insert({
        'sos_request_id': sosRequestId,
        'sender_type': senderType,
        'sender_id': senderId,
        'text': text,
      }).select().single();
      return data;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  /// Realtime odběr zpráv pro SOS request
  RealtimeChannel subscribeMessages({
    required String sosRequestId,
    required void Function(Map<String, dynamic>) onMessage,
  }) {
    return _client
        .channel('messages-$sosRequestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sos_request_id',
            value: sosRequestId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }
}
