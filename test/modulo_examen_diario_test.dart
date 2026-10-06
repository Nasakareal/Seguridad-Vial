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

  test(
    'conserva la estructura completa aunque todos los conteos sean cero',
    () {
      const registro = ModuloExamenDiario(
        id: 0,
        fecha: '2026-10-05',
        moduloNombre: 'Av. Lázaro Cárdenas (Casa Cuna)',
        servicioPublico: 0,
        automovilista: 0,
        chofer: 0,
        motociclista: 0,
        permiso: 0,
        total: 0,
        hombres: 0,
        mujeres: 0,
        aprobados: 0,
        reprobados: 0,
        folios: null,
        informadoPor: 'Bertha Mijayli Alcantar Almonte',
        createdAt: null,
        updatedAt: null,
      );

      expect(
        registro.textoParaCompartir(),
        '''GUARDIA CIVIL SEGURIDAD VIAL ESTATAL

MÓDULO DE LICENCIA
Av. Lázaro Cárdenas (Casa Cuna)

RESULTADOS DE EXÁMENES REALIZADOS

05/Octubre/2026

Servicio Público: 00
Automovilista: 00
Chófer: 00
Motociclista: 00
Permiso: 00

Hombre: 00
Mujeres: 00

Aprobado: 00
Reprobados: 00

Total: 00

Folios

Sin folios

INFORMA: Respetuosamente Bertha Mijayli Alcantar Almonte''',
      );
    },
  );
}
