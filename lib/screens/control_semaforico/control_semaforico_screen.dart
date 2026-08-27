import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/semaforo_priority.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/semaforo_ble_service.dart';
import '../../services/semaforo_priority_service.dart';

class ControlSemaforicoScreen extends StatefulWidget {
  const ControlSemaforicoScreen({super.key});

  @override
  State<ControlSemaforicoScreen> createState() =>
      _ControlSemaforicoScreenState();
}

class _ControlSemaforicoScreenState extends State<ControlSemaforicoScreen> {
  final gateway = SemaforoBleService();
  final catalog = SemaforoPriorityService();
  final biometrics = BiometricAuthService();
  final reason = TextEditingController();
  final search = TextEditingController();
  List<SemaforoNode> nodes = const [];
  SemaforoNode? selectedNode;
  bool catalogBusy = false;
  String catalogStatus = 'Cargando catálogo de cruceros…';
  int seconds = 90;
  int targetStage = 1;
  bool busy = false;
  bool connected = false;
  bool loraLinked = false;
  bool priorityActive = false;
  Timer? priorityTimer;
  String status = 'Conecta el Heltec móvil por Bluetooth para iniciar.';
  String nodeConfiguration = '';

  String get selectedRoute => selectedNode?.route ?? '';

  @override
  void initState() {
    super.initState();
    loadCatalog();
  }

  @override
  void dispose() {
    priorityTimer?.cancel();
    reason.dispose();
    search.dispose();
    gateway.dispose();
    super.dispose();
  }

