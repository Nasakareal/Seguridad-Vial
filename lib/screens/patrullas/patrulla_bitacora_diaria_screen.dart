import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/patrulla_servicio_service.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/safe_network_image.dart';

class PatrullaBitacoraDiariaScreen extends StatefulWidget {
  const PatrullaBitacoraDiariaScreen({super.key});

  @override
  State<PatrullaBitacoraDiariaScreen> createState() =>
      _PatrullaBitacoraDiariaScreenState();
}

class _PatrullaBitacoraDiariaScreenState
    extends State<PatrullaBitacoraDiariaScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _loading = true;
  bool _forbidden = false;
  String? _error;
  Map<String, dynamic> _meta = const <String, dynamic>{};
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      if (!await AuthService.canViewDailyPatrolLog()) {
        if (!mounted) return;
        setState(() {
          _forbidden = true;
          _loading = false;
        });
        return;
      }

      final response = await PatrullaServicioService.bitacoraDiaria(_date);
      final raw = response['data'];
      if (!mounted) return;
      setState(() {
        _forbidden = false;
        _meta = _map(response['meta']);
        _items = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const <Map<String, dynamic>>[];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'Selecciona el día de la bitácora',
      cancelText: 'Cancelar',
      confirmText: 'Consultar',
    );
    if (selected == null || DateUtils.isSameDay(selected, _date)) return;
    setState(() => _date = DateUtils.dateOnly(selected));
    await _load();
  }

  Future<void> _moveDate(int days) async {
    final target = DateUtils.dateOnly(_date.add(Duration(days: days)));
    if (target.isAfter(DateUtils.dateOnly(DateTime.now()))) return;
    setState(() => _date = target);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('Bitácora diaria'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _forbidden
          ? const _MessageState(
              icon: Icons.lock_outline_rounded,
              title: 'Consulta no disponible',
              message:
                  'La bitácora general está reservada para supervisión. Tu servicio continúa disponible en el menú de patrullas.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        date: _date,
                        loading: _loading,
                        canGoForward: !DateUtils.isSameDay(
                          _date,
                          DateTime.now(),
                        ),
                        onPrevious: () => _moveDate(-1),
                        onNext: () => _moveDate(1),
                        onPickDate: _pickDate,
                      ),
                    ),
                  ),
                  if (_loading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: scheme.primary),
                      ),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(message: _error!, onRetry: _load),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      sliver: SliverToBoxAdapter(child: _Summary(meta: _meta)),
                    ),
                    if (_items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.event_busy_outlined,
                          title: 'Sin movimientos',
                          message:
                              'No hay entregas ni servicios de patrulla registrados en este día.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverList.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) =>
                              _DailyLogCard(item: _items[index]),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime date;
  final bool loading;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  const _Header({
    required this.date,
    required this.loading,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0F4C5C);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C5C), Color(0xFF087E8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operación del día',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Entrega, recepción y trabajo de cada unidad',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _DateArrow(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Día anterior',
                onPressed: loading ? null : onPrevious,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .15),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: loading ? null : onPickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _friendlyDate(date),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _DateArrow(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Día siguiente',
                onPressed: loading || !canGoForward ? null : onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _DateArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .15),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white38,
    ),
    icon: Icon(icon),
  );
}

class _Summary extends StatelessWidget {
  final Map<String, dynamic> meta;

  const _Summary({required this.meta});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _SummaryItem(
          icon: Icons.local_police_outlined,
          value: '${_int(meta['total_bitacoras']) ?? 0}',
          label: 'Unidades',
          color: const Color(0xFF0E7490),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: _SummaryItem(
          icon: Icons.route_outlined,
          value: '${_int(meta['total_servicios']) ?? 0}',
          label: 'Servicios',
          color: const Color(0xFF7C3AED),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: _SummaryItem(
          icon: Icons.pending_actions_outlined,
          value: '${_int(meta['abiertas']) ?? 0}',
          label: 'En curso',
          color: const Color(0xFFD97706),
        ),
      ),
    ],
  );
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .12)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _DailyLogCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _DailyLogCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final patrol = _map(item['patrulla']);
    final log = _map(item['bitacora']);
    final handoff = _map(item['entrega_recepcion']);
    final finalHandoff = _map(item['entrega_final']);
    final totals = _map(item['totales']);
    final activities = _list(item['actividades']);
    final incidents = _list(item['hechos']);
    final open = _text(log['estatus']).toLowerCase() == 'abierta';
    final color = open ? const Color(0xFFD97706) : const Color(0xFF16803B);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: .16)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: const Icon(Icons.directions_car_filled_outlined),
        ),
        title: Text(
          'Patrulla ${_text(patrol['numero_economico'], 'S/N')}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_text(log['capturado_por_nombre'], 'Sin responsable')}\n'
            '${_shortTime(log['hora_inicio'])}–${open ? 'en curso' : _shortTime(log['hora_fin'])}',
          ),
        ),
        trailing: _StatusBadge(open: open),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.route_rounded,
                label: '${log['kilometros_recorridos'] ?? 0} km',
              ),
              _InfoChip(
                icon: Icons.assignment_outlined,
                label: '${_int(totals['servicios']) ?? 0} servicios',
              ),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: _text(_map(log['turno'])['nombre'], 'Sin turno'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.swap_horiz_rounded,
            label: 'Entrega y recepción',
          ),
          const SizedBox(height: 8),
          _HandoffPanel(handoff: handoff, finalHandoff: finalHandoff, log: log),
          const SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.timeline_rounded,
            label: 'Trabajo registrado',
          ),
          const SizedBox(height: 8),
          _WorkTimeline(activities: activities, incidents: incidents),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool open;

  const _StatusBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? const Color(0xFFD97706) : const Color(0xFF16803B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        open ? 'EN CURSO' : 'CERRADA',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF475569)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: const Color(0xFF0F4C5C)),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

