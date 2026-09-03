import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/traffic_controller.dart';
import '../../services/traffic_controller_access.dart';
import '../../services/traffic_controller_service.dart';

class SemaforosTalleresScreen extends StatefulWidget {
  const SemaforosTalleresScreen({super.key});

  @override
  State<SemaforosTalleresScreen> createState() =>
      _SemaforosTalleresScreenState();
}

class _SemaforosTalleresScreenState extends State<SemaforosTalleresScreen> {
  final _service = TrafficControllerService();
  final _nameA = TextEditingController();
  final _nameB = TextEditingController();
  final _greenA = TextEditingController();
  final _yellowA = TextEditingController();
  final _redAB = TextEditingController();
  final _greenB = TextEditingController();
  final _yellowB = TextEditingController();
  final _redBA = TextEditingController();
  Timer? _poller;
  TrafficControllerStatus? _status;
  bool? _allowed;
  bool _busy = false;
  bool _planLoaded = false;
  String _message = 'Conéctate a la red Wi-Fi del controlador maestro.';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final allowed = await TrafficControllerAccess.currentUserIsAllowed();
    if (!mounted) return;
    setState(() => _allowed = allowed);
    if (!allowed) return;
    await _refresh(showBusy: true);
    _poller = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refresh(showBusy: false),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    _service.dispose();
    for (final controller in [
      _nameA,
      _nameB,
      _greenA,
      _yellowA,
      _redAB,
      _greenB,
      _yellowB,
      _redBA,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh({required bool showBusy}) async {
    if (_busy && !showBusy) return;
    if (showBusy && mounted) setState(() => _busy = true);
    try {
      final status = await _service.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _message = status.fault.isEmpty
            ? (status.peerLinked
                  ? 'Maestro y secundario enlazados.'
                  : 'Maestro conectado en modo autónomo; el secundario no está presente.')
            : status.fault;
        if (!_planLoaded) {
          _loadPlan(status.plan);
          _planLoaded = true;
        }
      });
    } catch (error) {
      if (mounted && (_status == null || showBusy)) {
        setState(() => _message = _errorText(error));
      }
    } finally {
      if (showBusy && mounted) setState(() => _busy = false);
    }
  }

  void _loadPlan(TrafficControllerPlan plan) {
    _nameA.text = plan.movementAName;
    _nameB.text = plan.movementBName;
    _greenA.text = '${plan.greenASeconds}';
    _yellowA.text = '${plan.yellowASeconds}';
    _redAB.text = '${plan.allRedAToBSeconds}';
    _greenB.text = '${plan.greenBSeconds}';
    _yellowB.text = '${plan.yellowBSeconds}';
    _redBA.text = '${plan.allRedBToASeconds}';
  }

  TrafficControllerPlan _editedPlan() => TrafficControllerPlan(
    movementAName: _nameA.text.trim(),
    movementBName: _nameB.text.trim(),
    greenASeconds: int.tryParse(_greenA.text) ?? 0,
    yellowASeconds: int.tryParse(_yellowA.text) ?? 0,
    allRedAToBSeconds: int.tryParse(_redAB.text) ?? 0,
    greenBSeconds: int.tryParse(_greenB.text) ?? 0,
    yellowBSeconds: int.tryParse(_yellowB.text) ?? 0,
    allRedBToASeconds: int.tryParse(_redBA.text) ?? 0,
  );

  Future<void> _applyPlan() async {
    final plan = _editedPlan();
    final error = plan.validate();
    if (error != null) return _snack(error);
    if (!await _confirm(
      'Guardar plan',
      'El ciclo será de ${plan.cycleSeconds} segundos. El controlador pasará '
          'a todo rojo antes de aplicar los tiempos nuevos.',
      action: 'Guardar',
    )) {
      return;
    }
    await _run(() => _service.applyPlan(plan), 'Plan aplicado y confirmado.');
  }

  Future<void> _start() async {
    final peerLinked = _status?.peerLinked == true;
    if (!await _confirm(
      'Iniciar ciclo',
      peerLinked
          ? 'Se iniciará el ciclo sincronizado de los dos semáforos. Verifica '
                'en sitio que ambos focos rojos estén encendidos.'
          : 'El secundario no está enlazado. Se iniciará únicamente el ciclo '
                'autónomo del semáforo maestro.',
      action: 'Iniciar',
    )) {
      return;
    }
    await _run(
      _service.start,
      peerLinked
          ? 'Ciclo sincronizado iniciado.'
          : 'Ciclo autónomo del maestro iniciado.',
    );
  }