  Future<void> loadCatalog({String query = ''}) async {
    setState(() {
      catalogBusy = true;
      catalogStatus = 'Consultando catálogo institucional…';
    });
    try {
      final result = await catalog.listNodes(query: query);
      if (!mounted) return;
      final previousRoute = selectedNode?.route;
      SemaforoNode? selected;
      if (result.isNotEmpty) {
        selected = result.firstWhere(
          (node) => node.route == previousRoute,
          orElse: () => result.first,
        );
      }
      setState(() {
        nodes = result;
        selectedNode = selected;
        catalogStatus = result.isEmpty
            ? 'No hay cruceros que coincidan con la búsqueda.'
            : '${result.length} crucero(s) registrado(s).';
      });
    } catch (e) {
      if (!mounted) return;
      const fallback = SemaforoNode(
        id: 'FBF61B44',
        name: 'SALIDA QUIROGA',
        location: 'Morelia, Michoacán',
        route: 'QUIROGA_SALIDA',
        primaryStreet: 'SALIDA A QUIROGA',
        secondaryStreet: 'CRUCE TRANSVERSAL',
        activePlan: 'LOCAL CC1',
        scheduleStart: '18:30',
        scheduleEnd: '19:30',
        scheduleStatus: 'SAFE',
        online: false,
      );
      setState(() {
        nodes = const [fallback];
        selectedNode = fallback;
        catalogStatus =
            'Catálogo sin conexión; se conserva el crucero de banco local.';
      });
    } finally {
      if (mounted) setState(() => catalogBusy = false);
    }
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> connect() async {
    setState(() {
      busy = true;
      status = 'Buscando SV-MOVIL por Bluetooth…';
    });
    try {
      final response = await gateway.connect();
      if (!mounted) return;
      setState(() {
        connected = true;
        status = 'Bluetooth conectado: ${gateway.deviceName}\n$response';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          connected = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> testLink() async {
    setState(() {
      busy = true;
      status = 'Enviando prueba al nodo fijo por LoRa…';
    });
    try {
      final response = await gateway.testLink();
      if (!mounted) return;
      final ok = response.startsWith('LINK_ACK|');
      setState(() {
        loraLinked = ok;
        status = response;
      });
      message(ok ? 'Enlace Bluetooth + LoRa confirmado.' : response);
    } catch (e) {
      if (mounted) {
        setState(() {
          loraLinked = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestPriority() async {
    if (!loraLinked) return message('Primero confirma el enlace LoRa.');
    if (selectedNode == null) return message('Selecciona un crucero.');
    if (reason.text.trim().length < 8) {
      return message('Escribe un motivo operativo de al menos 8 caracteres.');
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar prioridad'),
        content: Text(
          '${selectedNode!.name}\n${selectedNode!.streets}\n'
          '${_stageLabel(targetStage)}\n'
          'Máximo $seconds segundos. Se exige confirmación real del controlador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final auth = await biometrics.verify(
      localizedReason: 'Autoriza prioridad semafórica',
    );
    if (!auth.allowed) return message(auth.message);
    setState(() {
      busy = true;
      status = 'Esperando confirmación del nodo fijo…';
    });
    try {
      final response = await gateway.requestPriority(
        selectedRoute,
        targetStage,
        seconds,
      );
      if (!mounted) return;
      final applied =
          response.startsWith('PRIORITY_ACK|') &&
          (response.contains('mode=PRIORIDAD CC3') ||
              response.contains('mode=PRIORIDAD BANCO S'));
      setState(() {
        priorityActive = applied;
        status = response;
      });
      if (applied) {
        priorityTimer?.cancel();
        priorityTimer = Timer(Duration(seconds: seconds), () {
          if (!mounted) return;
          setState(() {
            priorityActive = false;
            status =
                'Ventana de prioridad finalizada. El nodo fijo restauró automáticamente el ciclo local.';
          });
        });
      }
      message(applied ? 'Prioridad activa y confirmada.' : _explain(response));
    } catch (e) {
      if (mounted) {
        setState(() {
          priorityActive = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> queryConfiguration() async {
    if (!loraLinked) return message('Primero confirma el enlace LoRa.');
    if (selectedNode == null) return message('Selecciona un crucero.');
    setState(() {
      busy = true;
      status = 'Consultando identidad y programación del nodo fijo…';
    });
    try {
      final response = await gateway.queryConfiguration(selectedRoute);
      if (!mounted) return;
      final ok = response.startsWith('CONFIG_ACK|');
      if (ok) {
        final configuration = _parseConfiguration(response);
        try {
          final synced = await catalog.syncNodeConfiguration(
            configuration: configuration,
            catalogNode: selectedNode,
          );
          if (mounted) {
            setState(() {
              nodes = [synced, ...nodes.where((node) => node.id != synced.id)];
              selectedNode = synced;
              catalogStatus = 'Catálogo actualizado desde el nodo por LoRa.';
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              catalogStatus =
                  'Configuración recibida; quedó pendiente sincronizarla con el servidor.';
            });
          }
        }
      }
      setState(() {
        nodeConfiguration = ok ? response : '';
        status = response;
      });
      message(
        ok ? 'Configuración recibida desde el semáforo.' : _explain(response),
      );
    } catch (e) {
      if (mounted) {
        setState(() => status = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _configValue(String key) {
    for (final field in nodeConfiguration.split('|')) {
      if (field.startsWith('$key=')) return field.substring(key.length + 1);
    }
    return '—';
  }

  Map<String, String> _parseConfiguration(String response) {
    final result = <String, String>{};
    for (final field in response.split('|').skip(1)) {
      final separator = field.indexOf('=');
      if (separator > 0) {
        result[field.substring(0, separator)] = field.substring(separator + 1);
      }
    }
    return result;
  }

  Future<void> clearPriority() async {
    setState(() {
      busy = true;
      status = 'Solicitando regreso al ciclo local…';
    });
    try {
      final response = await gateway.clearPriority(selectedRoute);
      if (!mounted) return;
      final cleared =
          response.startsWith('PRIORITY_ACK|') &&
          response.contains('mode=LOCAL CC1');
      setState(() {
        priorityActive = !cleared;
        status = response;
      });
      if (cleared) priorityTimer?.cancel();
      message(
        cleared ? 'Ciclo local restaurado y confirmado.' : _explain(response),
      );
    } catch (e) {
      if (mounted) {
        setState(() => status = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _explain(String response) {
    if (response.contains('KEY_MISSING')) {
      return 'El enlace funciona, pero falta cargar la misma llave en ambos Heltec por USB.';
    }
    if (response.contains('mode=LOCAL CC1')) {
      return 'El nodo respondió, pero no aplicó prioridad: la portadora GIS/MCP aún no está presente.';
    }
    return 'La orden no fue confirmada como aplicada: $response';
  }

  String _stageLabel(int stage) => switch (stage) {
    1 => 'Movimiento A · etapa 1 · F1/F2 verde, F3/F4 rojo',
    2 => 'Movimiento B · etapa 2 · F2/F3 verde, F1/F4 rojo',
    4 => 'Movimiento C · etapa 4 · F4 verde, F1/F2/F3 rojo',
    _ => 'Etapa $stage',
  };

  @override
  Widget build(BuildContext context) {
    final color = priorityActive
        ? Colors.green
        : (loraLinked ? Colors.blue : Colors.orange);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prioridad semafórica · enlace directo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: color.withValues(alpha: .12),
            child: ListTile(
              leading: Icon(
                priorityActive
                    ? Icons.check_circle
                    : Icons.settings_input_antenna,
                color: color,
                size: 38,
              ),
              title: Text(
                priorityActive
                    ? 'Prioridad confirmada'
                    : connected
                    ? 'Heltec móvil conectado'
                    : 'Gateway desconectado',
              ),
              subtitle: Text(status),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : connect,
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(
              connected ? 'Reconectar Heltec móvil' : 'Buscar Heltec móvil',
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy || !connected ? null : testLink,
            icon: const Icon(Icons.cell_tower),
            label: const Text('Probar enlace con semáforo'),
          ),
          OutlinedButton.icon(
            onPressed: busy || !loraLinked ? null : queryConfiguration,
            icon: const Icon(Icons.info_outline),
            label: const Text('Consultar cruce y programación'),
          ),
          if (nodeConfiguration.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _configValue('name'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('Ruta: ${_configValue('route')}'),
                    Text('Principal: ${_configValue('street1')}'),
                    Text('Transversal: ${_configValue('street2')}'),
                    Text(
                      'Plan horario: ${_configValue('start')}–${_configValue('end')} · ${_configValue('schedule')}',
                    ),
                    Text('Nodo: ${_configValue('node')}'),
                  ],
                ),
              ),
            ),
          const Divider(height: 32),
          Text(
            'Crucero destinatario',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: search,
            enabled: !catalogBusy,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => loadCatalog(query: value),
            decoration: InputDecoration(
              labelText: 'Buscar por calle, nombre, ruta o nodo',
              border: OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Buscar todos',
                onPressed: catalogBusy
                    ? null
                    : () => loadCatalog(query: search.text),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<SemaforoNode>(
            value: selectedNode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Crucero registrado',
              border: OutlineInputBorder(),
            ),
            items: nodes
                .map(
                  (node) => DropdownMenuItem(
                    value: node,
                    child: Text(
                      node.streets.isEmpty
                          ? '${node.name} · ${node.route}'
                          : '${node.name} · ${node.streets}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (value) => setState(() {
                    selectedNode = value;
                    nodeConfiguration = '';
                  }),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                selectedNode?.online == true ? Icons.cloud_done : Icons.cloud,
                size: 18,
                color: selectedNode?.online == true
                    ? Colors.green
                    : Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$catalogStatus  Ruta LoRa: ${selectedRoute.isEmpty ? '—' : selectedRoute}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: targetStage,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Movimiento que recibirá paso prioritario',
              border: OutlineInputBorder(),
            ),
            items: [1, 2, 4]
                .map(
                  (stage) => DropdownMenuItem(
                    value: stage,
                    child: Text(_stageLabel(stage)),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (value) => setState(() => targetStage = value ?? 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Los nombres A/B/C son provisionales hasta identificar en banco qué calle y sentido corresponde a cada salida.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 90, label: Text('90 s')),
              ButtonSegment(value: 250, label: Text('250 s')),
              ButtonSegment(value: 500, label: Text('500 s')),
            ],
            selected: {seconds},
            onSelectionChanged: busy
                ? null
                : (value) => setState(() => seconds = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            enabled: !busy,
            maxLength: 160,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo operativo',
              border: OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: busy || !loraLinked || priorityActive
                ? null
                : requestPriority,
            icon: const Icon(Icons.emergency_share),
            label: Text(
              busy ? 'Esperando respuesta…' : 'Solicitar paso prioritario',
            ),
          ),
          if (connected && loraLinked)
            OutlinedButton.icon(
              onPressed: busy ? null : clearPriority,
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Cancelar prioridad antes de tiempo'),
            ),
          const SizedBox(height: 8),
          const Text(
            'El regreso al ciclo normal es automático al vencer la ventana. '
            'En el C26 antiguo, 500 s usa tiempos de etapa de hasta 250 s por el límite de un byte.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          const Text(
            'No usa Internet ni rutas HTTP. Bluetooth llega al Heltec móvil y LoRa al nodo fijo. Sin ACK de modo PRIORIDAD CC3, la app nunca muestra éxito.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
