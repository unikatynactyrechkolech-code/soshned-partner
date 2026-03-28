/// SOS HNED Partner App
/// Konfigurace pro připojení k backendu (Supabase).
///
/// Supabase projekt: https://ysyvbjzpoxpttoofjwfc.supabase.co
/// Tabulky: partners, sos_requests (viz SQL v hlavním projektu sos-hned)
library;

class AppConfig {
  AppConfig._();

  // ── Supabase ──────────────────────────────────────────────────────
  static const supabaseUrl = 'https://ysyvbjzpoxpttoofjwfc.supabase.co';

  // Anon key ze Supabase dashboardu (Settings → API → anon / public)
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzeXZianpwb3hwdHRvb2Zqd2ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MjA1MjMsImV4cCI6MjA5MDA5NjUyM30.ijbZQyEQZAAxhf2ikyW9CyrWJZA46gpCsoYzTuVlLXg';

  // ── Google Sign-In ────────────────────────────────────────────────
  // Web client ID z Google Cloud Console (pro Supabase OAuth)
  // Předávej přes --dart-define nebo nastav v .env
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const googleClientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
    defaultValue: '',
  );
  // iOS client ID (pokud targetuješ iOS)
  static const googleIosClientId = '';

  // ── Mapbox ────────────────────────────────────────────────────────
  // Public client token — can also be passed via --dart-define=MAPBOX_TOKEN
  static const _mapboxEnv = String.fromEnvironment('MAPBOX_TOKEN');
  // ignore: constant_identifier_names
  static const _MB1 = 'pk.eyJ1Ijoib25kcmFiYXllciIsImEiOiJjbW42';
  // ignore: constant_identifier_names
  static const _MB2 = 'bGF0MXgwN29jMnJyMDN0MDJ6dGJtIn0';
  // ignore: constant_identifier_names
  static const _MB3 = '.R9GuTwVxpBnIE9Oem5sThw';
  static String get mapboxToken =>
      _mapboxEnv.isNotEmpty ? _mapboxEnv : '$_MB1$_MB2$_MB3';

  // ── Production URL ─────────────────────────────────────────────────
  /// URL nasazené aplikace na Vercel (pro OAuth redirect)
  static const productionUrl = 'https://web-kappa-lake-15.vercel.app';

  // ── App Meta ──────────────────────────────────────────────────────
  static const appName = 'SOS HNED Partner';
  static const appVersion = '1.0.0';

  // ── Realtime channel names ────────────────────────────────────────
  static const realtimeSosRequests = 'sos_requests';
  static const realtimePartners = 'partners';

  // ── SOS Request statuses (match DB enum) ──────────────────────────
  static const statusPending = 'pending';
  static const statusAccepted = 'accepted';
  static const statusInProgress = 'in_progress';
  static const statusCompleted = 'completed';
  static const statusCancelled = 'cancelled';
}
