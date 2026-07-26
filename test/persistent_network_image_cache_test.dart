import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/services/persistent_network_image_cache.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'persistent-image-cache-test-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'guarda la imagen y la recupera sin volver a consultar la red',
    () async {
      var requests = 0;
      final cache = PersistentNetworkImageCache(
        directoryProvider: () async => directory,
        client: MockClient((request) async {
          requests++;
          return http.Response.bytes(
            const <int>[0x89, 0x50, 0x4E, 0x47],
            200,
            headers: const <String, String>{'content-type': 'image/png'},
          );
        }),
      );
      const url = 'https://example.test/profile/avatar.png';

      final downloaded = await cache.download(url);
      final cached = await cache.lookup(url, maxAge: const Duration(days: 7));

      expect(requests, 1);
      expect(await downloaded.exists(), isTrue);
      expect(cached, isNotNull);
      expect(cached!.isFresh, isTrue);
      expect(await cached.file.readAsBytes(), const <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
      ]);
    },
  );

  test('conserva una copia vencida como respaldo offline', () async {
    final cache = PersistentNetworkImageCache(
      directoryProvider: () async => directory,
      client: MockClient(
        (request) async => http.Response.bytes(
          const <int>[1, 2, 3],
          200,
          headers: const <String, String>{'content-type': 'image/jpeg'},
        ),
      ),
    );
    const url = 'https://example.test/feed/photo.jpg';

    await cache.download(url);
    final stale = await cache.lookup(url, maxAge: Duration.zero);

    expect(stale, isNotNull);
    expect(stale!.isFresh, isFalse);
    expect(await stale.file.readAsBytes(), const <int>[1, 2, 3]);
  });

  test('rechaza respuestas que no son imágenes', () async {
    final cache = PersistentNetworkImageCache(
      directoryProvider: () async => directory,
      client: MockClient(
        (request) async => http.Response(
          '<html>Error</html>',
          200,
          headers: const <String, String>{'content-type': 'text/html'},
        ),
      ),
    );

    await expectLater(
      cache.download('https://example.test/not-an-image'),
      throwsA(isA<FormatException>()),
    );
  });
}
