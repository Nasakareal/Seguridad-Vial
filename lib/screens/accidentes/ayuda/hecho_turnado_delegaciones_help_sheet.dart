import 'package:flutter/material.dart';

class HechoTurnadoDelegacionesHelpSheet extends StatefulWidget {
  final int initialPage;

  const HechoTurnadoDelegacionesHelpSheet({super.key, this.initialPage = 0});

  @override
  State<HechoTurnadoDelegacionesHelpSheet> createState() =>
      _HechoTurnadoDelegacionesHelpSheetState();
}

class _HechoTurnadoDelegacionesHelpSheetState
    extends State<HechoTurnadoDelegacionesHelpSheet> {
  static const int _totalPages = 7;
  static const Color _blue = Color(0xFF1457D9);
  static const Color _violet = Color(0xFF6D28D9);

  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _totalPages - 1);
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _totalPages - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * .92,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Header(
            current: _page + 1,
            total: _totalPages,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (value) => setState(() => _page = value),
              children: const [
                _HelpPage(
                  number: '1',
                  title: 'Encuentra el hecho',
                  description:
                      'Localiza el hecho que vas a turnar. Puedes buscarlo con la lupa o abrir el listado de hechos y filtrar la fecha en que ocurrió.',
                  accent: _blue,
                  illustration: _FindHechoIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.search_rounded,
                      title: 'Búsqueda rápida',
                      text:
                          'Usa la lupa si conoces la placa, el conductor o algún dato del hecho.',
                    ),
                    _Tip(
                      icon: Icons.calendar_month_outlined,
                      title: 'Búsqueda por fecha',
                      text:
                          'En el listado, elige la fecha correcta y confirma el folio antes de continuar.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '2',
                  title: 'Abre la edición',
                  description:
                      'Cuando encuentres el registro correcto, toca el lápiz de Editar. Verifica una vez más el folio y la ubicación para no modificar otro hecho.',
                  accent: Color(0xFF0E7490),
                  illustration: _EditHechoIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.edit_outlined,
                      title: 'Busca el lápiz',
                      text:
                          'Está en la tarjeta del hecho y también en la barra superior de su vista de detalle.',
                    ),
                    _Tip(
                      icon: Icons.verified_outlined,
                      title: 'Confirma el registro',
                      text:
                          'Revisa folio, fecha y lugar antes de cambiar su situación.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '3',
                  title: 'Cámbialo a TURNADO',
                  description:
                      'En Editar hecho, baja hasta el final del formulario. Abre el campo Situación y cambia PENDIENTE por TURNADO.',
                  accent: _violet,
                  illustration: _SituationIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.swipe_up_alt_rounded,
                      title: 'Está al final',
                      text:
                          'Desliza hacia abajo; el campo Situación aparece poco antes del botón Guardar cambios.',
                    ),
                    _Tip(
                      icon: Icons.account_tree_outlined,
                      title: 'Este orden es importante',
                      text:
                          'La puesta vinculada se habilita únicamente después de guardar el hecho como TURNADO.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '4',
                  title: 'Indica qué entregarás al MP',
                  description:
                      'Al elegir TURNADO aparecen Vehículos MP y Personas MP. Escribe las cantidades reales que pondrás a disposición del Ministerio Público.',
                  accent: Color(0xFFB45309),
                  illustration: _MpCountsIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.warning_amber_rounded,
                      title: 'No dejes ambos en cero',
                      text:
                          'Un hecho turnado debe indicar al menos una persona o un vehículo puesto a disposición.',
                    ),
                    _Tip(
                      icon: Icons.rule_rounded,
                      title: 'Captura cantidades, no nombres',
                      text:
                          'Aquí solo van los totales. Más adelante seleccionarás los registros específicos.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '5',
                  title: 'Guarda y crea la puesta',
                  description:
                      'Toca Guardar cambios. Cuando termine, aparecerá la opción Crear puesta vinculada al hecho; tócala para continuar.',
                  accent: Color(0xFF047857),
                  illustration: _LinkedPuestaIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.save_outlined,
                      title: 'Primero guarda',
                      text:
                          'No salgas de la pantalla mientras se actualiza el hecho. Espera el mensaje de confirmación.',
                    ),
                    _Tip(
                      icon: Icons.link_rounded,
                      title: 'Entra desde el hecho',
                      text:
                          'Usa el botón de puesta vinculada para que folio, lugar, fecha y demás datos se precarguen.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '6',
                  title: 'Adjunta el expediente',
                  description:
                      'En Crear Puesta a Disposición revisa los datos precargados. En Archivo PDF toca Elegir y selecciona la puesta escaneada.',
                  accent: Color(0xFFBE123C),
                  illustration: _FilesIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'La puesta va en Archivo PDF',
                      text:
                          'Adjunta un PDF legible de hasta 50 MB. El nombre del archivo aparecerá junto al botón.',
                    ),
                    _Tip(
                      icon: Icons.add_a_photo_outlined,
                      title: 'Fotos y narrativa',
                      text:
                          'Las fotos se agregan en Fotos de la puesta. Completa Narrativa u Observaciones cuando sea necesario.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '7',
                  title: 'Vincula y registra',
                  description:
                      'En Datos ya capturados del hecho marca los vehículos y conductores que realmente se turnan. Revisa todo y toca Registrar.',
                  accent: Color(0xFF4338CA),
                  illustration: _RegisterIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.checklist_rounded,
                      title: 'Selecciona solo lo turnado',
                      text:
                          'Cada marca copia ese vehículo o conductor a la puesta; no selecciones a quien no se entregará al MP.',
                    ),
                    _Tip(
                      icon: Icons.task_alt_rounded,
                      title: 'Última revisión',
                      text:
                          'Comprueba PDF, cantidades, selección y datos de autoridad. Al finalizar verás “Puesta registrada”.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Footer(
            current: _page,
            total: _totalPages,
            onPrevious: _previous,
            onNext: _next,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onClose;

  const _Header({
    required this.current,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF123B86), Color(0xFF4F2AA3)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 12, 14),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .48),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cómo poner un hecho turnado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'PROCESO PARA DELEGACIONES',
                        style: TextStyle(
                          color: Color(0xFFDDE7FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Paso $current de $total',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$current/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar ayuda',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpPage extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Color accent;
  final Widget illustration;
  final List<_Tip> tips;

  const _HelpPage({
    required this.number,
    required this.title,
    required this.description,
    required this.accent,
    required this.illustration,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: .24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF4B5565),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _IllustrationFrame(accent: accent, child: illustration),
          const SizedBox(height: 16),
          for (var i = 0; i < tips.length; i++) ...[
            _TipCard(tip: tips[i], accent: accent),
            if (i != tips.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _IllustrationFrame extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _IllustrationFrame({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18233A).withValues(alpha: .07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Tip {
  final IconData icon;
  final String title;
  final String text;

  const _Tip({required this.icon, required this.title, required this.text});
}

class _TipCard extends StatelessWidget {
  final _Tip tip;
  final Color accent;

  const _TipCard({required this.tip, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tip.icon, color: accent, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  tip.text,
                  style: const TextStyle(
                    color: Color(0xFF536071),
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _Footer({
    required this.current,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = current == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (index) {
                final active = index == current;
                final completed = index < current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: active ? 25 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF4F2AA3)
                        : completed
                        ? const Color(0xFF9B7DE1)
                        : const Color(0xFFD8DDEA),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (current > 0)
                  TextButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Anterior'),
                  )
                else
                  const SizedBox(width: 102),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isLast
                        ? const Color(0xFF047857)
                        : const Color(0xFF4F2AA3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onNext,
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  ),
                  label: Text(isLast ? 'Entendido' : 'Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FindHechoIllustration extends StatelessWidget {
  const _FindHechoIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MockAppBar(
          title: 'Hechos',
          actions: [Icons.search, Icons.event],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MockField(
                icon: Icons.calendar_today_outlined,
                label: 'Fecha',
                value: '18/09/2026',
                highlighted: true,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: _MockField(
                icon: Icons.filter_alt_outlined,
                label: 'Estado',
                value: 'Pendiente',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _MockHechoCard(showEdit: false),
      ],
    );
  }
}

class _EditHechoIllustration extends StatelessWidget {
  const _EditHechoIllustration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MockAppBar(title: 'Hechos', actions: [Icons.search]),
        SizedBox(height: 12),
        _MockHechoCard(showEdit: true),
        SizedBox(height: 10),
        _Callout(icon: Icons.touch_app_outlined, text: 'Toca el lápiz'),
      ],
    );
  }
}

class _SituationIllustration extends StatelessWidget {
  const _SituationIllustration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MockAppBar(title: 'Editar Hecho'),
        SizedBox(height: 14),
        Text('Final del formulario', style: _sectionLabel),
        SizedBox(height: 8),
        _MockField(
          icon: Icons.swap_horiz_rounded,
          label: 'Situación *',
          value: 'TURNADO',
          highlighted: true,
          trailing: Icons.arrow_drop_down,
        ),
        SizedBox(height: 9),
        _StatusChange(),
      ],
    );
  }
}

class _MpCountsIllustration extends StatelessWidget {
  const _MpCountsIllustration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MockField(
                icon: Icons.directions_car_outlined,
                label: 'Vehículos MP *',
                value: '1',
                highlighted: true,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MockField(
                icon: Icons.people_alt_outlined,
                label: 'Personas MP *',
                value: '0',
                highlighted: true,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _EquationHint(),
      ],
    );
  }
}

class _LinkedPuestaIllustration extends StatelessWidget {
  const _LinkedPuestaIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ActionButton(
          icon: Icons.save_outlined,
          label: 'Guardar cambios',
          filled: true,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'DESPUÉS DE GUARDAR',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 10),
        const _ActionButton(
          icon: Icons.assignment_ind_outlined,
          label: 'Crear puesta vinculada al hecho',
          emphasized: true,
        ),
      ],
    );
  }
}

class _FilesIllustration extends StatelessWidget {
  const _FilesIllustration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MockAppBar(title: 'Crear Puesta a Disposición'),
        SizedBox(height: 13),
        Text('Archivo PDF', style: _sectionLabel),
        SizedBox(height: 8),
        _FileRow(
          icon: Icons.picture_as_pdf_outlined,
          name: 'puesta_escaneada.pdf',
          action: 'Elegir',
          highlighted: true,
        ),
        SizedBox(height: 12),
        Text('Fotos de la puesta', style: _sectionLabel),
        SizedBox(height: 8),
        _FileRow(
          icon: Icons.add_a_photo_outlined,
          name: 'Sin fotos seleccionadas',
          action: 'Agregar',
        ),
        SizedBox(height: 12),
        _MockField(
          icon: Icons.notes_rounded,
          label: 'Narrativa',
          value: 'Agrega detalles si es necesario',
        ),
      ],
    );
  }
}

class _RegisterIllustration extends StatelessWidget {
  const _RegisterIllustration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Datos ya capturados del hecho', style: _sectionLabel),
        SizedBox(height: 5),
        Text(
          'Selecciona lo que se va a turnar para copiarlo a esta puesta.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
        SizedBox(height: 10),
        _CheckRow(
          title: 'Vehículo 1 · ABC-123-A',
          subtitle: 'Copiar como vehículo de la puesta',
          checked: true,
        ),
        _CheckRow(
          title: 'Conductor · JUAN PÉREZ',
          subtitle: 'Copiar como persona de la puesta',
          checked: false,
        ),
        SizedBox(height: 12),
        _ActionButton(
          icon: Icons.check_circle_outline,
          label: 'Registrar',
          filled: true,
          green: true,
        ),
      ],
    );
  }
}

