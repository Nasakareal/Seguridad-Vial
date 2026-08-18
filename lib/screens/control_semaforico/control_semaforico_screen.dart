import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/biometric_auth_service.dart';
import '../../services/semaforo_ble_service.dart';

class ControlSemaforicoScreen extends StatefulWidget {
  const ControlSemaforicoScreen({super.key});

  @override
  State<ControlSemaforicoScreen> createState() =>
      _ControlSemaforicoScreenState();
}

class _ControlSemaforicoScreenState extends State<ControlSemaforicoScreen> {
  final gateway = SemaforoBleService();
  final biometrics = BiometricAuthService();
  final reason = TextEditingController();
  final route = TextEditingController(text: 'QUIROGA_SALIDA');
  int seconds = 90;
  int targetStage = 1;
  bool busy = false;
  bool connected = false;
  bool loraLinked = false;
  bool priorityActive = false;
  Timer? priorityTimer;
  String status = 'Conecta el Heltec móvil por Bluetooth para iniciar.';

  @override
  void dispose() {
    priorityTimer?.cancel();
    reason.dispose();
    route.dispose();
    gateway.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
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
      if (mounted)
        setState(() {
          connected = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
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
      if (mounted)
        setState(() {
          loraLinked = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestPriority() async {
    if (!loraLinked) return message('Primero confirma el enlace LoRa.');
    if (reason.text.trim().length < 8)
      return message('Escribe un motivo operativo de al menos 8 caracteres.');
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar prioridad'),
        content: Text(
          '${route.text}\n${_stageLabel(targetStage)}\n'
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
        route.text.trim().toUpperCase(),
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
      if (mounted)
        setState(() {
          priorityActive = false;
          status = e.toString().replaceFirst('Exception: ', '');
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clearPriority() async {
    setState(() {
      busy = true;
      status = 'Solicitando regreso al ciclo local…';
    });
    try {
      final response = await gateway.clearPriority(
        route.text.trim().toUpperCase(),
      );
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
      if (mounted)
        setState(() => status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _explain(String response) {
    if (response.contains('KEY_MISSING'))
      return 'El enlace funciona, pero falta cargar la misma llave en ambos Heltec por USB.';
    if (response.contains('mode=LOCAL CC1'))
      return 'El nodo respondió, pero no aplicó prioridad: la portadora GIS/MCP aún no está presente.';
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
          const Divider(height: 32),
          TextField(
            controller: route,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Ruta / crucero',
              border: OutlineInputBorder(),
            ),
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
