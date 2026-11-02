import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:offtopic/core/routing/app_routes.dart';
import 'package:offtopic/features/home/presentation/screens/home_screen.dart';
import 'package:offtopic/features/room/presentation/screens/audio_test_screen.dart';

/// The app router, disposed with the provider container.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.audioTest,
        builder: (context, state) => const AudioTestScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
