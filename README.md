# SOS HNED Partner — Flutter Web Dashboard

Partnerská aplikace pro poskytovatele havarijních služeb.  
Flutter Web → build → deploy na Vercel.

---

## 📋 Předpoklady

1. **Flutter SDK** ≥ 3.2.0 nainstalovaný ([flutter.dev/get-started](https://flutter.dev/docs/get-started/install))
2. **Supabase projekt** s tabulkami `partners` a `sos_requests` (viz SQL níže)
3. **Vercel účet** pro deploy ([vercel.com](https://vercel.com))

---

## 🔑 API klíče — co potřebuješ nastavit

### 1. Supabase Anon Key

1. Jdi na [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Otevři svůj projekt (`ysyvbjzpoxpttoofjwfc`)
3. **Settings → API → Project API keys**
4. Zkopíruj `anon / public` klíč
5. Vlož do `lib/config/app_config.dart`:
   ```dart
   static const supabaseAnonKey = 'tvůj-anon-key-sem';
   ```

### 2. Google OAuth (volitelné, pro Google Sign-In)

1. Jdi na [Google Cloud Console](https://console.cloud.google.com)
2. Vytvoř OAuth 2.0 Client ID (Web Application)
3. Authorized redirect URIs: `https://ysyvbjzpoxpttoofjwfc.supabase.co/auth/v1/callback`
4. Vlož Client ID do `lib/config/app_config.dart`:
   ```dart
   static const googleWebClientId = 'tvůj-client-id.apps.googleusercontent.com';
   ```
5. V Supabase: **Authentication → Providers → Google** → zapni + vlož Client ID a Secret

### 3. Mapbox Token (pro mapu v detailu požadavku)

Token se předává při buildu přes `--dart-define`:
```bash
flutter build web --dart-define=MAPBOX_TOKEN=pk.tvůj-token
```

---

## 🚀 Build pro web

```bash
# Přejdi do složky projektu
cd sos-hned-partner

# Stáhni závislosti
flutter pub get

# Build web (release)
flutter build web --release --dart-define=MAPBOX_TOKEN=pk.tvůj-mapbox-token

# Výstup je ve složce: build/web/
```

Build vytvoří složku `build/web/` se vším co potřebuješ pro deploy.

---

## 🌐 Deploy na Vercel (ručně)

### Varianta A: Přes Vercel CLI

```bash
# Nainstaluj Vercel CLI (pokud nemáš)
npm i -g vercel

# Deploy build/web složky
cd build/web
vercel --prod
```

Při prvním spuštění:
- **Set up and deploy?** → `Y`
- **Which scope?** → vyber svůj účet
- **Link to existing project?** → `N` (vytvoří nový)
- **Project name?** → `soshned-partner` (nebo co chceš)
- **In which directory is your code?** → `.` (aktuální)
- **Override settings?** → `N`

### Varianta B: Přes Vercel Dashboard (drag & drop)

1. Jdi na [vercel.com/new](https://vercel.com/new)
2. Klikni dole na **"Browse"** (nebo přetáhni složku)
3. Nahraj celou složku `build/web/`
4. **Framework Preset:** `Other`
5. **Output Directory:** `.` (root)
6. Deploy!

### Varianta C: Přes GitHub + GitHub Actions

1. Pushni celý `sos-hned-partner/` na GitHub jako separátní repo
2. Přidej GitHub Actions workflow (viz níže)
3. V Vercel: **New Project → Import Git Repository**

⚠️ **POZOR:** Vercel nemá Flutter ve svém build prostředí! Musíš buildnout přes GitHub Actions a jen deployovat výstup.

---

## 🔄 GitHub Actions + Vercel (automatický deploy)

Vytvoř `.github/workflows/deploy.yml`:

```yaml
name: Deploy Flutter Web to Vercel

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'

      - run: flutter pub get

      - run: flutter build web --release --dart-define=MAPBOX_TOKEN=${{ secrets.MAPBOX_TOKEN }}

      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: build/web
          vercel-args: '--prod'
```

GitHub Secrets potřebuješ nastavit:
- `VERCEL_TOKEN` — z Vercel dashboard → Settings → Tokens
- `VERCEL_ORG_ID` — z `.vercel/project.json` po prvním `vercel` příkazu
- `VERCEL_PROJECT_ID` — z `.vercel/project.json`
- `MAPBOX_TOKEN` — tvůj Mapbox token

---

## 📁 Struktura projektu

```
sos-hned-partner/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # MaterialApp.router setup
│   ├── config/
│   │   └── app_config.dart       # ← SEM VLOŽ API KLÍČE
│   ├── models/
│   │   ├── partner.dart          # Partner model (1:1 Supabase tabulka)
│   │   └── sos_request.dart      # SOS Request model
│   ├── providers/
│   │   ├── auth_provider.dart    # Riverpod auth + data providers
│   │   └── theme_provider.dart   # Dark/light mode
│   ├── router/
│   │   └── app_router.dart       # GoRouter s auth guardem
│   ├── screens/
│   │   ├── login_screen.dart     # Google Sign-In
│   │   ├── register_screen.dart  # Registrace partnera
│   │   ├── dashboard_screen.dart # Hlavní dashboard (realtime SOS)
│   │   ├── request_detail_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── settings_screen.dart
│   │   └── history_screen.dart
│   ├── services/
│   │   └── supabase_service.dart # CRUD + auth + realtime
│   ├── theme/
│   │   └── app_theme.dart        # Material 3 light/dark (Google Fonts)
│   └── widgets/
│       ├── request_card.dart     # SOS request card
│       └── status_badge.dart     # Status badge
├── web/
│   ├── index.html                # Flutter Web entry
│   ├── manifest.json             # PWA manifest
│   └── icons/                    # App ikony (přidej své)
├── vercel.json                   # SPA rewrite pravidla pro Vercel
├── pubspec.yaml
└── README.md                     # Tento soubor
```

---

## 🗄️ Supabase tabulky (SQL)

Pokud jsi je ještě nevytvořil, spusť v SQL Editoru v Supabase:

```sql
-- Tabulka partnerů (poskytovatelé služeb)
CREATE TABLE partners (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  jmeno TEXT NOT NULL,
  firma TEXT,
  telefon TEXT NOT NULL,
  email TEXT NOT NULL,
  kategorie TEXT NOT NULL CHECK (kategorie IN ('zamecnik', 'odtahovka', 'servis', 'instalater')),
  adresa TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  zona TEXT DEFAULT 'Praha',
  hodnoceni DOUBLE PRECISION DEFAULT 0.0,
  pocet_recenzi INTEGER DEFAULT 0,
  is_online BOOLEAN DEFAULT false,
  foto_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Tabulka SOS požadavků
CREATE TABLE sos_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES auth.users(id),
  kategorie TEXT NOT NULL CHECK (kategorie IN ('zamecnik', 'odtahovka', 'servis', 'instalater')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled')),
  adresa TEXT,
  popis TEXT,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  accepted_by UUID REFERENCES partners(id),
  accepted_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexy
CREATE INDEX idx_partners_kategorie ON partners(kategorie);
CREATE INDEX idx_partners_is_online ON partners(is_online);
CREATE INDEX idx_sos_requests_status ON sos_requests(status);
CREATE INDEX idx_sos_requests_kategorie ON sos_requests(kategorie);
CREATE INDEX idx_sos_requests_accepted_by ON sos_requests(accepted_by);

-- Zapni Realtime pro sos_requests
ALTER PUBLICATION supabase_realtime ADD TABLE sos_requests;

-- RLS (Row Level Security)
ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_requests ENABLE ROW LEVEL SECURITY;

-- Partner vidí a upravuje pouze svůj profil
CREATE POLICY "Partner reads own profile" ON partners
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Partner updates own profile" ON partners
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Partner inserts own profile" ON partners
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- SOS požadavky — partner vidí pending (svá kategorie) + přijaté
CREATE POLICY "Partner reads pending requests" ON sos_requests
  FOR SELECT USING (
    status = 'pending'
    OR accepted_by IN (SELECT id FROM partners WHERE user_id = auth.uid())
  );

CREATE POLICY "Partner accepts request" ON sos_requests
  FOR UPDATE USING (
    status = 'pending'
    OR accepted_by IN (SELECT id FROM partners WHERE user_id = auth.uid())
  );
```

---

## ⚡ Quick Start (TL;DR)

```bash
# 1. Otevři projekt
cd sos-hned-partner

# 2. Nastav API klíče v lib/config/app_config.dart
#    - supabaseAnonKey  (POVINNÉ)
#    - googleWebClientId (volitelné)

# 3. Stáhni deps
flutter pub get

# 4. Spusť lokálně (dev)
flutter run -d chrome --dart-define=MAPBOX_TOKEN=pk.tvůj-token

# 5. Build pro produkci
flutter build web --release --dart-define=MAPBOX_TOKEN=pk.tvůj-token

# 6. Deploy na Vercel
cd build/web && vercel --prod
```

---

## 🔗 Souvisejicí projekty

| Projekt | Popis | Repo |
|---------|-------|------|
| **SOS HNED Web** | Hlavní zákaznická PWA (Next.js) | [GitHub](https://github.com/unikatynactyrechkolech-code/soshned) |
| **SOS HNED Partner** | Tento projekt — partnerský dashboard (Flutter Web) | — |

---

*SOS HNED © 2026*
