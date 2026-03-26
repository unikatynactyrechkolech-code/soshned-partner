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

  // DŮLEŽITÉ: Nahraď tímto svým anon key ze Supabase dashboardu
  // Settings → API → Project API keys → anon / public
  static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ── Google Sign-In ────────────────────────────────────────────────
  // Web client ID z Google Cloud Console (pro Supabase OAuth)
  static const googleWebClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID';
  // iOS client ID (pokud targetuješ iOS)
  static const googleIosClientId = 'YOUR_GOOGLE_IOS_CLIENT_ID';

  // ── Mapbox ────────────────────────────────────────────────────────
  // Token se načítá z .env nebo --dart-define při buildu:
  // flutter run --dart-define=MAPBOX_TOKEN=pk.xxx
  static const mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

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
