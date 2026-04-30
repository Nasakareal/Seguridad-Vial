import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/constancias_manejo_service.dart';

void main() {
  test('extracts constancia QR token from public validation URL', () {
    const token = 'e7796a3b-bdaf-4550-8629-d1b4d4952327';
    final parsed = ConstanciasManejoService.parseQrToken(
      'https://seguridadvial-mich.com/constancias-manejo/validar/$token',
    );

    expect(parsed, token);
  });

  test('accepts a raw constancia QR token', () {
    const token = 'e7796a3b-bdaf-4550-8629-d1b4d4952327';

    expect(ConstanciasManejoService.parseQrToken(token), token);
  });
}
