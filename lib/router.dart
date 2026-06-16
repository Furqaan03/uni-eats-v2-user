import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/signup_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/cart/checkout_screen.dart';
import 'features/home/home_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/restaurant/restaurant_detail_screen.dart';
import 'features/tracking/tracking_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'shell/dashboard_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Re-created whenever auth state changes so the redirect logic re-runs.
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    // Auth guard — redirect unauthenticated users to /login.
    redirect: (context, state) {
      const publicRoutes = {'/login', '/signup'};
      final isPublic = publicRoutes.contains(state.matchedLocation);
      if (!isAuthenticated && !isPublic) return '/login';
      // Prevent authenticated users from landing back on login/signup.
      if (isAuthenticated && isPublic) return '/home';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracking',
                builder: (context, state) => const TrackingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/restaurant/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          // Sanitise: only allow alphanumeric IDs to prevent IDOR path tricks.
          if (!RegExp(r'^[a-zA-Z0-9_\-]{1,32}$').hasMatch(id)) {
            return const HomeScreen();
          }
          return RestaurantDetailScreen(restaurantId: id);
        },
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/wallet',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
    ],
  );
});