  Future<void> _run(
    Future<TrafficControllerStatus> Function() operation,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      final status = await operation();
      if (!mounted) return;
      setState(() {
        _status = status;
        _message = success;
      });
      _snack(success);
    } catch (error) {
      if (mounted) _snack(_errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String body, {
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _connectionSettings() async {
    final current = await _service.loadConnection();
    if (!mounted) return;
    final endpoint = TextEditingController(text: current.endpoint);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conexión con el maestro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: endpoint,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: TrafficControllerService.defaultEndpoint,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'La clave del controlador se configura automáticamente.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar y probar'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await _service.saveConnection(
          TrafficControllerConnection(
            endpoint: endpoint.text,
            accessKey: TrafficControllerService.defaultAccessKey,
          ),
        );
        _planLoaded = false;
        await _refresh(showBusy: true);
      } catch (error) {
        if (mounted) _snack(_errorText(error));
      }
    }
    endpoint.dispose();
  }

  void _snack(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Semáforos de talleres')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Este módulo está disponible únicamente para la Unidad de '
              'Fomento a la Cultura Vial y superadmin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semáforos de talleres'),
        actions: [
          IconButton(
            tooltip: 'Configurar conexión',
            onPressed: _busy ? null : _connectionSettings,
            icon: const Icon(Icons.wifi_tethering),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _busy ? null : () => _refresh(showBusy: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(status: status, message: _message),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SignalCard(
                  node: status?.nodeA,
                  fallbackName: _nameA.text.isEmpty
                      ? 'Semáforo A'
                      : _nameA.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SignalCard(
                  node: status?.nodeB,
                  fallbackName: _nameB.text.isEmpty
                      ? 'Semáforo B'
                      : _nameB.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync, size: 34),
              title: Text(status?.phase ?? 'Sin datos del ciclo'),
              subtitle: Text(
                status == null
                    ? 'Configura la conexión con el maestro.'
                    : 'Faltan ${status.remainingSeconds} s · secuencia '
                          '${status.sequence} · ciclo ${status.plan.cycleSeconds} s',
              ),
              trailing: Icon(
                status?.peerLinked == true ? Icons.link : Icons.link_off,
                color: status?.peerLinked == true ? Colors.green : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: _busy
                ? null
                : () => _run(
                    _service.emergencyAllRed,
                    'Paro solicitado: ambos controladores en rojo.',
                  ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('TODO ROJO / PARO'),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || status?.running != true
                      ? null
                      : () => _run(_service.stop, 'Ciclo detenido en rojo.'),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Detener'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || status?.running == true ? null : _start,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Iniciar ciclo'),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Fases y tiempos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'El orden seguro no se puede alterar: A verde → A ámbar → todo '
            'rojo → B verde → B ámbar → todo rojo.',
          ),
          const SizedBox(height: 12),
          _MovementEditor(
            title: 'Movimiento A · controlador maestro',
            name: _nameA,
            green: _greenA,
            yellow: _yellowA,
            allRed: _redAB,
          ),
          _MovementEditor(
            title: 'Movimiento B · controlador secundario',
            name: _nameB,
            green: _greenB,
            yellow: _yellowB,
            allRed: _redBA,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _applyPlan,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar plan de operación'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Antes de conectar lámparas reales, prueba las salidas con cargas '
            'de banco. El optoacoplador aísla la señal, pero no sustituye '
            'contactores, protecciones eléctricas ni el enclavamiento físico.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final TrafficControllerStatus? status;
  final String message;
  const _StatusBanner({required this.status, required this.message});

  @override
  Widget build(BuildContext context) {
    final healthy =
        status != null && status!.fault.isEmpty && !status!.emergencyAllRed;
    final color = healthy ? Colors.green : Colors.orange;
    return Card(
      color: color.withValues(alpha: .12),
      child: ListTile(
        leading: Icon(
          healthy ? Icons.check_circle_outline : Icons.warning_amber,
          color: color,
          size: 38,
        ),
        title: Text(status == null ? 'Sin conexión' : status!.mode),
        subtitle: Text(message),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final TrafficControllerNodeStatus? node;
  final String fallbackName;
  const _SignalCard({required this.node, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final color = switch (node?.color) {
      TrafficLightColor.green => Colors.green,
      TrafficLightColor.yellow => Colors.amber,
      TrafficLightColor.red => Colors.red,
      _ => Colors.grey,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(Icons.circle, color: color, size: 54),
            const SizedBox(height: 6),
            Text(
              node?.name ?? fallbackName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              node == null
                  ? '—'
                  : '${node!.remainingSeconds} s · '
                        '${node!.online ? 'en línea' : 'sin enlace'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementEditor extends StatelessWidget {
  final String title;
  final TextEditingController name, green, yellow, allRed;
  const _MovementEditor({
    required this.title,
    required this.name,
    required this.green,
    required this.yellow,
    required this.allRed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Nombre de calle o movimiento',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _SecondsField(label: 'Verde', value: green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondsField(label: 'Ámbar', value: yellow),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondsField(label: 'Todo rojo', value: allRed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondsField extends StatelessWidget {
  final String label;
  final TextEditingController value;
  const _SecondsField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: value,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 's',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
