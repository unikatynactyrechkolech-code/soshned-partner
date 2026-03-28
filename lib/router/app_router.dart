import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/complete_profile_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/map_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';

/// Notifier that triggers GoRouter refresh when auth/profile state changes
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(partnerProfileProvider, (_, __) => notifyListeners());
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isLoggedIn = SupabaseService.instance.isLoggedIn;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';
      final isCompleteProfile = location == '/complete-profile';

      // Not logged in → go to login (unless already on auth route)
      if (!isLoggedIn && !isAuthRoute) return '/login';

      // Read the profile state (may be loading, data, or error)
      final profileAsync = ref.read(partnerProfileProvider);

      // Logged in on auth route → redirect away
      if (isLoggedIn && isAuthRoute) {
        if (profileAsync.isLoading) return '/'; // Will re-redirect when profile loads
        final profile = profileAsync.valueOrNull;
        if (profile == null) return '/complete-profile';
        return '/';
      }

      // Logged in, trying to access app routes → check profile exists
      if (isLoggedIn && !isCompleteProfile && !isAuthRoute) {
        if (profileAsync.isLoading) return null; // Wait for profile to load
        final profile = profileAsync.valueOrNull;
        if (profile == null) return '/complete-profile';
      }

      // On complete-profile but already has profile → go to dashboard
      if (isLoggedIn && isCompleteProfile) {
        if (profileAsync.isLoading) return null;
        final profile = profileAsync.valueOrNull;
        if (profile != null) return '/';
      }

      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Profile Completion (after Google OAuth) ───────────────
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // ── Main (with bottom nav shell) ──────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      // ── Detail (full screen, no bottom nav) ───────────────────
      GoRoute(
        path: '/request/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RequestDetailScreen(requestId: id);
        },
      ),
    ],
  );
});

/// Shell s bottom navigation barem
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    ('/', Icons.dashboard_rounded, 'Dashboard'),
    ('/map', Icons.map_rounded, 'Mapa'),
    ('/history', Icons.history_rounded, 'Historie'),
    ('/profile', Icons.person_rounded, 'Profil'),
    ('/settings', Icons.settings_rounded, 'Nastavení'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => t.$1 == location).clamp(0, 4);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(_tabs[i].$1),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.$2),
                  label: t.$3,
                ))
            .toList(),
      ),
    );
  }
}
