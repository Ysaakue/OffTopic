import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/core/routing/app_router.dart';
import 'package:offtopic/core/routing/app_routes.dart';

void main() {
  test('starts at the home route', () {
    final container = ProviderContainer.test();

    final router = container.read(appRouterProvider);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
  });

  test('disposes the router with the container', () {
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);

    container.dispose();

    // The route information provider is a ChangeNotifier; once disposed it
    // rejects new listeners.
    expect(
      () => router.routeInformationProvider.addListener(() {}),
      throwsFlutterError,
    );
  });
}
