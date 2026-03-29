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
import '../screens/messages_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/about_screen.dart';
import '../screens/terms_screen.dart';

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
            path: '/messages',
            builder: (context, state) => const MessagesScreen(),
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

      // ── Edit Profile (full screen) ────────────────────────────
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // ── Privacy ───────────────────────────────────────────────
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),

      // ── About ─────────────────────────────────────────────────
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),

      // ── Terms ─────────────────────────────────────────────────
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsScreen(),
      ),
    ],
  );
});

/// Shell s Instagram-style bottom navigation barem
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  // (path, outlinedIcon, filledIcon, label)
  static const _tabs = [
    ('/', Icons.home_outlined, Icons.home, 'Domů'),
    ('/map', Icons.explore_outlined, Icons.explore, 'Mapa'),
    ('/messages', Icons.chat_bubble_outline, Icons.chat_bubble, 'Zprávy'),
    ('/history', Icons.schedule_outlined, Icons.schedule, 'Historie'),
    ('/profile', Icons.person_outline, Icons.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => t.$1 == location).clamp(0, _tabs.length - 1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0a0a0a) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.$1),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? tab.$3 : tab.$2,
                            size: 26,
                            color: isActive
                                ? (isDark ? Colors.white : const Color(0xFF111827))
                                : (isDark ? Colors.white38 : Colors.grey[400]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.$4,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive
                                  ? (isDark ? Colors.white : const Color(0xFF111827))
                                  : (isDark ? Colors.white38 : Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
