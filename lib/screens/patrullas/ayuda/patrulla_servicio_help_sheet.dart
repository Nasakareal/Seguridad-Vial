import 'package:flutter/material.dart';

class PatrullaServicioHelpSheet extends StatefulWidget {
  final int initialPage;

  const PatrullaServicioHelpSheet({super.key, this.initialPage = 0});

  @override
  State<PatrullaServicioHelpSheet> createState() =>
      _PatrullaServicioHelpSheetState();
}

class _PatrullaServicioHelpSheetState extends State<PatrullaServicioHelpSheet> {
  static const int _totalPages = 4;
  late final PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, 2);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _totalPages - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _previous() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * .9,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.local_police_outlined,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Control de patrullas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (value) => setState(() => _page = value),
              children: const [
                _HelpPage(
                  number: '1',
                  title: 'Recibe la unidad',
                  description:
                      'Antes de iniciar el turno, selecciona la patrulla que realmente se te entrega y registra las lecturas tal como aparecen en ese momento.',
                  accent: Color(0xFF0E7490),
                  illustration: _ReceptionIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.directions_car_outlined,
                      title: 'Patrulla disponible',
                      text:
                          'Elige el número económico correcto. Si no aparece, puede estar ocupada, inactiva o asignada a otra área.',
                    ),
                    _Tip(
                      icon: Icons.speed_rounded,
                      title: 'Kilometraje exacto',
                      text:
                          'Copia la lectura del tablero sin redondearla. Será la referencia para calcular lo recorrido.',
                    ),
                    _Tip(
                      icon: Icons.local_gas_station_outlined,
                      title: 'Nivel de combustible',
                      text:
                          'Mueve el control hasta aproximarlo al indicador real de la unidad.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '2',
                  title: 'Inspecciona y documenta',
                  description:
                      'Revisa la patrulla antes de aceptarla. Lo que registres protege tanto a quien entrega como a quien recibe la unidad.',
                  accent: Color(0xFF7C3AED),
                  illustration: _InspectionIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.fact_check_outlined,
                      title: 'Estado físico y mecánico',
                      text:
                          'Marca Bueno, Regular o Malo en cada elemento. Usa No aplica solamente cuando la patrulla no tenga ese equipo.',
                    ),
                    _Tip(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventario',
                      text:
                          'Apaga el interruptor de cualquier accesorio que no esté presente: refacción, gato, llave, extintor o botiquín.',
                    ),
                    _Tip(
                      icon: Icons.add_a_photo_outlined,
                      title: 'Evidencia clara',
                      text:
                          'Toma las cinco vistas con buena luz. En daños existentes describe ubicación, tamaño y condición.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '3',
                  title: 'Consulta tu servicio',
                  description:
                      'Después de confirmar la recepción, la patrulla queda vinculada a tu cuenta y se abre automáticamente la bitácora del turno.',
                  accent: Color(0xFF1D4ED8),
                  illustration: _ServiceIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.local_police_outlined,
                      title: 'Una unidad a la vez',
                      text:
                          'No podrás recibir otra patrulla mientras tengas un servicio activo.',
                    ),
                    _Tip(
                      icon: Icons.analytics_outlined,
                      title: 'Resumen del turno',
                      text:
                          'Aquí verás kilometraje inicial, combustible y los servicios asociados a tu bitácora.',
                    ),
                    _Tip(
                      icon: Icons.refresh_rounded,
                      title: 'Información actualizada',
                      text:
                          'Usa Actualizar en la barra superior si acabas de registrar actividad desde otra pantalla.',
                    ),
                  ],
                ),
                _HelpPage(
                  number: '4',
                  title: 'Entrega y cierra el turno',
                  description:
                      'Al terminar, registra el estado final. Revisa los datos antes de confirmar porque la bitácora se cerrará y la unidad volverá a estar disponible.',
                  accent: Color(0xFFB42318),
                  illustration: _DeliveryIllustration(),
                  tips: [
                    _Tip(
                      icon: Icons.speed_rounded,
                      title: 'Kilometraje final',
                      text:
                          'Debe ser igual o mayor al inicial. Captura exactamente la lectura mostrada en el tablero.',
                    ),
                    _Tip(
                      icon: Icons.report_outlined,
                      title: 'Novedades de entrega',
                      text:
                          'Anota fallas, daños, faltantes o cualquier situación ocurrida durante el servicio.',
                    ),
                    _Tip(
                      icon: Icons.history_rounded,
                      title: 'Historial',
                      text:
                          'Después del cierre podrás consultar fecha, horario, patrulla y kilómetros recorridos.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _PageIndicators(current: _page, total: _totalPages),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                if (_page > 0)
                  TextButton.icon(
                    onPressed: _previous,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  )
                else
                  const SizedBox(width: 100),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    _page == _totalPages - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    _page == _totalPages - 1 ? 'Entendido' : 'Siguiente',
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(fontSize: 15, height: 1.45)),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: .14),
                  accent.withValues(alpha: .04),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: .2)),
            ),
            child: illustration,
          ),
          const SizedBox(height: 18),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TipCard(tip: tip, accent: accent),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tip.icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  tip.text,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicators extends StatelessWidget {
  final int current;
  final int total;

  const _PageIndicators({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: index == current ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == current
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _ReceptionIllustration extends StatelessWidget {
  const _ReceptionIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            _MiniIcon(
              icon: Icons.local_police_outlined,
              color: Color(0xFF0E7490),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patrulla 01-234',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text('Unidad operativa disponible'),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: Color(0xFF16A34A)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: _MetricDemo(
                icon: Icons.speed,
                value: '48,210',
                label: 'Kilómetros',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricDemo(
                icon: Icons.local_gas_station_outlined,
                value: '75%',
                label: 'Combustible',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InspectionIllustration extends StatelessWidget {
  const _InspectionIllustration();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.car_repair_outlined, 'Carrocería', 'Bueno'),
      (Icons.tire_repair_outlined, 'Llantas', 'Regular'),
      (Icons.campaign_outlined, 'Sirena', 'Bueno'),
    ];
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(item.$1, color: const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.$3 == 'Bueno'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.$3,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PhotoDemo(label: 'Frontal'),
            _PhotoDemo(label: 'Trasera'),
            _PhotoDemo(label: 'Tablero'),
          ],
        ),
      ],
    );
  }
}

class _ServiceIllustration extends StatelessWidget {
  const _ServiceIllustration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            _MiniIcon(icon: Icons.local_police, color: Color(0xFF1D4ED8)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unidad 01-234',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text('Servicio iniciado · 08:15'),
                ],
              ),
            ),
            Chip(label: Text('ACTIVO')),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricDemo(
                icon: Icons.speed,
                value: '48,210',
                label: 'Inicio',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricDemo(
                icon: Icons.assignment_outlined,
                value: '3',
                label: 'Servicios',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryIllustration extends StatelessWidget {
  const _DeliveryIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: _MetricDemo(
                icon: Icons.speed,
                value: '48,296',
                label: 'Kilometraje final',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricDemo(
                icon: Icons.route_outlined,
                value: '86 km',
                label: 'Recorridos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFB42318),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Entregar y cerrar servicio',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(icon, color: color),
  );
}

class _MetricDemo extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricDemo({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _PhotoDemo extends StatelessWidget {
  final String label;

  const _PhotoDemo({required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 50,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF7C3AED)),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
