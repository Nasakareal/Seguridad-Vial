import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/modulo_examen_diario.dart';

void main() {
  test('formatea la tarjeta diaria para compartir', () {
    const registro = ModuloExamenDiario(
      id: 1,
      fecha: '2026-10-05',
      moduloNombre: 'Av. Lázaro Cárdenas (Casa Cuna)',
      servicioPublico: 2,
      automovilista: 3,
      chofer: 0,
      motociclista: 1,
      permiso: 0,
      total: 6,
      hombres: 4,
      mujeres: 2,
      aprobados: 5,
      reprobados: 1,
      folios: null,
      informadoPor: 'Nombre anterior',
      createdAt: null,
      updatedAt: null,
    );

    final texto = registro.textoParaCompartir(
      nombreUsuario: 'Bertha Mijayli Alcantar Almonte',
    );

    expect(texto, contains('05/Octubre/2026'));
    expect(texto, contains('Servicio Público: 02'));
    expect(texto, contains('Automovilista: 03'));
    expect(texto, contains('Total: 06'));
    expect(texto, contains('Folios\n\nSin folios'));
    expect(
      texto,
      endsWith('INFORMA: Respetuosamente Bertha Mijayli Alcantar Almonte'),
    );
  });
}
