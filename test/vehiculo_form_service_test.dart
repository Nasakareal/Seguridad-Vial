import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/vehiculo_form_service.dart';

void main() {
  String? validateVehicle({
    required String tipoServicio,
    required String? estadoPlacas,
  }) {
    return VehiculoFormService.validateVehiculoBeforeSubmit(
      marca: 'NISSAN',
      linea: 'VERSA',
      color: 'BLANCO',
      tipoServicio: tipoServicio,
      partesDanadas: 'NINGUNA',
      tipoGeneral: 'AUTOMOVIL',
      tipoCarroceria: 'SEDAN',
      placas: 'ABC123',
      estadoPlacas: estadoPlacas,
      serie: '',
      capacidad: '5',
      montoDanos: '0',
      modelo: '2024',
      tarjetaCirculacionNombre: '',
      aseguradora: '',
    );
  }

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

  test('servicio publico federal no exige estado de placas', () {
    expect(
      validateVehicle(
        tipoServicio: 'SERVICIO PÚBLICO FEDERAL',
        estadoPlacas: null,
      ),
      isNull,
    );
    expect(
      VehiculoFormService.estadoPlacasParaPayload(
        placas: 'ABC123',
        tipoServicio: 'SERVICIO PÚBLICO FEDERAL',
        estadoPlacas: null,
      ),
      'Federal',
    );
  });

  test('servicio no federal sigue exigiendo estado de placas', () {
    expect(
      validateVehicle(tipoServicio: 'PARTICULAR', estadoPlacas: null),
      'Si capturas placas, también debes capturar el estado de placas.',
    );
    expect(
      validateVehicle(tipoServicio: 'PARTICULAR', estadoPlacas: 'MICHOACAN'),
      isNull,
    );
  });

  test('sin placas no reutiliza el estado de placas', () {
    expect(
      VehiculoFormService.estadoPlacasParaPayload(
        placas: '',
        tipoServicio: 'PARTICULAR',
        estadoPlacas: 'MICHOACAN',
      ),
      isNull,
    );
  });

  test('normaliza teléfonos mexicanos sin depender de la lada', () {
    expect(VehiculoFormService.normalizeTelefonoMx('4434765057'), '4434765057');
    expect(VehiculoFormService.normalizeTelefonoMx('3541234567'), '3541234567');
    expect(
      VehiculoFormService.normalizeTelefonoMx('+52 354 123 4567'),
      '3541234567',
    );
    expect(
      VehiculoFormService.normalizeTelefonoMx('5213541234567'),
      '3541234567',
    );
    expect(
      VehiculoFormService.normalizeTelefonoMx('0443541234567'),
      '3541234567',
    );
    expect(
      VehiculoFormService.normalizeTelefonoMx('013541234567'),
      '3541234567',
    );
    expect(VehiculoFormService.validateTelefono('+52 354 123 4567'), isNull);
  });
}
