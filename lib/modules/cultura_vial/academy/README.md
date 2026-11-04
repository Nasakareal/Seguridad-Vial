# Academia y simulador

Esta carpeta es la única fuente de la Academia Vial. Ya no es necesario editar
archivos dentro de `screens/publico`.

## Dónde modificar cada cosa

- `content/vial_question_bank.dart`: las 30 preguntas, opciones, respuesta
  correcta y explicación educativa.
- `models/vial_question.dart`: formato de una pregunta y modos Aprender,
  Practicar y Simulacro.
- `screens/academia_vial_screen.dart`: reglas, número de preguntas, tiempo,
  calificación y navegación.
- `widgets/academy_question_card.dart`: colores, iconos, tarjetas de respuesta
  y retroalimentación visual.

## Plantilla para agregar una pregunta

```dart
VialQuestion(
  'Categoría',
  '¿Texto claro de la situación?',
  [
    'Primera opción',
    'Segunda opción',
    'Tercera opción',
    'Cuarta opción',
  ],
  1, // 0=A, 1=B, 2=C, 3=D
  'Explicación breve de por qué esa decisión es la más segura.',
),
```

Cada pregunta debe tener al menos tres opciones, un índice `correct` válido y
una explicación. El modo Aprender muestra la explicación inmediatamente;
Practicar selecciona 10 preguntas al azar; Simulacro utiliza todo el banco y
oculta la respuesta hasta el final.

Después de editar el banco ejecuta:

```text
flutter test test/michoacan_al_volante_test.dart
```
