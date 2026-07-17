import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/reconstructor_transito_project.dart';

void main() {
  group('ReconstructorProject', () {
    test('conserva el esquema JSON compatible con el backend', () {
      final original = ReconstructorProject.demo();
      final json = original.toJson();
      final restored = ReconstructorProject.fromJson(json);

      expect(json['version'], 1);
      expect((json['scene'] as Map)['roads'], isA<List<dynamic>>());
      expect(json['actors'], isA<List<dynamic>>());
      expect(json['events'], isA<List<dynamic>>());
      expect(restored.metadata.name, original.metadata.name);
      expect(restored.roads.length, 2);
      expect(restored.actors.length, 2);
      expect(restored.events.any((event) => event.code == 'PMC'), isTrue);
    });

    test('interpola la posición y el ángulo entre fotogramas', () {
      final actor = ReconstructorActor(
        id: 'actor_test',
        type: 'automovil',
        name: 'Vehículo',
        color: 0xFFEF4444,
        keyframes: <ReconstructorKeyframe>[
          ReconstructorKeyframe(time: 0, x: 0, y: 0, rotation: 170),
          ReconstructorKeyframe(time: 10, x: 100, y: 50, rotation: -170),
        ],
      );

      final middle = actor.positionAt(5)!;

      expect(middle.x, 50);
      expect(middle.y, 25);
      expect(middle.rotation.abs(), 180);
    });

    test('normaliza límites y carriles de doble sentido al importar', () {
      final project = ReconstructorProject.fromJson(<String, dynamic>{
        'metadata': <String, dynamic>{'duration': 500, 'pixelsPerMeter': 1},
        'scene': <String, dynamic>{
          'roads': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'curve',
              'direction': 'two_way',
              'lanes': 3,
              'surface': 'cobblestone',
            },
          ],
        },
      });

      expect(project.metadata.duration, 120);
      expect(project.metadata.pixelsPerMeter, 2);
      expect(project.roads.single.lanes, 4);
      expect(project.roads.single.surface, 'cobblestone');
      expect(project.roads.single.type, 'curve');
    });
  });
}
