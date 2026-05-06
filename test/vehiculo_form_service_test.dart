import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/vehiculo_form_service.dart';

void main() {
  test('tipo servicio placa only accepts the closed catalog', () {
    expect(VehiculoFormService.tiposServicioPlaca, const <String>[
      'PARTICULAR',
      'SERVICIO PÚBLICO ESTATAL',
      'SERVICIO PÚBLICO FEDERAL',
      'OFICIAL',
    ]);

    expect(VehiculoFormService.validateTipoServicioPlaca('PARTICULAR'), isNull);
    expect(
      VehiculoFormService.validateTipoServicioPlaca('SERVICIO PÚBLICO ESTATAL'),
      isNull,
    );
    expect(
      VehiculoFormService.validateTipoServicioPlaca('SERVICIO PÚBLICO FEDERAL'),
      isNull,
    );
    expect(VehiculoFormService.validateTipoServicioPlaca('OFICIAL'), isNull);
    expect(VehiculoFormService.validateTipoServicioPlaca('PÚBLICO'), isNotNull);
  });

  test('tipo servicio placa normalizes legacy and QR values', () {
    expect(
      VehiculoFormService.normalizeTipoServicioPlaca('publico federal'),
      'SERVICIO PÚBLICO FEDERAL',
    );
    expect(
      VehiculoFormService.normalizeTipoServicioPlaca('PUBLICO'),
      'SERVICIO PÚBLICO ESTATAL',
    );
    expect(
      VehiculoFormService.normalizeTipoServicioPlaca('privado'),
      'PARTICULAR',
    );
    expect(
      VehiculoFormService.normalizeTipoServicioPlaca('gobierno'),
      'OFICIAL',
    );
  });
}
