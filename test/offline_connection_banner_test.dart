import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/network_status_service.dart';
import 'package:seguridad_vial_app/widgets/offline_connection_banner.dart';

void main() {
  tearDown(NetworkStatusService.markOnline);

  testWidgets('el aviso offline deja pasar los toques al contenido', (
    tester,
  ) async {
    var taps = 0;
    NetworkStatusService.markOffline();

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineConnectionBanner(
          child: Stack(
            children: [
              Positioned(
                top: 6,
                left: 12,
                right: 12,
                height: 48,
                child: MaterialButton(
                  onPressed: () => taps += 1,
                  child: const Text('Acción detrás del aviso'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(NetworkStatusService.defaultOfflineMessage),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(100, 30));

    expect(taps, 1);
  });
}
