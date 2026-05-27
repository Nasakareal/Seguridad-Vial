import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/red_apoyo.dart';

void main() {
  test('DirectorioRedApoyoPage parses API payload and groups contacts', () {
    final page = DirectorioRedApoyoPage.fromJson({
      'data': [
        {
          'id': 7,
          'region': 'Region Morelia',
          'nivel_gobierno': 'Municipal',
          'tipo_apoyo': 'Proteccion civil',
          'tipo_apoyo_label': 'Proteccion civil',
          'institucion': 'Proteccion Civil Municipal',
          'contacto': 'Juan Perez',
          'cargo': 'Director',
          'telefono': '4431234567',
          'telefono_secundario': '4437654321',
          'telefonos': ['4431234567', '4437654321'],
          'whatsapp': {
            'telefono': '524431234567',
            'url': 'https://wa.me/524431234567',
            'telefono_secundario': '524437654321',
            'url_secundaria': 'https://wa.me/524437654321',
          },
          'direccion': 'Centro',
          'municipio': 'Morelia',
          'observaciones': 'Disponible 24 horas',
          'orden': 1,
          'delegacion': {
            'id': 4,
            'clave': 'MOR',
            'nombre': 'Morelia',
            'municipio': 'Morelia',
            'es_hija': true,
            'padre': {
              'id': 1,
              'clave': 'REG',
              'nombre': 'Region Morelia',
              'municipio': 'Morelia',
            },
          },
          'destacamento': {'id': 2, 'nombre': 'Base Centro'},
          'updated_at': '2026-05-27 00:00:00',
        },
      ],
      'meta': {'count': 1, 'limit': 250},
    });

    expect(page.items, hasLength(1));
    expect(page.groupedByRegion, hasLength(1));
    expect(page.items.first.institucion, 'Proteccion Civil Municipal');
    expect(page.items.first.whatsapp.url, 'https://wa.me/524431234567');
    expect(page.items.first.territorioLabel, 'Morelia (Region Morelia)');
  });

  test('DirectorioRedApoyoMeta parses filters', () {
    final meta = DirectorioRedApoyoMeta.fromJson({
      'regiones': [
        {
          'id': 1,
          'clave': 'REG',
          'nombre': 'Region Morelia',
          'municipio': 'Morelia',
          'hijas': [
            {
              'id': 4,
              'clave': 'MOR',
              'nombre': 'Morelia',
              'municipio': 'Morelia',
            },
          ],
        },
      ],
      'niveles_gobierno': {'Federal': 'Federal'},
      'tipos_apoyo': {'Salud': 'Salud'},
    });

    expect(meta.regiones.single.hijas.single.nombre, 'Morelia');
    expect(meta.nivelesGobierno['Federal'], 'Federal');
    expect(meta.tiposApoyo['Salud'], 'Salud');
  });
}
