import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/actividad_fomento.dart';
import '../../../widgets/normalized_integer_input_formatter.dart';

class FomentoCulturaVialPanel extends StatelessWidget {
  final List<ActividadFomentoPrograma> programas;
  final int? programaId;
  final ValueChanged<int?> onProgramaChanged;
  final String? nivelEducativo;
  final ValueChanged<String?> onNivelEducativoChanged;
  final String? sector;
  final ValueChanged<String?> onSectorChanged;
  final Map<String, TextEditingController> countControllers;
  final TextEditingController totalController;
  final ValueChanged<String> onCountChanged;

  const FomentoCulturaVialPanel({
    super.key,
    required this.programas,
    required this.programaId,
    required this.onProgramaChanged,
    required this.nivelEducativo,
    required this.onNivelEducativoChanged,
    required this.sector,
    required this.onSectorChanged,
    required this.countControllers,
    required this.totalController,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validProgramaId = programas.any((item) => item.id == programaId)
        ? programaId
        : null;
    final validNivel = _validOrFallback(
      nivelEducativo,
      ActividadFomentoDetalle.nivelesEducativos,
    );
    final validSector = _validOrFallback(
      sector,
      ActividadFomentoDetalle.sectores,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.school_rounded, color: Colors.indigo.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Datos estadísticos de Fomento a la Cultura Vial',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: validProgramaId,
          items: [
            DropdownMenuItem<int>(
              value: null,
              child: Text(
                programas.isEmpty
                    ? 'Sin programas para esta subcategoría'
                    : 'Seleccione...',
              ),
            ),
            ...programas.map(
              (programa) => DropdownMenuItem<int>(
                value: programa.id,
                child: Text(programa.nombre),
              ),
            ),
          ],
          onChanged: programas.isEmpty ? null : onProgramaChanged,
          decoration: _dec(
            'Programa / taller / campaña',
            helperText: programas.isEmpty
                ? null
                : '${programas.length} opción(es) disponibles para la subcategoría seleccionada.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: validNivel,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Seleccione...'),
                  ),
                  ..._optionsWithFallback(
                    nivelEducativo,
                    ActividadFomentoDetalle.nivelesEducativos,
                  ).map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  ),
                ],
                onChanged: onNivelEducativoChanged,
                decoration: _dec('Nivel educativo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: validSector,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Seleccione...'),
                  ),
                  ..._optionsWithFallback(
                    sector,
                    ActividadFomentoDetalle.sectores,
                  ).map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  ),
                ],
                onChanged: onSectorChanged,
                decoration: _dec('Sector'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680
                ? 4
                : (constraints.maxWidth >= 420 ? 2 : 1);
            final spacing = 10.0;
            final itemWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: 12,
              children: [
                ...ActividadFomentoDetalle.numericFields.map((field) {
                  return SizedBox(
                    width: itemWidth,
                    child: TextField(
                      controller: countControllers[field.key],
                      keyboardType: TextInputType.number,
                      inputFormatters: const <TextInputFormatter>[
                        NormalizedIntegerInputFormatter(
                          max: ActividadFomentoDetalle.maxCount,
                        ),
                      ],
                      onChanged: onCountChanged,
                      decoration: _dec(field.label, hintText: '0'),
                    ),
                  );
                }),
                SizedBox(
                  width: itemWidth,
                  child: TextField(
                    controller: totalController,
                    readOnly: true,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Total población atendida', hintText: '0'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static InputDecoration _dec(
    String label, {
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static String? _validOrFallback(String? value, List<String> options) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return null;
    if (options.contains(clean)) return clean;
    return clean;
  }

  static List<String> _optionsWithFallback(
    String? selected,
    List<String> options,
  ) {
    final clean = (selected ?? '').trim();
    if (clean.isEmpty || options.contains(clean)) return options;
    return <String>[...options, clean];
  }
}
