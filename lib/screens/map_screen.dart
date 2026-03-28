import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../config/app_config.dart';

/// Mapa — partner vidí:
///  1. Svoji polohu (modrý pin, může přetáhnout)
///  2. Ostatní online partnery (zelené piny)
///  3. Pending SOS požadavky ve své kategorii (červené piny)
///
/// Kliknutím na mapu může nastavit svoji polohu → uloží se do DB.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  List<Partner> _onlinePartners = [];
  List<SosRequest> _pendingRequests = [];
  bool _loading = true;

  LatLng? _myPosition;
  bool _savingPosition = false;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() => _loading = true);

    try {
      final partner = ref.read(partnerProfileProvider).valueOrNull;

      // Načti moji polohu z profilu
      if (partner != null && partner.lat != null && partner.lng != null) {
        _myPosition = LatLng(partner.lat!, partner.lng!);
      }

      // Načti online partnery
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
          _myPosition ??= const LatLng(50.0755, 14.4378); // Praha default
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _myPosition ??= const LatLng(50.0755, 14.4378);
          _loading = false;
        });
      }
    }
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('📍 Poloha uložena do databáze'),
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
            content: Text('Chyba při ukládání polohy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPosition = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          if (_savingPosition)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadMapData,
            tooltip: 'Obnovit data',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _myPosition ?? const LatLng(50.0755, 14.4378), // Praha
              initialZoom: 13.5,
              onTap: (tapPos, latLng) => _showSetPositionDialog(latLng),
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: isDark
                    ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxToken}'
                    : 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxToken}',
                userAgentPackageName: 'cz.soshned.partner',
                maxZoom: 19,
              ),

              // ── Moje poloha (modrý pin, draggable) ────────────
              if (_myPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPosition!,
                      width: 55,
                      height: 65,
                      child: _MyPositionPin(
                        name: partner?.jmeno ?? '?',
                        onDragEnd: _setMyPosition,
                      ),
                    ),
                  ],
                ),

              // ── Online partneři (zelené piny) ─────────────────
              MarkerLayer(
                markers: _onlinePartners
                    .where((p) =>
                        p.lat != null &&
                        p.lng != null &&
                        p.id != partner?.id) // Neukázat sebe
                    .map((p) => Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 44,
                          height: 54,
                          child: _PartnerPin(partner: p),
                        ))
                    .toList(),
              ),

              // ── SOS požadavky (červené piny) ──────────────────
              MarkerLayer(
                markers: _pendingRequests
                    .map((r) => Marker(
                          point: LatLng(r.lat, r.lng),
                          width: 50,
                          height: 60,
                          child: _SosRequestPin(request: r),
                        ))
                    .toList(),
              ),
            ],
          ),

          // ── Loading overlay ───────────────────────────────────────
          if (_loading)
            Container(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // ── Legenda ───────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            child: _MapLegend(
              isDark: isDark,
              partnerCount: _onlinePartners.length,
              requestCount: _pendingRequests.length,
            ),
          ),

          // ── Instrukce ─────────────────────────────────────────────
          if (_myPosition == null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1a1a2e)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded,
                        color: Color(0xFF3B82F6), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Klikni na mapu pro nastavení svojí polohy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── FAB: Přidat pin (centovat na Prahu) ───────────────────
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              children: [
                // Centrovat na sebe
                if (_myPosition != null)
                  FloatingActionButton.small(
                    heroTag: 'center',
                    onPressed: () {
                      _mapController.move(_myPosition!, 15);
                    },
                    backgroundColor:
                        isDark ? const Color(0xFF1a1a2e) : Colors.white,
                    child: const Icon(Icons.my_location_rounded,
                        color: Color(0xFF3B82F6), size: 20),
                  ),
                const SizedBox(height: 8),
                // Refresh
                FloatingActionButton.small(
                  heroTag: 'refresh',
                  onPressed: _loadMapData,
                  backgroundColor:
                      isDark ? const Color(0xFF1a1a2e) : Colors.white,
                  child: Icon(Icons.refresh_rounded,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSetPositionDialog(LatLng position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0c0c14) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            const Icon(Icons.location_on_rounded,
                size: 48, color: Color(0xFF3B82F6)),
            const SizedBox(height: 12),
            Text(
              'Nastavit polohu zde?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tato poloha se uloží do databáze a bude viditelná zákazníkům na mapě.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
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
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setMyPosition(position);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Potvrdit'),
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
}

// ═══════════════════════════════════════════════════════════════════
//  Pin widgety
// ═══════════════════════════════════════════════════════════════════

/// Modrý pin — moje poloha
class _MyPositionPin extends StatelessWidget {
  final String name;
  final void Function(LatLng)? onDragEnd;

  const _MyPositionPin({required this.name, this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        // Šipka dolů
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(color: const Color(0xFF3B82F6)),
        ),
      ],
    );
  }
}

/// Zelený pin — online partner
class _PartnerPin extends StatelessWidget {
  final Partner partner;

  const _PartnerPin({required this.partner});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPartnerInfo(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Center(
              child: _categoryIcon(partner.kategorie),
            ),
          ),
          CustomPaint(
            size: const Size(10, 6),
            painter: _TrianglePainter(color: const Color(0xFF22C55E)),
          ),
        ],
      ),
    );
  }

  void _showPartnerInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0c0c14) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  partner.jmeno.isNotEmpty ? partner.jmeno[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              partner.jmeno,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            if (partner.firma != null && partner.firma!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                partner.firma!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.2),
                ),
              ),
              child: Text(
                partner.kategorieLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22C55E),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 4),
                Text(
                  partner.hodnoceni.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                Text(
                  ' (${partner.pocetRecenzi} recenzí)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white30 : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on_rounded,
                    color: isDark ? Colors.white30 : Colors.grey[400],
                    size: 14),
                const SizedBox(width: 2),
                Text(
                  partner.zona,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Červený pulsující pin — SOS požadavek
class _SosRequestPin extends StatelessWidget {
  final SosRequest request;

  const _SosRequestPin({required this.request});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Center(
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(color: const Color(0xFFEF4444)),
        ),
      ],
    );
  }
}

/// Legenda
class _MapLegend extends StatelessWidget {
  final bool isDark;
  final int partnerCount;
  final int requestCount;

  const _MapLegend({
    required this.isDark,
    required this.partnerCount,
    required this.requestCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0c0c14).withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(const Color(0xFF3B82F6), 'Moje poloha'),
          const SizedBox(height: 6),
          _legendItem(const Color(0xFF22C55E),
              'Online partneři ($partnerCount)'),
          const SizedBox(height: 6),
          _legendItem(const Color(0xFFEF4444),
              'SOS požadavky ($requestCount)'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

/// Trojúhelník pod pinem (šipka)
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

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

/// Ikona podle kategorie
Widget _categoryIcon(String kategorie) {
  IconData icon;
  switch (kategorie) {
    case 'zamecnik':
      icon = Icons.key_rounded;
      break;
    case 'odtahovka':
      icon = Icons.local_shipping_rounded;
      break;
    case 'servis':
      icon = Icons.build_rounded;
      break;
    case 'instalater':
      icon = Icons.water_drop_rounded;
      break;
    default:
      icon = Icons.handyman_rounded;
  }
  return Icon(icon, color: Colors.white, size: 16);
}
