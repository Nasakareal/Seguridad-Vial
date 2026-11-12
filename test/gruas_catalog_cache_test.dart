import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/services/gruas_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_session_owner_key': 'user:catalog-test',
    });
  });

  test(
    'same operational scope reuses local catalog without another request',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return _catalogResponse([
          _grua(7, 'GRÚAS SINIESTROS', unidadIds: [1, 5]),
        ]);
      });

      await http.runWithClient(() async {
        final first = await GruasCatalogService.fetchOperativoGruas(
          operativoId: 100,
          unidadId: 5,
        );
        final second = await GruasCatalogService.fetchOperativoGruas(
          operativoId: 101,
          unidadId: 5,
        );

        expect(first.single['id'], 7);
        expect(second.single['id'], 7);
      }, () => client);

      expect(requests, 1);
    },
  );

  test(
    'an empty catalog is cached and does not query on every opening',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return _catalogResponse(const []);
      });

      await http.runWithClient(() async {
        expect(
          await GruasCatalogService.fetchOperativoGruas(
            operativoId: 200,
            unidadId: 2,
            delegacionId: 30,
          ),
          isEmpty,
        );
        expect(
          await GruasCatalogService.fetchOperativoGruas(
            operativoId: 201,
            unidadId: 2,
            delegacionId: 30,
          ),
          isEmpty,
        );
      }, () => client);

      expect(requests, 1);
    },
  );

  test(
    'manual synchronization refreshes and replaces the local catalog',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return _catalogResponse([
          _grua(
            requests == 1 ? 1 : 2,
            requests == 1 ? 'GRÚA ANTERIOR' : 'GRÚA NUEVA',
            unidadIds: [1, 5],
          ),
        ]);
      });

      await http.runWithClient(() async {
        final first = await GruasCatalogService.fetchOperativoGruas(
          operativoId: 300,
          unidadId: 5,
        );
        final refreshed = await GruasCatalogService.fetchOperativoGruas(
          operativoId: 300,
          unidadId: 5,
          forceRefresh: true,
        );
        final localAgain = await GruasCatalogService.fetchOperativoGruas(
          operativoId: 301,
          unidadId: 5,
        );

        expect(first.single['nombre'], 'GRÚA ANTERIOR');
        expect(refreshed.single['nombre'], 'GRÚA NUEVA');
        expect(localAgain.single['nombre'], 'GRÚA NUEVA');
      }, () => client);

      expect(requests, 2);
    },
  );

  test(
    'delegation catalog keeps only gruas assigned to that delegation',
    () async {
      final client = MockClient((request) async {
        return _catalogResponse([
          _grua(10, 'GRÚAS URUAPAN', delegacionIds: [30]),
          _grua(11, 'GRÚAS MORELIA', delegacionIds: [15]),
        ]);
      });

      await http.runWithClient(() async {
        final gruas = await GruasCatalogService.fetchOperativoGruas(
          operativoId: 400,
          unidadId: 2,
          delegacionId: 30,
        );

        expect(gruas.map((item) => item['id']), [10]);
      }, () => client);
    },
  );
}

http.Response _catalogResponse(List<Map<String, dynamic>> data) {
  return http.Response(
    jsonEncode(<String, dynamic>{'data': data}),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> _grua(
  int id,
  String nombre, {
  List<int> unidadIds = const [],
  List<int> delegacionIds = const [],
}) {
  return <String, dynamic>{
    'id': id,
    'nombre': nombre,
    'unidades': [
      for (final unidadId in unidadIds)
        <String, dynamic>{'id': unidadId, 'nombre': 'UNIDAD $unidadId'},
    ],
    'delegaciones': [
      for (final delegacionId in delegacionIds)
        <String, dynamic>{
          'id': delegacionId,
          'nombre': 'DELEGACIÓN $delegacionId',
        },
    ],
  };
}
