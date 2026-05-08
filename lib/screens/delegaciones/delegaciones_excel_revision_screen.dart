import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/delegaciones_excel_revision_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';

class DelegacionesExcelRevisionScreen extends StatefulWidget {
  const DelegacionesExcelRevisionScreen({super.key});

  @override
  State<DelegacionesExcelRevisionScreen> createState() =>
      _DelegacionesExcelRevisionScreenState();
}

class _DelegacionesExcelRevisionScreenState
    extends State<DelegacionesExcelRevisionScreen> {
  final _svc = DelegacionesExcelRevisionService();

  DateTime _fecha = DateTime.now();
  bool _loading = true;
  bool _busy = false;
  bool _loggingOut = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fecha = DateTime(_fecha.year, _fecha.month, _fecha.day);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _svc.fetch(fecha: _fecha);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() => _fecha = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Map<String, dynamic> _map(String key) => _asMap(_data?[key]);

  List<Map<String, dynamic>> _list(String key) {
    final raw = _data?[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _detailItems(
    Map<String, dynamic> detalles,
    dynamic key,
  ) {
    final name = (key ?? '').toString().trim();
    if (name.isEmpty) return const <Map<String, dynamic>>[];

    final raw = detalles[name];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _openDetailItem(Map<String, dynamic> item) {
    final tipo = (item['tipo'] ?? '').toString();
    final id = _int(item['id']);

    if (id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este registro no trae ID para abrir.')),
      );
      return;
    }

    if (tipo == 'actividad') {
      Navigator.pushNamed(
        context,
        AppRoutes.actividadesShow,
        arguments: {'actividad_id': id},
      );
      return;
    }

    if (tipo == 'hecho') {
      Navigator.pushNamed(context, AppRoutes.accidentesShow, arguments: id);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tipo de registro no reconocido.')),
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtDisplayDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _fmtNumber(num value, {int decimals = 0}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final buffer = StringBuffer();
    final source = parts.first;

    for (var i = 0; i < source.length; i++) {
      final left = source.length - i;
      buffer.write(source[i]);
      if (left > 1 && left % 3 == 1) {
        buffer.write(',');
      }
    }

    if (parts.length > 1 && decimals > 0) {
      buffer.write('.');
      buffer.write(parts.last);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final totales = _map('totales');
    final fuentes = _map('fuentes');
    final corte = _map('corte');
    final excel = _map('excel');
    final detalles = _map('detalles');
    final alertas = _list('alertas');
    final regionales = _list('regionales');
    final topActividades = _list('top_actividades');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Revisión Excel Delegaciones'),
        actions: [
          IconButton(
            tooltip: 'Fecha de corte',
            onPressed: _busy || _loading ? null : _pickDate,
            icon: const Icon(Icons.event_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _busy || _loading
                ? null
                : () => _runBusy(() async => _load()),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.6))
            : _error != null
            ? _errorView()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _summaryHeader(corte, excel),
                    const SizedBox(height: 14),
                    _metricsGrid(totales, fuentes),
                    const SizedBox(height: 18),
                    _sectionTitle('Alertas de cuadre'),
                    const SizedBox(height: 8),
                    if (alertas.isEmpty)
                      _clearState()
                    else
                      ...alertas.map(
                        (a) => _AlertTile(
                          data: a,
                          items: _detailItems(detalles, a['detalle_key']),
                          onOpen: _openDetailItem,
                          fmtNumber: _fmtNumber,
                        ),
                      ),
                    const SizedBox(height: 18),
                    _sectionTitle('Conciliacion rapida'),
                    const SizedBox(height: 8),
                    _conciliation(totales, fuentes),
                    const SizedBox(height: 18),
                    _sectionTitle('Hechos de transito'),
                    const SizedBox(height: 8),
                    _hechosStatus(totales),
                    const SizedBox(height: 18),
                    _sectionTitle('Regionales'),
                    const SizedBox(height: 8),
                    _regionalList(regionales),
                    const SizedBox(height: 18),
                    _sectionTitle('Top renglones del Excel'),
                    const SizedBox(height: 8),
                    _topActivities(topActividades),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryHeader(
    Map<String, dynamic> corte,
    Map<String, dynamic> excel,
  ) {
    final corteLabel = (corte['label'] ?? '').toString();
    final archivo = _asMap(excel['archivo_diario']);
    final generado = excel['generado_para_revision'] == true;
    final mensaje = (excel['mensaje'] ?? '').toString();
    final archivoExiste = archivo['existe'] == true;
    final archivoNombre =
        (archivo['nombre'] ?? 'excel_delegaciones_${_fmtDate(_fecha)}.xlsx')
            .toString();
    final actualizado = (archivo['actualizado_at'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Corte ${_fmtDisplayDate(_fecha)}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (corteLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        corteLabel,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Fecha'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: generado ? Icons.history_toggle_off : Icons.check_circle,
                label: (excel['titulo'] ?? '').toString().trim().isEmpty
                    ? archivoExiste
                          ? 'Excel diario guardado'
                          : 'Vista generada al momento'
                    : excel['titulo'].toString(),
                color: archivoExiste
                    ? const Color(0xFF047857)
                    : const Color(0xFFB45309),
              ),
              _Pill(
                icon: Icons.description_outlined,
                label: archivoNombre,
                color: const Color(0xFF2563EB),
              ),
              if (actualizado.trim().isNotEmpty)
                _Pill(
                  icon: Icons.schedule_outlined,
                  label: actualizado,
                  color: const Color(0xFF6D28D9),
                ),
            ],
          ),
          if (mensaje.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: generado
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: generado
                      ? const Color(0xFFF59E0B).withValues(alpha: .45)
                      : const Color(0xFF16A34A).withValues(alpha: .28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    generado
                        ? Icons.warning_amber_outlined
                        : Icons.verified_outlined,
                    color: generado
                        ? const Color(0xFFB45309)
                        : const Color(0xFF047857),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: TextStyle(
                        color: generado
                            ? const Color(0xFF92400E)
                            : const Color(0xFF166534),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricsGrid(
    Map<String, dynamic> totales,
    Map<String, dynamic> fuentes,
  ) {
    final sinDelegacion =
        _int(fuentes['actividades_sin_delegacion']) +
        _int(fuentes['hechos_sin_delegacion']);
    final participantes = _int(
      totales['personas_participantes'] ?? totales['estado_fuerza'],
    );
    final detenidas = _int(fuentes['personas_detenidas_fuente']);
    final aseguradas = _int(
      totales['personas_aseguradas'] ?? totales['aseguramientos_total'],
    );

    final items = [
      _MetricData(
        icon: Icons.checklist_rtl,
        label: 'Dispositivos',
        value: _fmtNumber(_int(totales['dispositivos'])),
        detail:
            '${_fmtNumber(_double(totales['km_recorridos']), decimals: 1)} km',
        color: const Color(0xFF2563EB),
      ),
      _MetricData(
        icon: Icons.people_alt_outlined,
        label: 'Alcanzadas',
        value: _fmtNumber(_int(totales['personas_alcanzadas'])),
        detail:
            '${_fmtNumber(_int(fuentes['personas_alcanzadas_fuente']))} en capturas',
        color: const Color(0xFF0F766E),
      ),
      _MetricData(
        icon: Icons.groups_outlined,
        label: 'Participantes',
        value: _fmtNumber(participantes),
        detail:
            '${_fmtNumber(_int(fuentes['personas_participantes_fuente']))} en capturas',
        color: const Color(0xFF0891B2),
      ),
      _MetricData(
        icon: Icons.gavel,
        label: 'Detenidas',
        value: _fmtNumber(detenidas),
        detail: 'Aseg. Excel ${_fmtNumber(aseguradas)}',
        color: const Color(0xFF9333EA),
      ),
      _MetricData(
        icon: Icons.car_crash_outlined,
        label: 'Hechos contados',
        value: _fmtNumber(_int(totales['hechos_total'])),
        detail:
            '${_fmtNumber(_int(totales['involucrados_total']))} involucrados',
        color: const Color(0xFFDC2626),
      ),
      _MetricData(
        icon: Icons.pending_actions_outlined,
        label: 'Incompletos',
        value: _fmtNumber(_int(fuentes['hechos_incompletos_en_corte'])),
        detail: 'Aun no entran al Excel',
        color: const Color(0xFFEA580C),
      ),
      _MetricData(
        icon: Icons.wrong_location_outlined,
        label: 'Sin delegacion',
        value: _fmtNumber(sinDelegacion),
        detail: 'Abre la alerta para verlos',
        color: const Color(0xFF7C3AED),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MetricCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _clearState() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: .28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sin alertas fuertes para este corte.',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conciliation(
    Map<String, dynamic> totales,
    Map<String, dynamic> fuentes,
  ) {
    final rows = [
      _InfoRowData(
        label: 'Actividades fuente',
        value: _fmtNumber(_int(fuentes['actividades_en_corte'])),
        detail: 'Capturas de Delegaciones dentro del corte',
      ),
      _InfoRowData(
        label: 'Personas alcanzadas',
        value: _fmtNumber(_int(totales['personas_alcanzadas'])),
        detail:
            '${_fmtNumber(_int(fuentes['personas_alcanzadas_fuente']))} capturadas en actividades',
      ),
      _InfoRowData(
        label: 'Participantes',
        value: _fmtNumber(
          _int(totales['personas_participantes'] ?? totales['estado_fuerza']),
        ),
        detail:
            '${_fmtNumber(_int(fuentes['personas_participantes_fuente']))} capturados como estado de fuerza',
      ),
      _InfoRowData(
        label: 'Detenidas en capturas',
        value: _fmtNumber(_int(fuentes['personas_detenidas_fuente'])),
        detail: 'Suma del campo personas detenidas en actividades',
      ),
      _InfoRowData(
        label: 'Personas aseguradas Excel',
        value: _fmtNumber(
          _int(
            totales['personas_aseguradas'] ?? totales['aseguramientos_total'],
          ),
        ),
        detail: 'Control de aseguramientos del formato',
      ),
      _InfoRowData(
        label: 'Dispositivos Excel',
        value: _fmtNumber(_int(totales['dispositivos'])),
        detail: 'Total de renglones operativos reflejados',
      ),
      _InfoRowData(
        label: 'Hechos por fecha',
        value: _fmtNumber(_int(fuentes['hechos_por_fecha_en_corte'])),
        detail: 'Ocurrieron dentro del rango de corte',
      ),
      _InfoRowData(
        label: 'Hechos que entran',
        value: _fmtNumber(_int(fuentes['hechos_contados_excel'])),
        detail: 'Completados dentro de la ventana del Excel',
      ),
      _InfoRowData(
        label: 'Completados fuera',
        value: _fmtNumber(_int(fuentes['hechos_completados_fuera_corte'])),
        detail: 'Se contabilizan en otro corte por hora de cierre',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(data: rows[i]),
            if (i < rows.length - 1)
              Divider(height: 1, color: Colors.grey.shade200, indent: 16),
          ],
        ],
      ),
    );
  }

  Widget _hechosStatus(Map<String, dynamic> totales) {
    final resueltos = _int(totales['hechos_resueltos']);
    final pendientes = _int(totales['hechos_pendientes']);
    final turnados = _int(totales['hechos_turnados']);
    final total = (resueltos + pendientes + turnados).clamp(0, 1 << 31).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _ProgressLine(
            label: 'Resueltos',
            value: resueltos,
            total: total,
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 12),
          _ProgressLine(
            label: 'Pendientes',
            value: pendientes,
            total: total,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: 12),
          _ProgressLine(
            label: 'Turnados',
            value: turnados,
            total: total,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _regionalList(List<Map<String, dynamic>> regionales) {
    if (regionales.isEmpty) {
      return _emptyBox('Sin regionales para mostrar.');
    }

    final max = regionales
        .map((e) => _int(e['dispositivos']))
        .fold<int>(0, (prev, item) => item > prev ? item : prev);

    return Column(
      children: [
        _regionalLegend(),
        const SizedBox(height: 10),
        ...regionales.map(
          (regional) => _RegionalTile(
            data: regional,
            maxDispositivos: max,
            fmtNumber: _fmtNumber,
            intValue: _int,
            doubleValue: _double,
            onOpen: _openDetailItem,
          ),
        ),
      ],
    );
  }

  Widget _regionalLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '“Revisar” significa que esa regional tiene hechos pendientes o turnados dentro del Excel. Toca una regional para ver el motivo exacto.',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _topActivities(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _emptyBox('Sin renglones con conteo para este corte.');
    }

    return Column(
      children: rows
          .map(
            (row) => _TopActivityTile(
              data: row,
              fmtNumber: _fmtNumber,
              intValue: _int,
              doubleValue: _double,
            ),
          )
          .toList(),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _errorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: .3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No se pudo cargar la revision',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData item;

  const _MetricCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_flat, color: Colors.grey.shade400, size: 18),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final String Function(num value, {int decimals}) fmtNumber;

  const _AlertTile({
    required this.data,
    required this.items,
    required this.onOpen,
    required this.fmtNumber,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = (data['tipo'] ?? '').toString();
    final color = tipo == 'critica'
        ? const Color(0xFFDC2626)
        : tipo == 'aviso'
        ? const Color(0xFFEA580C)
        : const Color(0xFF2563EB);
    final title = (data['titulo'] ?? 'Alerta').toString();
    final detail = (data['detalle'] ?? '').toString();
    final count = data['conteo'];
    final countText = count is num
        ? fmtNumber(count)
        : count?.toString() ?? '0';
    final hasItems = items.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded: hasItems && tipo == 'critica',
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.priority_high, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                hasItems
                    ? 'Toca para ver ${fmtNumber(items.length)} registros y abrirlos.'
                    : 'Sin listado detallado disponible para esta alerta.',
                style: TextStyle(
                  color: hasItems ? color : Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          trailing: Text(
            countText,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: [
            if (hasItems)
              ...items.map(
                (item) => _DetailRecordTile(item: item, onOpen: onOpen),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Esta alerta es un total calculado; no hay filas individuales para abrir.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRecordTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _DetailRecordTile({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final tipo = (item['tipo'] ?? '').toString();
    final isActividad = tipo == 'actividad';
    final color = isActividad
        ? const Color(0xFF2563EB)
        : const Color(0xFFDC2626);
    final title = (item['titulo'] ?? 'Registro').toString();
    final subtitle = (item['subtitulo'] ?? '').toString();
    final motivo = (item['motivo'] ?? '').toString();
    final fecha = (item['fecha'] ?? '').toString();
    final hora = (item['hora'] ?? '').toString();
    final municipio = (item['municipio'] ?? '').toString();
    final lugar = (item['lugar'] ?? '').toString();
    final alcanzadas = _intValue(item['personas_alcanzadas']);
    final participantes = _intValue(item['personas_participantes']);
    final detenidas = _intValue(item['personas_detenidas']);
    final meta = [
      if (fecha.trim().isNotEmpty) fecha,
      if (hora.trim().isNotEmpty) hora,
      if (municipio.trim().isNotEmpty) municipio,
      if (lugar.trim().isNotEmpty) lugar,
    ].join(' · ');
    final personasMeta = [
      if (participantes > 0) '$participantes participantes',
      if (alcanzadas > 0) '$alcanzadas alcanzadas',
      if (detenidas > 0) '$detenidas detenidas',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActividad ? Icons.assignment_outlined : Icons.car_crash_outlined,
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (motivo.trim().isNotEmpty)
              Text(
                motivo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (meta.trim().isNotEmpty)
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (isActividad && personasMeta.trim().isNotEmpty)
              Text(
                personasMeta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => onOpen(item),
      ),
    );
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _InfoRowData {
  final String label;
  final String value;
  final String detail;

  const _InfoRowData({
    required this.label,
    required this.value,
    required this.detail,
  });
}

class _InfoRow extends StatelessWidget {
  final _InfoRowData data;

  const _InfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.detail,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            data.value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressLine({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: pct,
            backgroundColor: color.withValues(alpha: .12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RegionalTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final int maxDispositivos;
  final String Function(num value, {int decimals}) fmtNumber;
  final int Function(dynamic value) intValue;
  final double Function(dynamic value) doubleValue;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _RegionalTile({
    required this.data,
    required this.maxDispositivos,
    required this.fmtNumber,
    required this.intValue,
    required this.doubleValue,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (data['nombre'] ?? '').toString();
    final dispositivos = intValue(data['dispositivos']);
    final hechos = intValue(data['hechos_total']);
    final pendientes = intValue(data['hechos_pendientes']);
    final turnados = intValue(data['hechos_turnados']);
    final km = doubleValue(data['km_recorridos']);
    final alcanzadas = intValue(data['personas_alcanzadas']);
    final participantes = intValue(
      data['personas_participantes'] ?? data['estado_fuerza'],
    );
    final aseguradas = intValue(
      data['personas_aseguradas'] ?? data['aseguramientos_total'],
    );
    final detenidasHijas = intValue(data['personas_detenidas_hijas_total']);
    final estado = (data['estado'] ?? '').toString();
    final color = estado == 'ok'
        ? const Color(0xFF16A34A)
        : estado == 'vacio'
        ? const Color(0xFF64748B)
        : const Color(0xFFEA580C);
    final pct = maxDispositivos <= 0
        ? 0.0
        : (dispositivos / maxDispositivos).clamp(0.0, 1.0);
    final alertas = _alerts(data, pendientes: pendientes, turnados: turnados);
    final hijas = _hijas(data);
    final diferenciasRenglones = _diferenciasRenglones(data);
    final totalHijas = intValue(data['dispositivos_hijas_total']);
    final diferenciaHijas = intValue(data['diferencia_hijas']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded: estado == 'atencion',
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.apartment, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusDetail(estado, alertas),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallBadge(label: _statusLabel(estado), color: color),
            ],
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(
                  label: 'Dispositivos',
                  value: fmtNumber(dispositivos),
                ),
                _MiniStat(label: 'Hechos', value: fmtNumber(hechos)),
                _MiniStat(label: 'Alcanzadas', value: fmtNumber(alcanzadas)),
                _MiniStat(
                  label: 'Participantes',
                  value: fmtNumber(participantes),
                ),
                _MiniStat(label: 'Aseguradas', value: fmtNumber(aseguradas)),
                _MiniStat(label: 'Pendientes', value: fmtNumber(pendientes)),
                _MiniStat(label: 'Turnados', value: fmtNumber(turnados)),
                _MiniStat(label: 'Km', value: fmtNumber(km, decimals: 1)),
                if (hijas.isNotEmpty)
                  _MiniStat(label: 'Suma hijas', value: fmtNumber(totalHijas)),
                if (hijas.isNotEmpty)
                  _MiniStat(
                    label: 'Det. hijas',
                    value: fmtNumber(detenidasHijas),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Motivo de revisión',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (alertas.isEmpty)
                    Text(
                      estado == 'vacio'
                          ? 'No hay registros contados para esta regional en este corte.'
                          : 'No hay pendientes ni turnados marcados para esta regional.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    )
                  else
                    ...alertas.map(
                      (alerta) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(Icons.circle, size: 6, color: color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alerta,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Actividad relativa del corte: ${fmtNumber(dispositivos)} de ${fmtNumber(maxDispositivos)} dispositivos en la regional con más actividad.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            if (diferenciasRenglones.isNotEmpty) ...[
              const SizedBox(height: 12),
              _rowDiffs(diferenciasRenglones),
            ],
            if (hijas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _childBreakdown(hijas, diferenciaHijas),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String estado) {
    if (estado == 'ok') return 'Sin alertas';
    if (estado == 'vacio') return 'Sin registros';
    return 'Revisar';
  }

  String _statusDetail(String estado, List<String> alertas) {
    if (estado == 'vacio') return 'No hay conteo en este corte';
    if (alertas.isEmpty) return 'Sin pendientes ni turnados';
    return 'Toca para ver ${alertas.length == 1 ? 'el motivo' : 'los motivos'}';
  }

  List<String> _alerts(
    Map<String, dynamic> data, {
    required int pendientes,
    required int turnados,
  }) {
    final raw = data['alertas'];
    final alertas = <String>[];

    if (raw is List) {
      for (final item in raw) {
        final text = (item ?? '').toString().trim();
        if (text.isNotEmpty) alertas.add(text);
      }
    }

    if (raw is! List && pendientes > 0) {
      alertas.add('Tiene $pendientes hechos pendientes dentro del corte.');
    }
    if (raw is! List && turnados > 0) {
      alertas.add('Tiene $turnados hechos turnados a MP dentro del corte.');
    }

    return alertas;
  }

  List<Map<String, dynamic>> _hijas(Map<String, dynamic> data) {
    final raw = data['hijas'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _diferenciasRenglones(Map<String, dynamic> data) {
    final raw = data['diferencias_renglones'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _rowDiffs(List<Map<String, dynamic>> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Renglones que provocan la diferencia',
            style: TextStyle(
              color: Color(0xFF78350F),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((row) {
            final actividad = (row['actividad'] ?? '').toString();
            final excel = intValue(row['excel']);
            final base = intValue(row['base_actual']);
            final diferencia = intValue(row['diferencia']);
            final badge = diferencia < 0
                ? 'Base +${fmtNumber(diferencia.abs())}'
                : 'Excel +${fmtNumber(diferencia.abs())}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actividad,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Excel ${fmtNumber(excel)} · Base actual ${fmtNumber(base)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SmallBadge(label: badge, color: const Color(0xFFB45309)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _childBreakdown(
    List<Map<String, dynamic>> hijas,
    int diferenciaHijas,
  ) {
    final totalHijas = hijas
        .map((item) => intValue(item['dispositivos']))
        .fold<int>(0, (prev, item) => prev + item);
    final totalExcelRegional = totalHijas + diferenciaHijas;
    final diferenciaAbs = diferenciaHijas.abs();
    final diferenciaLabel = diferenciaHijas > 0
        ? 'Excel +${fmtNumber(diferenciaAbs)}'
        : 'Base +${fmtNumber(diferenciaAbs)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dispositivos y personas por delegación',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (diferenciaHijas != 0)
                _SmallBadge(
                  label: diferenciaLabel,
                  color: const Color(0xFFB45309),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'El total compara renglones del Excel: las actividades cuentan en su renglón y los hechos completos aparecen en SINIESTROS y ACCIDENTES dentro del formato.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (diferenciaHijas != 0) ...[
            const SizedBox(height: 8),
            Text(
              'Comparación: el Excel regional trae ${fmtNumber(totalExcelRegional)} dispositivos y la suma actual de sus delegaciones trae ${fmtNumber(totalHijas)}. ${diferenciaHijas < 0 ? 'La base actual trae ${fmtNumber(diferenciaAbs)} más que ese Excel guardado.' : 'El Excel guardado trae ${fmtNumber(diferenciaAbs)} más que la base actual por delegaciones.'}',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...hijas.map(
            (item) => _DelegacionBreakdownRow(
              data: item,
              fmtNumber: fmtNumber,
              intValue: intValue,
              onOpen: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class _DelegacionBreakdownRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(num value, {int decimals}) fmtNumber;
  final int Function(dynamic value) intValue;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _DelegacionBreakdownRow({
    required this.data,
    required this.fmtNumber,
    required this.intValue,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (data['nombre'] ?? '').toString();
    final esCabecera = data['es_cabecera'] == true;
    final dispositivos = intValue(data['dispositivos']);
    final actividades = intValue(data['actividades_contadas']);
    final hechos = intValue(data['hechos_contados']);
    final alcanzadas = intValue(data['personas_alcanzadas']);
    final participantes = intValue(
      data['personas_participantes'] ?? data['estado_fuerza'],
    );
    final detenidas = intValue(data['personas_detenidas']);
    final registros = _registrosContados(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: registros.isNotEmpty && dispositivos <= 3,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (esCabecera)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: _SmallBadge(
                              label: 'Cabecera',
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${fmtNumber(actividades)} actividades + ${fmtNumber(hechos)} hechos en SINIESTROS/ACCIDENTES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmtNumber(participantes)} participantes · ${fmtNumber(alcanzadas)} alcanzadas · ${fmtNumber(detenidas)} detenidas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (registros.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ver ${fmtNumber(registros.length)} registros contados',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                fmtNumber(dispositivos),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          children: registros.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No hay registros individuales para esta fila.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]
              : registros
                    .map(
                      (item) => _DetailRecordTile(item: item, onOpen: onOpen),
                    )
                    .toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _registrosContados(Map<String, dynamic> data) {
    final raw = data['registros_contados'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class _TopActivityTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(num value, {int decimals}) fmtNumber;
  final int Function(dynamic value) intValue;
  final double Function(dynamic value) doubleValue;

  const _TopActivityTile({
    required this.data,
    required this.fmtNumber,
    required this.intValue,
    required this.doubleValue,
  });

  @override
  Widget build(BuildContext context) {
    final actividad = (data['actividad'] ?? '').toString();
    final cantidad = intValue(data['cantidad']);
    final personas = intValue(data['personas_alcanzadas']);
    final participantes = intValue(
      data['personas_participantes'] ?? data['estado_fuerza'],
    );
    final km = doubleValue(data['km_recorridos']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                fmtNumber(cantidad),
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actividad,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fmtNumber(participantes)} participantes · ${fmtNumber(personas)} alcanzadas · ${fmtNumber(km, decimals: 1)} km',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
