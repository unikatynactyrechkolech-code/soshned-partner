import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../config/app_config.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Mapbox Style URLs — prémiové styly (512 retina tiles)
// ═══════════════════════════════════════════════════════════════════════

class _MapboxStyles {
  static String _url(String styleId) =>
      'https://api.mapbox.com/styles/v1/mapbox/$styleId/tiles/512/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxToken}';

  /// Terén (outdoors)
  static String get terrain => _url('outdoors-v12');

  /// Satelit + popisky
  static String get satellite => _url('satellite-streets-v12');

  /// Prohlídka (streets)
  static String get streets => _url('streets-v12');

  /// Doprava (navigation)
  static String get navigation => _url('navigation-day-v1');

  /// Navigation Night (dark mode variant)
  static String get navigationNight => _url('navigation-night-v1');
}

// ═══════════════════════════════════════════════════════════════════════
//  MapScreen
// ═══════════════════════════════════════════════════════════════════════

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  List<Partner> _onlinePartners = [];
  List<SosRequest> _pendingRequests = [];
  bool _loading = true;
  String? _error;

  LatLng? _myPosition;
  bool _savingPosition = false;
  bool _placingPin = false;  // Režim umísťování špendlíku

  Timer? _refreshTimer;

  // Map style: terén, satelit, prohlídka, doprava
  String _mapStyle = 'prohlidka'; // default = streets
  bool _showStylePicker = false;

  String get _currentTileUrl {
    switch (_mapStyle) {
      case 'teren':
        return _MapboxStyles.terrain;
      case 'satelit':
        return _MapboxStyles.satellite;
      case 'prohlidka':
        return _MapboxStyles.streets;
      case 'doprava':
        return _MapboxStyles.navigation;
      default:
        return _MapboxStyles.streets;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMapData();
    // Refresh every 15 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────

  Future<void> _loadMapData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final partner = ref.read(partnerProfileProvider).valueOrNull;

      if (partner != null && partner.lat != null && partner.lng != null) {
        _myPosition = LatLng(partner.lat!, partner.lng!);
      }

      final partners = await SupabaseService.instance.getAllOnlinePartners();
      List<SosRequest> requests = [];
      if (partner != null) {
        requests = await SupabaseService.instance
            .getPendingRequests(partner.kategorie);
      }

      if (mounted) {
        setState(() {
          _onlinePartners = partners;
          _pendingRequests = requests;
          _myPosition ??= const LatLng(50.0755, 14.4378);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _myPosition ??= const LatLng(50.0755, 14.4378);
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _refreshData() async {
    try {
      final partner = ref.read(partnerProfileProvider).valueOrNull;
      final partners = await SupabaseService.instance.getAllOnlinePartners();
      List<SosRequest> requests = [];
      if (partner != null) {
        requests = await SupabaseService.instance
            .getPendingRequests(partner.kategorie);
      }
      if (mounted) {
        setState(() {
          _onlinePartners = partners;
          _pendingRequests = requests;
        });
      }
    } catch (_) {}
  }

  // ── Save my position ─────────────────────────────────────────────

  Future<void> _setMyPosition(LatLng position) async {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    if (partner == null) return;

    setState(() {
      _myPosition = position;
      _savingPosition = true;
    });

    try {
      await SupabaseService.instance.updateLocation(
        partner.id,
        position.latitude,
        position.longitude,
      );
      ref.invalidate(partnerProfileProvider);

      if (mounted) {
        setState(() => _placingPin = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('📍 Sídlo firmy uloženo — viditelná na mapě klientům'),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
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
      if (mounted) setState(() => _savingPosition = false);
    }
  }

  // ── Tile URL ──────────────────────────────────────────────────────

  String _getTileUrl(bool isDark) {
    // Použij vybraný styl, v dark mode fallback na navigation night
    if (isDark && _mapStyle == 'doprava') {
      return _MapboxStyles.navigationNight;
    }
    return _currentTileUrl;
  }

  // ═════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final tileUrl = _getTileUrl(isDark);
    final effectiveDark = _mapStyle == 'satelit' || isDark;

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ───────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _myPosition ?? const LatLng(50.0755, 14.4378),
              initialZoom: 14.0,
              maxZoom: 19,
              minZoom: 3,
              onTap: (tapPos, latLng) {
                if (_showStylePicker) {
                  setState(() => _showStylePicker = false);
                  return;
                }
                if (_placingPin) {
                  _showSetPositionDialog(latLng);
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Mapbox Premium Tiles
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'cz.soshned.partner',
                maxZoom: 19,
                tileSize: 512,
                zoomOffset: -1,
              ),

              // My position (blue)
              if (_myPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPosition!,
                      width: 60,
                      height: 72,
                      child: _MyPositionMarker(
                        name: partner?.jmeno ?? '?',
                        kategorie: partner?.kategorie,
                      ),
                    ),
                  ],
                ),

              // Online partners (emerald)
              MarkerLayer(
                markers: _onlinePartners
                    .where((p) =>
                        p.lat != null &&
                        p.lng != null &&
                        p.id != partner?.id)
                    .map((p) => Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 52,
                          height: 68,
                          child: _PartnerMarker(
                            partner: p,
                            onTap: () => _showPartnerSheet(p),
                          ),
                        ))
                    .toList(),
              ),

              // SOS requests (red)
              MarkerLayer(
                markers: _pendingRequests
                    .map((r) => Marker(
                          point: LatLng(r.lat, r.lng),
                          width: 56,
                          height: 68,
                          child: _SosMarker(request: r),
                        ))
                    .toList(),
              ),
            ],
          ),

          // ── TOP GRADIENT + CONTROLS ───────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (effectiveDark ? Colors.black : Colors.white)
                        .withOpacity(0.85),
                    (effectiveDark ? Colors.black : Colors.white)
                        .withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Title badge
                  _GlassBadge(
                    dark: effectiveDark,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded,
                            size: 16,
                            color: effectiveDark
                                ? Colors.white70
                                : Colors.grey[800]),
                        const SizedBox(width: 6),
                        Text(
                          'Mapa',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: effectiveDark
                                ? Colors.white
                                : Colors.grey[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Online count
                  _GlassBadge(
                    dark: effectiveDark,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_onlinePartners.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: effectiveDark
                                ? Colors.white
                                : Colors.grey[900],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _GlassBadge(
                      dark: effectiveDark,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 13, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text(
                            '${_pendingRequests.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_savingPosition) ...[
                    const SizedBox(width: 6),
                    const _GlassBadge(
                      dark: true,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── LOADING ───────────────────────────────────────────────
          if (_loading)
            Container(
              color: (effectiveDark ? Colors.black : Colors.white)
                  .withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(
                      'Načítám mapu…',
                      style: TextStyle(
                        color: effectiveDark ? Colors.white54 : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── ERROR ─────────────────────────────────────────────────
          if (_error != null && !_loading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chyba: $_error',
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Color(0xFFEF4444), size: 16),
                      onPressed: () => setState(() => _error = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

          // ── PLACING PIN INSTRUCTION ─────────────────────────────────
          if (_placingPin && !_loading)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: _GlassCard(
                dark: effectiveDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.touch_app_rounded,
                              color: Color(0xFF3B82F6), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '👆 Klepněte na mapu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: effectiveDark
                                      ? Colors.white
                                      : Colors.grey[900],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Klepněte kamkoliv na mapu pro umístění sídla vaší firmy.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: effectiveDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _placingPin = false),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Zrušit umísťování'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── SET PIN FAB BUTTON ────────────────────────────────────────
          if (!_placingPin && !_loading)
            Positioned(
              bottom: 32,
              left: 14,
              right: 80,
              child: GestureDetector(
                onTap: () => setState(() => _placingPin = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_location_alt_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _myPosition != null
                            ? 'Změnit sídlo firmy'
                            : 'Nastavit sídlo firmy',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── RIGHT CONTROLS (Globe + 3D, Apple Maps style) ──────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Globe button (style picker)
                GestureDetector(
                  onTap: () => setState(() => _showStylePicker = !_showStylePicker),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _showStylePicker
                          ? (effectiveDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade900.withOpacity(0.2))
                          : (effectiveDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9)),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12),
                      ],
                      border: Border.all(
                        color: _showStylePicker
                            ? (effectiveDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade900.withOpacity(0.3))
                            : (effectiveDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.15)),
                        width: _showStylePicker ? 2 : 1,
                      ),
                    ),
                    child: Icon(Icons.public_rounded,
                        size: 20,
                        color: effectiveDark ? Colors.white70 : Colors.grey[700]),
                  ),
                ),

                const SizedBox(height: 8),

                // My location
                if (_myPosition != null)
                  _MapFab(
                    dark: effectiveDark,
                    icon: Icons.my_location_rounded,
                    onTap: () => _mapController.move(_myPosition!, 15),
                  ),
                const SizedBox(height: 8),

                // Refresh
                _MapFab(
                  dark: effectiveDark,
                  icon: Icons.refresh_rounded,
                  onTap: _loadMapData,
                ),
              ],
            ),
          ),

          // ── STYLE PICKER POPOVER ──────────────────────────────────
          if (_showStylePicker)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70 + 52,
              right: 14,
              child: _StylePickerPopover(
                dark: effectiveDark,
                currentStyle: _mapStyle,
                onStyleSelected: (style) {
                  setState(() {
                    _mapStyle = style;
                    _showStylePicker = false;
                  });
                },
                onClose: () => setState(() => _showStylePicker = false),
              ),
            ),

          // ── LEGEND (bottom left) ──────────────────────────────────
          Positioned(
            bottom: 32,
            left: 14,
            child: _GlassCard(
              dark: effectiveDark,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendDot(
                      color: const Color(0xFF3B82F6),
                      label: 'Moje sídlo',
                      dark: effectiveDark),
                  const SizedBox(height: 5),
                  _LegendDot(
                      color: const Color(0xFF22C55E),
                      label: 'Online (${_onlinePartners.length})',
                      dark: effectiveDark),
                  const SizedBox(height: 5),
                  _LegendDot(
                      color: const Color(0xFFEF4444),
                      label: 'SOS (${_pendingRequests.length})',
                      dark: effectiveDark),
                ],
              ),
            ),
          ),

          // ── MY INFO CARD ──────────────────────────────────────────
          if (partner != null && !_loading && !_placingPin)
            Positioned(
              bottom: 140,
              left: 14,
              right: 80,
              child: _GlassCard(
                dark: effectiveDark,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          partner.jmeno.isNotEmpty
                              ? partner.jmeno[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.jmeno,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: effectiveDark
                                  ? Colors.white
                                  : Colors.grey[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              partner.kategorieLabel,
                              if (partner.firma != null &&
                                  partner.firma!.isNotEmpty)
                                partner.firma,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 10,
                              color: effectiveDark
                                  ? Colors.white38
                                  : Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: partner.isOnline
                            ? const Color(0xFF22C55E).withOpacity(0.15)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: partner.isOnline
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            partner.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: partner.isOnline
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Position dialog ───────────────────────────────────────────────

  void _showSetPositionDialog(LatLng position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0c0c14) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded,
                  size: 32, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 14),
            Text(
              'Nastavit sídlo firmy zde?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[500],
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sídlo firmy se uloží do databáze a bude\nviditelné zákazníkům v klientské aplikaci.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Zrušit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setMyPosition(position);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Potvrdit'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Partner detail sheet ──────────────────────────────────────────

  void _showPartnerSheet(Partner p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0c0c14) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF22C55E).withOpacity(0.2),
                  const Color(0xFF22C55E).withOpacity(0.05),
                ]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  p.jmeno.isNotEmpty ? p.jmeno[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p.jmeno,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            if (p.firma != null && p.firma!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(p.firma!,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey[500])),
            ],
            const SizedBox(height: 10),
            // Category badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _categoryIcon(p.kategorie),
                  const SizedBox(width: 6),
                  Text(
                    p.kategorieLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.star_rounded, const Color(0xFFF59E0B),
                      '${p.hodnoceni.toStringAsFixed(1)} (${p.pocetRecenzi} recenzí)', isDark),
                  const SizedBox(height: 8),
                  _infoRow(Icons.phone_outlined, const Color(0xFF3B82F6),
                      p.telefon, isDark),
                  const SizedBox(height: 8),
                  _infoRow(Icons.email_outlined, const Color(0xFF8B5CF6),
                      p.email, isDark),
                  if (p.adresa != null && p.adresa!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on_outlined,
                        const Color(0xFFEF4444), p.adresa!, isDark),
                  ],
                  const SizedBox(height: 8),
                  _infoRow(
                      Icons.pin_drop_outlined,
                      Colors.grey,
                      '${p.lat?.toStringAsFixed(4) ?? '?'}, ${p.lng?.toStringAsFixed(4) ?? '?'}',
                      isDark),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // IDs (small, visible)
            Text('ID: ${p.id}',
                style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white12 : Colors.grey[300],
                    fontFamily: 'monospace')),
            if (p.userId != null)
              Text('User: ${p.userId}',
                  style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.white12 : Colors.grey[300],
                      fontFamily: 'monospace')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey[800])),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MARKER WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _MyPositionMarker extends StatelessWidget {
  final String name;
  final String? kategorie;

  const _MyPositionMarker({required this.name, this.kategorie});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Center(
            child: kategorie != null
                ? _categoryIcon(kategorie!)
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 9),
          painter: _ArrowPainter(color: const Color(0xFF2563EB)),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Sídlo',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerMarker extends StatelessWidget {
  final Partner partner;
  final VoidCallback onTap;

  const _PartnerMarker({required this.partner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Center(child: _categoryIcon(partner.kategorie)),
          ),
          CustomPaint(
            size: const Size(12, 7),
            painter: _ArrowPainter(color: const Color(0xFF16A34A)),
          ),
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              partner.jmeno.split(' ').first,
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosMarker extends StatelessWidget {
  final SosRequest request;

  const _SosMarker({required this.request});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(0.3),
              width: 3,
            ),
          ),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Center(
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _ArrowPainter(color: const Color(0xFFDC2626)),
        ),
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withOpacity(0.9),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'SOS',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _GlassBadge extends StatelessWidget {
  final bool dark;
  final Widget child;

  const _GlassBadge({required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withOpacity(0.5)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }
}

class _GlassCard extends StatelessWidget {
  final bool dark;
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({
    required this.dark,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withOpacity(0.55)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1), blurRadius: 16),
        ],
        border: Border.all(
          color: dark
              ? Colors.white.withOpacity(0.06)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: child,
    );
  }
}

class _MapFab extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final VoidCallback onTap;

  const _MapFab({
    required this.dark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.black.withOpacity(0.6)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12), blurRadius: 12),
          ],
          border: Border.all(
            color: dark
                ? Colors.white.withOpacity(0.06)
                : Colors.grey.withOpacity(0.15),
          ),
        ),
        child: Icon(icon,
            size: 20,
            color: dark ? Colors.white70 : Colors.grey[700]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dark;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white60 : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════
//  STYLE PICKER POPOVER (Apple Maps style — Globe icon opens this)
// ═══════════════════════════════════════════════════════════════════════

class _StylePickerPopover extends StatelessWidget {
  final bool dark;
  final String currentStyle;
  final ValueChanged<String> onStyleSelected;
  final VoidCallback onClose;

  const _StylePickerPopover({
    required this.dark,
    required this.currentStyle,
    required this.onStyleSelected,
    required this.onClose,
  });

  static const _styles = [
    {'id': 'teren', 'label': 'Terén', 'desc': 'Výšky a příroda', 'icon': Icons.terrain_rounded},
    {'id': 'satelit', 'label': 'Satelit', 'desc': 'Družicové snímky', 'icon': Icons.satellite_alt_rounded},
    {'id': 'prohlidka', 'label': 'Prohlídka', 'desc': 'Ulice a POI', 'icon': Icons.map_rounded},
    {'id': 'doprava', 'label': 'Doprava', 'desc': 'Navigační styl', 'icon': Icons.directions_car_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF1a1a2e).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Text(
              'Styl mapy',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: dark ? Colors.white.withOpacity(0.3) : Colors.grey[400],
              ),
            ),
          ),
          ..._styles.map((s) {
            final active = currentStyle == s['id'];
            return GestureDetector(
              onTap: () => onStyleSelected(s['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? (dark ? Colors.white.withOpacity(0.12) : const Color(0xFFEFF6FF))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: active
                      ? Border.all(
                          color: dark
                              ? Colors.white.withOpacity(0.15)
                              : const Color(0xFFBFDBFE),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF3B82F6).withOpacity(0.2)
                            : (dark ? Colors.white.withOpacity(0.06) : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(8),
                        border: active
                            ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))
                            : null,
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        size: 16,
                        color: active
                            ? const Color(0xFF60A5FA)
                            : (dark ? Colors.white.withOpacity(0.5) : Colors.grey[500]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? (dark ? Colors.white : const Color(0xFF2563EB))
                                  : (dark ? Colors.white.withOpacity(0.6) : Colors.grey[700]),
                            ),
                          ),
                          Text(
                            s['desc'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              color: dark ? Colors.white.withOpacity(0.25) : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (active)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF60A5FA),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

Widget _categoryIcon(String kategorie) {
  IconData icon;
  switch (kategorie) {
    case 'zamecnik':
      icon = Icons.key_rounded;
    case 'odtahovka':
      icon = Icons.local_shipping_rounded;
    case 'servis':
      icon = Icons.build_rounded;
    case 'instalater':
      icon = Icons.water_drop_rounded;
    default:
      icon = Icons.handyman_rounded;
  }
  return Icon(icon, color: Colors.white, size: 16);
}