const TextStyle _sectionLabel = TextStyle(
  color: Color(0xFF202939),
  fontWeight: FontWeight.w900,
  fontSize: 13,
);

class _MockAppBar extends StatelessWidget {
  final String title;
  final List<IconData> actions;

  const _MockAppBar({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_back, size: 19, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final icon in actions) ...[
            const SizedBox(width: 10),
            Icon(icon, size: 19, color: Colors.white),
          ],
        ],
      ),
    );
  }
}

class _MockField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;
  final IconData? trailing;

  const _MockField({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? const Color(0xFF6D28D9)
        : const Color(0xFFD3D8E2);
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF7F2FF) : const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: highlighted ? 1.7 : 1),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: highlighted ? color : const Color(0xFF667085),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlighted
                        ? const Color(0xFF4C1D95)
                        : const Color(0xFF202939),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, color: color),
        ],
      ),
    );
  }
}

class _MockHechoCard extends StatelessWidget {
  final bool showEdit;

  const _MockHechoCard({required this.showEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E0E8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_car, color: Color(0xFF45556C)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folio: MOR-2026-01842',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text('Fecha: 18/09/2026 14:30', style: TextStyle(fontSize: 12)),
                Text('Ubicación: MORELIA', style: TextStyle(fontSize: 12)),
                Text('Situación: PENDIENTE', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: showEdit ? const Color(0xFFEDE4FF) : Colors.transparent,
              shape: BoxShape.circle,
              border: showEdit
                  ? Border.all(color: const Color(0xFF8B5CF6))
                  : null,
            ),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {},
              tooltip: 'Editar',
              icon: Icon(
                Icons.edit,
                color: showEdit
                    ? const Color(0xFF6D28D9)
                    : const Color(0xFF667085),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Callout({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, color: const Color(0xFF6D28D9), size: 20),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6D28D9),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.arrow_upward_rounded,
          color: Color(0xFF6D28D9),
          size: 20,
        ),
      ],
    );
  }
}

