import 'package:flutter/material.dart';

import '../../models/guardianes_camino_dispositivo.dart';
import '../../services/app_version_service.dart';
import '../../services/auth_service.dart';
import '../../services/guardianes_camino_dispositivos_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';
import '../../app/routes.dart';
import '../login_screen.dart';

class DispositivosScreen extends StatefulWidget {
  const DispositivosScreen({super.key});

  @override
  State<DispositivosScreen> createState() => _DispositivosScreenState();
}

class _DispositivosScreenState extends State<DispositivosScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _loading = true;
  bool _canUseDispositivos = false;

  String? _error;

  DateTime _selectedDate = DateTime.now();
  List<GuardianesCaminoDispositivo> _items =
      const <GuardianesCaminoDispositivo>[];
  String? _catalogoNombreFiltro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      if (!mounted) return;
      await _bootstrapTrackingStatusOnly();
      if (!mounted) return;
      await _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await TrackingService.isRunning();
      if (!mounted) return;
      setState(() => _trackingOn = running);
    }
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      await TrackingService.stop();
      await AuthService.logout();
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtDmY(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });

    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hasUnitAccess = await AuthService.isCarreterasUser(refresh: true);
      final hasPermission = await AuthService.can('ver operativos carreteras');
      if (!hasUnitAccess || !hasPermission) {
        if (!mounted) return;
        setState(() {
          _items = const <GuardianesCaminoDispositivo>[];
          _canUseDispositivos = false;
          _loading = false;
          _error = 'No tienes acceso al módulo de carreteras.';
        });
        return;
      }

      final result = await GuardianesCaminoDispositivosService.fetchIndex(
        fecha: _selectedDate,
      );

      if (!mounted) return;
      setState(() {
        _items = result.items;
        _canUseDispositivos = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const <GuardianesCaminoDispositivo>[];
        _canUseDispositivos = false;
        _loading = false;
        _error = 'No se pudieron cargar los dispositivos.\n$e';
      });
    }
  }

  void _showResumen(GuardianesCaminoDispositivo item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            shrinkWrap: true,
            children: [
              Text(
                item.catalogoNombre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Fecha',
                value: item.fecha.isEmpty ? '—' : item.fecha,
              ),
              _InfoRow(
                label: 'Hora',
                value: item.hora.isEmpty ? '—' : item.hora,
              ),
              _InfoRow(label: 'Ubicación', value: item.ubicacionResumen),
              _InfoRow(
                label: 'Destacamento',
                value: item.destacamentoNombre.isEmpty
                    ? '—'
                    : item.destacamentoNombre,
              ),
              _InfoRow(
                label: 'Responsable',
                value: item.nombreResponsable.isEmpty
                    ? '—'
                    : item.nombreResponsable,
              ),
              _InfoRow(
                label: 'Cargo',
                value: item.cargoResponsable.isEmpty
                    ? '—'
                    : item.cargoResponsable,
              ),
              _InfoRow(
                label: 'Estado de fuerza',
                value: '${item.estadoFuerzaParticipante}',
              ),
              _InfoRow(label: 'Fotos', value: '${item.fotosCount}'),
              _InfoRow(
                label: 'Requiere evidencia',
                value: item.requiereEvidencia ? 'Sí' : 'No',
              ),
              const SizedBox(height: 12),
              const Text(
                'Resumen',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(item.resumen),
            ],
          ),
        );
      },
    );
  }

  Widget _filtersBar() {
    final catalogosDisponibles =
        _items
            .map((item) => item.catalogoNombre)
            .where((nombre) => nombre.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mostrando: ${_fmtYmd(_selectedDate)}',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _fmtDmY(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _catalogoNombreFiltro,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Listado (todos)'),
            ),
            ...catalogosDisponibles.map(
              (catalogo) => DropdownMenuItem<String>(
                value: catalogo,
                child: Text(catalogo),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _catalogoNombreFiltro = value);
          },
          decoration: InputDecoration(
            labelText: 'Listado',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _catalogoNombreFiltro == null
        ? _items
        : _items
              .where((item) => item.catalogoNombre == _catalogoNombreFiltro)
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Dispositivos'),
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            await _load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
              if (_trackingOn) const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.blue.withValues(alpha: .06),
                  border: Border.all(color: Colors.blue.withValues(alpha: .18)),
                ),
                child: _filtersBar(),
              ),
              const SizedBox(height: 12),
              _SummaryStrip(
                total: filteredItems.length,
                selectedDate: _fmtDmY(_selectedDate),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(child: Text(_error!)),
                )
              else if (filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No hay dispositivos para este filtro.'),
                  ),
                )
              else
                ...filteredItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DispositivoCard(
                      item: item,
                      onTap: () => _showResumen(item),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      floatingActionButton: _canUseDispositivos
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.dispositivosCreate),
              tooltip: 'Agregar dispositivo',
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int total;
  final String selectedDate;

  const _SummaryStrip({required this.total, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(label: 'Listado', value: '$total registros'),
          ),
          Expanded(
            child: _SummaryItem(label: 'Fecha', value: selectedDate),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DispositivoCard extends StatelessWidget {
  final GuardianesCaminoDispositivo item;
  final VoidCallback onTap;

  const _DispositivoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.catalogoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    '#${item.id}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.ubicacionResumen,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.resumen,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniTag(text: item.fecha.isEmpty ? 'Sin fecha' : item.fecha),
                  if (item.hora.isNotEmpty) _MiniTag(text: item.hora),
                  if (item.destacamentoNombre.isNotEmpty)
                    _MiniTag(text: item.destacamentoNombre),
                  _MiniTag(text: '${item.fotosCount} fotos'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;

  const _MiniTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
