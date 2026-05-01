import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/location_consent_screen.dart';
import 'package:seguridad_vial_app/screens/login_screen.dart';
import 'package:seguridad_vial_app/screens/welcome_screen.dart';

void main() {
  Future<void> pumpOnCompactPhone(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(320, 520),
    double textScale = 1.7,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;

    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, appChild) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: appChild ?? const SizedBox.shrink(),
          );
        },
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('welcome keeps the login button above small phone chrome', (
    tester,
  ) async {
    await pumpOnCompactPhone(tester, const WelcomeScreen());

    final loginButton = find.widgetWithText(ElevatedButton, 'Iniciar Sesión');
    expect(loginButton, findsOneWidget);
    expect(tester.takeException(), isNull);

    final buttonRect = tester.getRect(loginButton);
    expect(buttonRect.top, greaterThanOrEqualTo(0));
    expect(
      buttonRect.bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });

  testWidgets('login form scrolls on compact phones with large text', (
    tester,
  ) async {
    await pumpOnCompactPhone(tester, const LoginScreen());

    final accessButton = find.text('Acceder');
    expect(accessButton, findsOneWidget);
    await tester.ensureVisible(accessButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('location consent actions adapt on compact phones', (
    tester,
  ) async {
    await pumpOnCompactPhone(
      tester,
      const LocationConsentScreen(next: SizedBox.shrink()),
    );

    final acceptButton = find.text('Aceptar y continuar');
    expect(acceptButton, findsOneWidget);
    await tester.ensureVisible(acceptButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
