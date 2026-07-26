import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_boleta_screen.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_module.dart';

void main() {
  ConduceLegalidadOperativo operativo(String tipo) {
    return ConduceLegalidadOperativo(
      id: 11,
      nombre: tipo == 'alcoholimetria'
          ? 'Operativo Alcoholimetría'
          : 'Operativo conduce con legalidad',
      tipoOperativo: tipo,
      estado: 'activo',
      totalCapturas: 1,
      misCapturas: 1,
    );
  }

  test('el ticket de alcoholimetría se identifica como prevención', () {
    final item = operativo('alcoholimetria');

    expect(item.ticketOperativoTitle, 'OPERATIVO PREVENCIÓN DE ACCIDENTES');
    expect(item.ticketFolioPrefix, 'PA');
    expect(item.ticketOperativoTitle, isNot(contains('ALCOHOL')));
    expect(item.ticketOperativoTitle, isNot(contains('CONDUCE')));
  });

  test('el ticket de Conduce con Legalidad conserva su identidad', () {
    final item = operativo('conduce_legalidad');

    expect(item.ticketOperativoTitle, 'OPERATIVO CONDUCE CON LEGALIDAD');
    expect(item.ticketFolioPrefix, 'CL');
    expect(item.ticketOperativoTitle, isNot(contains('PREVENCIÓN')));
  });

  test('fecha y hora caben juntas en el ancho legible de 58 mm', () {
    final writer = ThermalTicketRowFormatter(width: 32);

    writer.pairRow('Fecha', '2026-07-25', 'Hora', '21:30');

    final line = writer.toString().trim();
    expect(line, contains('Fecha: 2026-07-25'));
    expect(line, contains('Hora: 21:30'));
    expect(line.split('\n'), hasLength(1));
  });

  test('una fila larga cae de forma segura a dos renglones', () {
    final writer = ThermalTicketRowFormatter(width: 32);

    writer.pairRow('Placas/permiso', 'ABC-123-A', 'Estado placas', 'Michoacán');

    expect(writer.toString().trim().split('\n').length, greaterThan(1));
  });

  test('la salida térmica reemplaza acentos y símbolos por ASCII', () {
    final writer = ThermalTicketRowFormatter(width: 48);

    writer.line('PREVENCIÓN ÁÉÍÓÚ Ü Ñ ¿acción! 20°');

    final output = writer.toString().trim();
    expect(output, 'PREVENCION AEIOU U N ?accion! 20 grados');
    expect(output.codeUnits.every((byte) => byte <= 0x7F), isTrue);
  });
}