class _StatusChange extends StatelessWidget {
  const _StatusChange();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StatusPill(label: 'PENDIENTE', color: Color(0xFFB45309)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded, color: Colors.grey.shade500),
        ),
        const _StatusPill(label: 'TURNADO', color: Color(0xFF6D28D9)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EquationHint extends StatelessWidget {
  const _EquationHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Vehículos MP + Personas MP  >  0',
              style: TextStyle(
                color: Color(0xFF8A3F08),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool emphasized;
  final bool green;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.filled = false,
    this.emphasized = false,
    this.green = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = green
        ? const Color(0xFF047857)
        : emphasized
        ? const Color(0xFF6D28D9)
        : const Color(0xFF1457D9);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color, width: emphasized ? 1.8 : 1),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .2),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: filled ? Colors.white : color, size: 21),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String action;
  final bool highlighted;

  const _FileRow({
    required this.icon,
    required this.name,
    required this.action,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? const Color(0xFFBE123C)
        : const Color(0xFF45556C);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF1F3) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFF3A8B8)
              : const Color(0xFFD8DDE5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            child: Text(
              action,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;

  const _CheckRow({
    required this.title,
    required this.subtitle,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFF1EEFF) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box_rounded : Icons.check_box_outline_blank,
            color: checked ? const Color(0xFF4F2AA3) : const Color(0xFF98A2B3),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
