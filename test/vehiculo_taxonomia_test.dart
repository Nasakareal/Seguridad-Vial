import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/vehiculos/vehiculo_taxonomia.dart';

void main() {
  group('VehiculoTaxonomia', () {
    test('expone únicamente los tipos generales válidos', () {
      expect(VehiculoTaxonomia.esTipoGeneral('motocicleta'), isTrue);
      expect(VehiculoTaxonomia.esTipoGeneral('MOTOCICLETA'), isTrue);
      expect(VehiculoTaxonomia.esTipoGeneral('Scooter'), isFalse);
    });

    test('muestra la etiqueta legible del tipo general', () {
      expect(
        VehiculoTaxonomia.etiquetaTipoGeneral('motocicleta'),
        'Motocicleta',
      );
      expect(VehiculoTaxonomia.etiquetaTipoGeneral('automovil'), 'Automóvil');
      expect(
        VehiculoTaxonomia.etiquetaTipoGeneral('no especificado'),
        'No especificado',
      );
    });

    test('la taxonomía de motocicleta conserva todas sus carrocerías', () {
      expect(
        VehiculoTaxonomia.carroceriasDeTipoGeneral('motocicleta'),
        containsAll(<String>['Trabajo', 'Scooter', 'Pista', 'Naked']),
      );
    });
  });
}