class _HandoffPanel extends StatelessWidget {
  final Map<String, dynamic> handoff;
  final Map<String, dynamic> finalHandoff;
  final Map<String, dynamic> log;

  const _HandoffPanel({
    required this.handoff,
    required this.finalHandoff,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    if (handoff.isEmpty && finalHandoff.isEmpty) {
      return const _SoftPanel(
        child: Text('No se encontró el registro de entrega y recepción.'),
      );
    }
    return _SoftPanel(
      child: Column(
        children: [
          if (handoff.isNotEmpty) ...[
            const _MiniHeading('Recepción inicial'),
            const SizedBox(height: 9),
            _DataRow(
              icon: Icons.person_remove_alt_1_outlined,
              label: 'Entregó',
              value: _text(handoff['entrega_nombre'], 'Sin entrega previa'),
            ),
            const SizedBox(height: 9),
            _DataRow(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Recibió',
              value: _text(handoff['recibe_nombre'], 'Sin confirmar'),
            ),
            const SizedBox(height: 9),
            _DataRow(
              icon: Icons.schedule_outlined,
              label: 'Hora',
              value: _shortTime(handoff['hora_real']),
            ),
            const SizedBox(height: 10),
            _DetailsButton(
              label: 'Ver inspección de recepción',
              onPressed: () => _showHandoffDetails(
                context,
                title: 'Datos de recepción',
                record: handoff,
              ),
            ),
            const Divider(height: 24),
          ],
          const SizedBox(height: 9),
          _DataRow(
            icon: Icons.speed_rounded,
            label: 'Kilometraje',
            value:
                '${log['kilometraje_inicio'] ?? handoff['kilometraje'] ?? '-'} → ${log['kilometraje_fin'] ?? 'en curso'} km',
          ),
          const SizedBox(height: 9),
          _DataRow(
            icon: Icons.local_gas_station_outlined,
            label: 'Combustible',
            value: _fuelRange(
              log['combustible_inicio'] ?? handoff['nivel_combustible'],
              log['combustible_fin'],
            ),
          ),
          if (finalHandoff.isNotEmpty) ...[
            const Divider(height: 24),
            const _MiniHeading('Entrega al finalizar'),
            const SizedBox(height: 9),
            _DataRow(
              icon: Icons.person_remove_alt_1_outlined,
              label: 'Entregó',
              value: _text(finalHandoff['entrega_nombre'], 'Sin confirmar'),
            ),
            const SizedBox(height: 9),
            _DataRow(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Recibe',
              value: _text(
                finalHandoff['recibe_nombre'],
                'Pendiente de recepción',
              ),
            ),
            const SizedBox(height: 9),
            _DataRow(
              icon: Icons.schedule_outlined,
              label: 'Hora',
              value: _dateTimeTime(
                finalHandoff['entrega_confirmada_at'] ??
                    finalHandoff['hora_real'],
              ),
            ),
            const SizedBox(height: 10),
            _DetailsButton(
              label: 'Ver datos de entrega',
              onPressed: () => _showHandoffDetails(
                context,
                title: 'Datos de entrega',
                record: finalHandoff,
              ),
            ),
          ],
          if (_hasText(handoff['danos_existentes']) ||
              _hasText(handoff['novedades']) ||
              _hasText(handoff['observaciones'])) ...[
            const Divider(height: 22),
            _DataRow(
              icon: Icons.report_problem_outlined,
              label: 'Novedades',
              value:
                  [
                        handoff['danos_existentes'],
                        handoff['novedades'],
                        handoff['observaciones'],
                      ]
                      .where(_hasText)
                      .map((value) => value.toString().trim())
                      .join(' · '),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DetailsButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.visibility_outlined),
      label: Text(label),
    ),
  );
}

Future<void> _showHandoffDetails(
  BuildContext context, {
  required String title,
  required Map<String, dynamic> record,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF8FAFC),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _HandoffDetailsSheet(title: title, record: record),
  );
}

class _HandoffDetailsSheet extends StatelessWidget {
  final String title;
  final Map<String, dynamic> record;

  const _HandoffDetailsSheet({required this.title, required this.record});

  static const _conditions = <(String, String)>[
    ('estado_carroceria', 'Carrocería'),
    ('estado_interiores', 'Interiores'),
    ('estado_llantas', 'Llantas'),
    ('estado_luces', 'Luces'),
    ('estado_torreta', 'Torreta'),
    ('estado_sirena', 'Sirena'),
    ('estado_radio', 'Radio'),
    ('estado_mecanico', 'Mecánico'),
  ];

  static const _inventory = <(String, String)>[
    ('trae_refaccion', 'Refacción'),
    ('trae_gato', 'Gato'),
    ('trae_llave_cruz', 'Llave de cruz'),
    ('trae_extintor', 'Extintor'),
    ('trae_botiquin', 'Botiquín'),
  ];

  static const _photos = <(String, String)>[
    ('foto_frontal_url', 'Frontal'),
    ('foto_trasera_url', 'Trasera'),
    ('foto_lateral_izquierdo_url', 'Lateral izquierdo'),
    ('foto_lateral_derecho_url', 'Lateral derecho'),
    ('foto_tablero_url', 'Tablero'),
  ];

  @override
  Widget build(BuildContext context) {
    final conditions = _conditions
        .where((field) => _hasText(record[field.$1]))
        .toList();
    final inventory = _inventory
        .where((field) => record.containsKey(field.$1))
        .toList();
    final photos = _photos
        .where((field) => _hasText(record[field.$1]))
        .toList();
    final notes = <(String, String)>[
      ('equipo_adicional', 'Equipo adicional'),
      ('danos_existentes', 'Daños existentes'),
      ('novedades', 'Novedades'),
      ('observaciones', 'Observaciones'),
    ].where((field) => _hasText(record[field.$1])).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: Color(0xFFE0F2F1),
                foregroundColor: Color(0xFF0F766E),
                child: Icon(Icons.fact_check_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${_text(record['fecha'], 'Sin fecha')} · ${_shortTime(record['hora_real'])}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DetailSection(
            title: 'Responsables y lecturas',
            icon: Icons.swap_horiz_rounded,
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.person_remove_alt_1_outlined,
                  label: 'Entregó',
                  value: _text(record['entrega_nombre'], 'Sin registrar'),
                ),
                const SizedBox(height: 11),
                _DataRow(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Recibió',
                  value: _text(record['recibe_nombre'], 'Pendiente'),
                ),
                const SizedBox(height: 11),
                _DataRow(
                  icon: Icons.speed_rounded,
                  label: 'Kilometraje',
                  value: '${record['kilometraje'] ?? '-'} km',
                ),
                const SizedBox(height: 11),
                _DataRow(
                  icon: Icons.local_gas_station_outlined,
                  label: 'Combustible',
                  value: _hasText(record['nivel_combustible'])
                      ? '${_number(record['nivel_combustible'])}%'
                      : 'Sin registrar',
                ),
              ],
            ),
          ),
          if (conditions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Estado de la unidad',
              icon: Icons.directions_car_filled_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: conditions
                    .map(
                      (field) => _ConditionBadge(
                        label: field.$2,
                        value: _text(record[field.$1]),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (inventory.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Inventario recibido',
              icon: Icons.inventory_2_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: inventory
                    .map(
                      (field) => _InventoryBadge(
                        label: field.$2,
                        value: _bool(record[field.$1]),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Anotaciones capturadas',
              icon: Icons.notes_rounded,
              child: Column(
                children: notes
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _NoteBlock(
                          label: field.$2,
                          value: _text(record[field.$1]),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Evidencia fotográfica',
              icon: Icons.photo_library_outlined,
              child: SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return _EvidencePhoto(
                      label: photo.$2,
                      url: _text(record[photo.$1]),
                    );
                  },
                ),
              ),
            ),
          ],
          if (conditions.isEmpty &&
              inventory.isEmpty &&
              notes.isEmpty &&
              photos.isEmpty) ...[
            const SizedBox(height: 12),
            const _SoftPanel(
              child: Text(
                'Este registro no contiene inspección, inventario, anotaciones ni fotografías adicionales.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0F4C5C)),
            const SizedBox(width: 7),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}

class _ConditionBadge extends StatelessWidget {
  final String label;
  final String value;

  const _ConditionBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().toLowerCase();
    final color = switch (normalized) {
      'bueno' => const Color(0xFF16803B),
      'regular' => const Color(0xFFD97706),
      'malo' => const Color(0xFFB91C1C),
      _ => const Color(0xFF64748B),
    };
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            _statusLabel(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InventoryBadge extends StatelessWidget {
  final String label;
  final bool? value;

  const _InventoryBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value == true
        ? const Color(0xFF16803B)
        : value == false
        ? const Color(0xFFB91C1C)
        : const Color(0xFF64748B);
    final text = value == true
        ? 'Sí'
        : value == false
        ? 'No'
        : '-';
    return Chip(
      avatar: Icon(
        value == true ? Icons.check_circle : Icons.cancel_outlined,
        size: 18,
        color: color,
      ),
      label: Text('$label · $text'),
      backgroundColor: color.withValues(alpha: .07),
      side: BorderSide(color: color.withValues(alpha: .15)),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String label;
  final String value;

  const _NoteBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _EvidencePhoto extends StatelessWidget {
  final String label;
  final String url;

  const _EvidencePhoto({required this.label, required this.url});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => showPhotoViewer(
        context: context,
        title: 'Evidencia · $label',
        photoUrl: url,
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SafeNetworkImage(
                url,
                width: 104,
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
                loadingBuilder: (_, __) => Container(
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _MiniHeading extends StatelessWidget {
  final String text;

  const _MiniHeading(this.text);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF0F4C5C),
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _SoftPanel extends StatelessWidget {
  final Widget child;

  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF64748B)),
      const SizedBox(width: 8),
      SizedBox(
        width: 82,
        child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ],
  );
}

class _WorkTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> incidents;

  const _WorkTimeline({required this.activities, required this.incidents});

  @override
  Widget build(BuildContext context) {
    final entries = <_WorkEntry>[
      ...activities.map(
        (item) => _WorkEntry(
          time: _text(item['hora']),
          title: _text(
            _map(item['subcategoria'])['nombre'] ?? item['nombre'],
            'Actividad',
          ),
          detail: _text(item['lugar'] ?? item['motivo'], 'Sin detalle'),
          icon: Icons.assignment_turned_in_outlined,
          color: const Color(0xFF0E7490),
        ),
      ),
      ...incidents.map(
        (item) => _WorkEntry(
          time: _text(item['hora']),
          title: _text(item['tipo_hecho'], 'Hecho de tránsito'),
          detail: _text(
            [item['calle'], item['colonia']]
                .where(_hasText)
                .map((value) => value.toString().trim())
                .join(', '),
            'Sin ubicación',
          ),
          icon: Icons.car_crash_outlined,
          color: const Color(0xFFB45309),
        ),
      ),
    ]..sort((a, b) => a.time.compareTo(b.time));

    if (entries.isEmpty) {
      return const _SoftPanel(
        child: Text(
          'No se registraron actividades ni hechos en este servicio.',
        ),
      );
    }

    return Column(
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: entry.color.withValues(alpha: .1),
                    foregroundColor: entry.color,
                    child: Icon(entry.icon, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          entry.detail,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _shortTime(entry.time),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WorkEntry {
  final String time;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _WorkEntry({
    required this.time,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const <Map<String, dynamic>>[];

int? _int(dynamic value) => value is int
    ? value
    : value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '');

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

bool _hasText(dynamic value) => _text(value).isNotEmpty;

bool? _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = _text(value).toLowerCase();
  if (const {'1', 'true', 'si', 'sí'}.contains(normalized)) return true;
  if (const {'0', 'false', 'no'}.contains(normalized)) return false;
  return null;
}

String _statusLabel(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'bueno' => 'Bueno',
    'regular' => 'Regular',
    'malo' => 'Malo',
    'no_aplica' => 'No aplica',
    _ => value,
  };
}

String _shortTime(dynamic value) {
  final text = _text(value, '--:--');
  return text.length >= 5 ? text.substring(0, 5) : text;
}

String _number(dynamic value) {
  if (value == null || _text(value).isEmpty) return '-';
  final parsed = double.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return parsed == parsed.roundToDouble()
      ? parsed.round().toString()
      : parsed.toStringAsFixed(1);
}

String _fuelRange(dynamic start, dynamic end) {
  final startText = _number(start);
  final endText = _number(end);
  return '${startText == '-' ? '-' : '$startText%'} → '
      '${endText == '-' ? 'en curso' : '$endText%'}';
}

String _dateTimeTime(dynamic value) {
  final text = _text(value, '--:--');
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return _shortTime(text);
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _friendlyDate(DateTime date) {
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  if (DateUtils.isSameDay(date, DateTime.now())) {
    return 'Hoy, ${date.day} de ${months[date.month - 1]}';
  }
  return '${date.day} de ${months[date.month - 1]} de ${date.year}';
}

String _message(Object error) {
  if (error is PatrullaServicioException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}
