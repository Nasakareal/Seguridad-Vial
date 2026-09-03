import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/app/routes.dart';
import 'package:seguridad_vial_app/models/traffic_controller.dart';
import 'package:seguridad_vial_app/screens/control_semaforico/control_semaforico_screen.dart';
import 'package:seguridad_vial_app/screens/semaforos_talleres/semaforos_talleres_screen.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:seguridad_vial_app/services/traffic_controller_access.dart';
import 'package:seguridad_vial_app/services/traffic_controller_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('talleres y prioridad de campo son módulos y rutas independientes', () {
    expect(AppRoutes.controlSemaforico, '/control-semaforico');
    expect(AppRoutes.semaforosTalleres, '/semaforos-talleres');
    expect(AppRoutes.semaforosTalleres, isNot(AppRoutes.controlSemaforico));
    expect(const ControlSemaforicoScreen(), isA<ControlSemaforicoScreen>());
    expect(const SemaforosTalleresScreen(), isA<SemaforosTalleresScreen>());
  });

  group('acceso al controlador semafórico', () {
    test('admite unidad 6 y superadmin', () {
      expect(
        TrafficControllerAccess.isAllowed(
          unitId: AuthService.unidadCulturaVialId,
          roleId: 8,
          roleName: 'operador',
        ),
        isTrue,
      );
      expect(
        TrafficControllerAccess.isAllowed(
          unitId: 2,
          roleId: 1,
          roleName: 'superadmin',
        ),
        isTrue,
      );
    });

    test('rechaza otras unidades aunque tengan acceso operativo general', () {
      expect(
        TrafficControllerAccess.isAllowed(
          unitId: AuthService.unidadSeguridadVialId,
          roleId: 2,
          roleName: 'administrador',
        ),
        isFalse,
      );
    });
  });

  group('plan seguro', () {
    test('calcula el ciclo y valida límites', () {
      const plan = TrafficControllerPlan(
        greenASeconds: 25,
        yellowASeconds: 3,
        allRedAToBSeconds: 2,
        greenBSeconds: 35,
        yellowBSeconds: 4,
        allRedBToASeconds: 2,
      );
      expect(plan.cycleSeconds, 71);
      expect(plan.validate(), isNull);
    });

    test('no admite omitir todo rojo ni ámbar demasiado corto', () {
      const noAllRed = TrafficControllerPlan(allRedAToBSeconds: 0);
      const shortYellow = TrafficControllerPlan(yellowBSeconds: 1);
      expect(noAllRed.validate(), contains('todo rojo'));
      expect(shortYellow.validate(), contains('ámbar'));
    });
  });

  test('interpreta estado de los dos nodos', () {
    final status = TrafficControllerStatus.fromJson({
      'running': true,
      'peer_linked': true,
      'emergency_all_red': false,
      'mode': 'Ciclo sincronizado',
      'phase': 'A verde',
      'remaining_seconds': 17,
      'sequence': 9,
      'plan': const TrafficControllerPlan().toJson(),
      'node_a': {'online': true, 'color': 'green', 'remaining_seconds': 17},
      'node_b': {'online': true, 'color': 'red', 'remaining_seconds': 17},
    });
    expect(status.nodeA.color, TrafficLightColor.green);
    expect(status.nodeB.color, TrafficLightColor.red);
    expect(status.peerLinked, isTrue);
  });

  test('admite estado autónomo del maestro sin secundario', () {
    final status = TrafficControllerStatus.fromJson({
      'running': true,
      'peer_linked': false,
      'emergency_all_red': false,
      'mode': 'Ciclo autónomo del maestro',
      'phase': 'A verde',
      'remaining_seconds': 17,
      'sequence': 10,
      'plan': const TrafficControllerPlan().toJson(),
      'node_a': {'online': true, 'color': 'green', 'remaining_seconds': 17},
      'node_b': {'online': false, 'color': 'red', 'remaining_seconds': 17},
    });
    expect(status.running, isTrue);
    expect(status.peerLinked, isFalse);
    expect(status.nodeA.online, isTrue);
    expect(status.nodeB.online, isFalse);
  });

  test('envía iniciar aunque el secundario no esté enlazado', () async {
    SharedPreferences.setMockInitialValues({});
    final service = TrafficControllerService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://192.168.4.1/api/start');
        return http.Response(
          '{"running":true,"peer_linked":false,'
          '"emergency_all_red":false,'
          '"mode":"Ciclo autónomo del maestro"}',
          200,
        );
      }),
    );

    final status = await service.start();

    expect(status.running, isTrue);
    expect(status.peerLinked, isFalse);
    service.dispose();
  });
}
