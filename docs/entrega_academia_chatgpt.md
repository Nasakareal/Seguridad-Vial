# Paquete para mejorar Michoacán al Volante

Este ZIP contiene únicamente el módulo educativo Flutter y los archivos
necesarios para entenderlo. No contiene backend operativo, credenciales,
bases de datos ni información personal.

## Objetivo sugerido

Mejorar Academia Vial y Simulador con la misma calidad visual e interactiva de
los tres juegos existentes, conservando las rutas, el audio, el progreso y las
interfaces públicas actuales.

## Archivos principales

- `lib/modules/cultura_vial/academy/content/vial_question_bank.dart`: banco de
  preguntas editable.
- `lib/modules/cultura_vial/academy/widgets/academy_question_card.dart`:
  presentación visual de preguntas y respuestas.
- `lib/modules/cultura_vial/academy/screens/academia_vial_screen.dart`: lógica
  de Aprender, Practicar y Simulacro.
- `lib/modules/cultura_vial/games/`: juegos terminados que sirven como
  referencia de calidad.
- `assets/cultura_vial/`: recursos visuales de los juegos.
- `test/michoacan_al_volante_test.dart`: validaciones del banco y los modos.

## Contratos que deben conservarse

- `AcademiaVialScreen(initialMode: AcademiaMode...)`.
- `AcademiaMode.aprender`, `practicar` y `simulacro`.
- `vialQuestionBank` como lista de `VialQuestion`.
- Registro de resultados mediante `CulturaVialProgressService`.
- Música limitada al módulo mediante `CulturaVialAudioService`.
- El simulacro no debe revelar respuestas durante el examen.
- No modificar autenticación ni módulos institucionales.

## Validación

Ejecutar:

```text
flutter analyze lib/modules/cultura_vial
flutter test test/michoacan_al_volante_test.dart test/cultura_vial_games_test.dart
```

Estado al generar el paquete: analizador sin errores y 12 pruebas aprobadas.
