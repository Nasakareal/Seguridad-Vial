import 'package:flutter/material.dart';

enum ConduceLegalidadHelpMode { nuevaCaptura, formulario, impresion }

class ConduceLegalidadWorkflowHelpSheet extends StatefulWidget {
  final int initialPage;
  final ConduceLegalidadHelpMode mode;

  const ConduceLegalidadWorkflowHelpSheet({
    super.key,
    this.initialPage = 0,
    this.mode = ConduceLegalidadHelpMode.formulario,
  });

  @override
  State<ConduceLegalidadWorkflowHelpSheet> createState() =>
      _ConduceLegalidadWorkflowHelpSheetState();
}

class _ConduceLegalidadWorkflowHelpSheetState
    extends State<ConduceLegalidadWorkflowHelpSheet>
    with SingleTickerProviderStateMixin {
  late final PageController _pages;
  late final AnimationController _demo;
  late final List<_HelpTopic> _visibleTopics;
  late int _page;

  static const _topics = <_HelpTopic>[
    _HelpTopic(
      title: 'Crear una nueva captura',
      intro:
          'Dentro de un operativo, el botón inferior derecho abre el formulario de una intervención nueva.',
      icon: Icons.add_circle_outline,
      color: Color(0xFF2563EB),
      action: 'Agregar captura',
      actionIcon: Icons.add,
      steps: <String>[
        'Confirma que estás dentro del operativo correcto.',
        'Busca Agregar captura en la esquina inferior derecha.',
        'Tócalo para abrir el formulario de la nueva intervención.',
      ],
      tip:
          'Los iconos de cada tarjeta pertenecen a una captura existente. Para crear otra usa siempre el botón inferior derecho.',
      demoIcons: <IconData>[Icons.list_alt_outlined, Icons.add_circle],
      highlightedIcon: 1,
    ),
    _HelpTopic(
      title: 'Fundamento y datos',
      intro:
          'Esta parte identifica por qué se realizó la intervención. La ubicación ya viene del operativo.',
      icon: Icons.gavel_outlined,
      color: Color(0xFF6D28D9),
      action: 'Añadir otro fundamento',
      actionIcon: Icons.add,
      steps: <String>[
        'Selecciona el Fundamento del operativo que corresponda a la conducta observada.',
        'Si existen varias infracciones, pulsa Añadir otro fundamento y selecciona cada una por separado.',
        'La Narrativa se completa sola con los fundamentos. Revísala y corrígela únicamente si hace falta.',
        'Confirma que la ubicación general mostrada corresponda al punto del operativo; esa misma se usará en el IPH y el ticket.',
      ],
      tip:
          'Debajo de cada fundamento se muestra su texto legal y la sanción. Revísalos antes de continuar.',
      demoIcons: <IconData>[
        Icons.gavel_outlined,
        Icons.notes_outlined,
        Icons.auto_awesome_outlined,
      ],
      highlightedIcon: 0,
    ),
    _HelpTopic(
      title: 'Vehículo y tarjeta',
      intro:
          'Agrega el vehículo intervenido y verifica sus datos antes de incorporarlo a la captura.',
      icon: Icons.qr_code_scanner,
      color: Color(0xFF0F766E),
      action: 'Escanear tarjeta',
      actionIcon: Icons.qr_code_scanner,
      steps: <String>[
        'En Vehículos pulsa Agregar. Cada alimentación admite como máximo un vehículo.',
        'Puedes tocar Escanear tarjeta y centrar el QR para proponer los datos automáticamente.',
        'Revisa Tipo de vehículo, Carrocería, Marca, Color, placas, estado y número de serie.',
        'Completa Grúa, Corralón, aseguradora y antecedente solamente cuando correspondan.',
        'Pulsa Agregar vehículo; después aparecerá en la sección Vehículos y podrás editarlo o quitarlo.',
      ],
      tip:
          'El escaneo no guarda por sí solo. Corrige cualquier dato faltante o incorrecto antes de pulsar Agregar vehículo.',
      demoIcons: <IconData>[
        Icons.two_wheeler_outlined,
        Icons.qr_code_scanner,
        Icons.fact_check_outlined,
      ],
      highlightedIcon: 1,
    ),
    _HelpTopic(
      title: 'Persona y licencia',
      intro:
          'Registra a la persona relacionada con la intervención y los datos reales de su licencia.',
      icon: Icons.badge_outlined,
      color: Color(0xFF0369A1),
      action: 'Escanear licencia',
      actionIcon: Icons.qr_code_scanner,
      steps: <String>[
        'En Personas pulsa Agregar y selecciona el tipo de persona que estás registrando.',
        'Toca Escanear licencia, permite la cámara y mantén el QR completo dentro del recuadro.',
        'Verifica nombre, sexo, número y tipo de licencia contra el documento físico.',
        'Marca Licencia permanente sólo cuando el documento lo indique; de lo contrario selecciona su vigencia.',
        'Pulsa Agregar persona y confirma que aparezca en la lista antes de guardar la captura.',
      ],
      tip:
          'Si el QR no contiene algún dato, complétalo manualmente. El escaneo sólo propone información.',
      demoIcons: <IconData>[
        Icons.person_add_alt_1_outlined,
        Icons.qr_code_scanner,
        Icons.badge_outlined,
      ],
      highlightedIcon: 1,
    ),
    _HelpTopic(
      title: 'Evidencias y guardado',
      intro:
          'Finaliza la alimentación con las evidencias necesarias y una última revisión.',
      icon: Icons.save_outlined,
      color: Color(0xFF15803D),
      action: 'Guardar captura',
      actionIcon: Icons.save_outlined,
      steps: <String>[
        'En Fotos usa Cámara para tomar una evidencia o Galería para elegir una existente.',
        'Revisa las miniaturas y quita cualquier imagen equivocada antes de guardar.',
        'Escribe en Observaciones únicamente información adicional que no pertenezca a la Narrativa.',
        'Confirma fundamentos, vehículo, personas y fotos; después pulsa Guardar captura.',
        'Espera el mensaje de confirmación antes de cerrar o regresar a otra pantalla.',
      ],
      tip:
          'Si no hay internet, la aplicación conserva el borrador o deja el envío pendiente para sincronizarlo cuando vuelva la conexión.',
      demoIcons: <IconData>[
        Icons.photo_camera_outlined,
        Icons.notes_outlined,
        Icons.save_outlined,
      ],
      highlightedIcon: 2,
    ),
    _HelpTopic(
      title: 'Imprimir la boleta',
      intro:
          'Abre la boleta de la captura y envíala a una impresora térmica emparejada.',
      icon: Icons.print_outlined,
      color: Color(0xFFB45309),
      action: 'Imprimir',
      actionIcon: Icons.print_outlined,
      steps: <String>[
        'Toca el icono de boleta en la tarjeta de la captura.',
        'Revisa la vista previa y pulsa el icono Imprimir.',
        'Elige papel de 58 mm u 80 mm.',
        'Selecciona la impresora Bluetooth previamente emparejada.',
      ],
      tip:
          'Usa Prueba Bluetooth para confirmar conexión y ancho del papel antes del operativo.',
      demoIcons: <IconData>[
        Icons.receipt_long_outlined,
        Icons.print_outlined,
        Icons.bluetooth_connected,
      ],
      highlightedIcon: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _visibleTopics = switch (widget.mode) {
      ConduceLegalidadHelpMode.nuevaCaptura => <_HelpTopic>[_topics[0]],
      ConduceLegalidadHelpMode.formulario => _topics.sublist(1, 5),
      ConduceLegalidadHelpMode.impresion => <_HelpTopic>[_topics[5]],
    };
    _page = widget.initialPage.clamp(0, _visibleTopics.length - 1);
    _pages = PageController(initialPage: _page);
    _demo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pages.dispose();
    _demo.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _visibleTopics.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  void _previous() {
    if (_page == 0) return;
    _pages.previousPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = _visibleTopics[_page];
    return Container(
      height: MediaQuery.sizeOf(context).height * .92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Padding(
              key: ValueKey(_page),
              padding: const EdgeInsets.fromLTRB(20, 16, 10, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: topic.color.withValues(alpha: .12),
                    child: Icon(topic.icon, color: topic.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar ayuda',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _visibleTopics.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) =>
                  _HelpPage(topic: _visibleTopics[index], animation: _demo),
            ),
          ),
          _PageDots(
            current: _page,
            count: _visibleTopics.length,
            color: topic.color,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: _page == 0
                      ? null
                      : TextButton.icon(
                          onPressed: _previous,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                        ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: topic.color),
                  onPressed: _next,
                  icon: Icon(
                    _page == _visibleTopics.length - 1
                        ? Icons.check
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    _page == _visibleTopics.length - 1
                        ? 'Entendido'
                        : 'Siguiente',
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

class _HelpPage extends StatelessWidget {
  final _HelpTopic topic;
  final Animation<double> animation;

  const _HelpPage({required this.topic, required this.animation});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topic.intro, style: const TextStyle(fontSize: 15, height: 1.45)),
          const SizedBox(height: 18),
          _AnimatedDemo(topic: topic, animation: animation),
          const SizedBox(height: 20),
          for (var index = 0; index < topic.steps.length; index++) ...[
            _StepRow(
              number: index + 1,
              text: topic.steps[index],
              color: topic.color,
            ),
            if (index != topic.steps.length - 1) const SizedBox(height: 11),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: topic.color.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: topic.color.withValues(alpha: .22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: topic.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(topic.tip, style: const TextStyle(height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDemo extends StatelessWidget {
  final _HelpTopic topic;
  final Animation<double> animation;

  const _AnimatedDemo({required this.topic, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final pulse = Curves.easeInOut.transform(animation.value);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topic.color.withValues(alpha: .11), Colors.white],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: topic.color.withValues(alpha: .20)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: topic.color.withValues(alpha: .10),
                          child: Icon(topic.icon, size: 20, color: topic.color),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DemoLine(width: 112),
                              SizedBox(height: 7),
                              _DemoLine(width: 170, light: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (
                          var index = 0;
                          index < topic.demoIcons.length;
                          index++
                        ) ...[
                          AnimatedScale(
                            duration: const Duration(milliseconds: 120),
                            scale: index == topic.highlightedIcon
                                ? 1 + (pulse * .14)
                                : 1,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: index == topic.highlightedIcon
                                    ? topic.color.withValues(
                                        alpha: .10 + pulse * .08,
                                      )
                                    : Colors.grey.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: index == topic.highlightedIcon
                                      ? topic.color
                                      : Colors.grey.shade200,
                                  width: index == topic.highlightedIcon ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                topic.demoIcons[index],
                                color: index == topic.highlightedIcon
                                    ? topic.color
                                    : Colors.grey.shade600,
                                size: 21,
                              ),
                            ),
                          ),
                          if (index != topic.demoIcons.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Transform.translate(
                offset: Offset(0, -3 * pulse),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(topic.actionIcon, color: topic.color),
                    const SizedBox(width: 8),
                    Text(
                      topic.action,
                      style: TextStyle(
                        color: topic.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DemoLine extends StatelessWidget {
  final double width;
  final bool light;

  const _DemoLine({required this.width, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: light ? 7 : 10,
      decoration: BoxDecoration(
        color: light ? Colors.grey.shade200 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final Color color;

  const _StepRow({
    required this.number,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: color,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: const TextStyle(height: 1.35)),
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  final int current;
  final int count;
  final Color color;

  const _PageDots({
    required this.current,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: selected ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}

class _HelpTopic {
  final String title;
  final String intro;
  final IconData icon;
  final Color color;
  final String action;
  final IconData actionIcon;
  final List<String> steps;
  final String tip;
  final List<IconData> demoIcons;
  final int highlightedIcon;

  const _HelpTopic({
    required this.title,
    required this.intro,
    required this.icon,
    required this.color,
    required this.action,
    required this.actionIcon,
    required this.steps,
    required this.tip,
    required this.demoIcons,
    required this.highlightedIcon,
  });
}
