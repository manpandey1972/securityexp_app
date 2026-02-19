import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Wraps a widget in a MaterialApp for testing
Widget buildTestableWidget(
  Widget child, {
  ThemeData? theme,
  Size? size,
}) {
  final widget = MaterialApp(
    home: Scaffold(body: child),
    theme: theme ?? ThemeData.dark(),
  );

  if (size != null) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: widget,
    );
  }

  return widget;
}

/// Wraps a widget in a MaterialApp with a Dialog route
Widget buildTestableDialog(Widget dialog) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          // Immediately show dialog on build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (_) => dialog,
            );
          });
          return const SizedBox.shrink();
        },
      ),
    ),
    theme: ThemeData.dark(),
  );
}

/// Resets the GetIt service locator for widget tests
Future<void> resetServiceLocator() async {
  final sl = GetIt.instance;
  await sl.reset();
}

/// Registers a mock in the GetIt service locator
void registerMock<T extends Object>(T mock) {
  final sl = GetIt.instance;
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(mock);
}
