import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/user_note.dart';
import 'package:seguridad_vial_app/screens/notes/note_text_editing_controller.dart';

void main() {
  test('parsea una nota persistida con colores y resaltados', () {
    final note = UserNote.fromJson({
      'id': 9,
      'title': 'Pendientes',
      'content': 'Llamar a la delegación',
      'color': 'blue',
      'is_pinned': true,
      'highlights': [
        {'start': 0, 'end': 6, 'color': 'yellow'},
      ],
    });

    expect(note.id, 9);
    expect(note.color, 'blue');
    expect(note.isPinned, isTrue);
    expect(note.highlights, hasLength(1));
    expect(note.highlights.first.end, 6);
  });

  test('aplica y elimina marcatexto sobre la selección', () {
    final controller = NoteTextEditingController(text: 'texto importante');
    addTearDown(controller.dispose);

    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 16);
    expect(controller.applyHighlight('green'), isTrue);
    expect(controller.highlights, hasLength(1));
    expect(controller.highlights.single.start, 6);
    expect(controller.highlights.single.end, 16);
    expect(controller.highlights.single.color, 'green');

    controller.selection = const TextSelection(baseOffset: 8, extentOffset: 12);
    expect(controller.clearHighlight(), isTrue);
    expect(controller.highlights, hasLength(2));
    expect(controller.highlights[0].start, 6);
    expect(controller.highlights[0].end, 8);
    expect(controller.highlights[1].start, 12);
    expect(controller.highlights[1].end, 16);
  });

  test('desplaza el resaltado cuando se inserta texto antes', () {
    final controller = NoteTextEditingController(
      text: 'abcdef',
      highlights: const [NoteHighlight(start: 2, end: 5, color: 'pink')],
    );
    addTearDown(controller.dispose);

    controller.value = const TextEditingValue(
      text: 'XXabcdef',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(controller.highlights.single.start, 4);
    expect(controller.highlights.single.end, 7);
  });

  test(
    'una nota de delegaciones no comparte datos con otros modelos locales',
    () {
      final note = UserNote.fromJson({
        'id': 4,
        'title': null,
        'content': 'Privada',
        'color': 'invalido',
        'highlights': const [],
      });

      expect(note.title, isEmpty);
      expect(note.color, 'neutral');
      expect(note.content, 'Privada');
    },
  );
}
