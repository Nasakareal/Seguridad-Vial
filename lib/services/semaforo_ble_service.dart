import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class SemaforoBleService {
  static const serviceUuid = '7a260001-4d2d-4c26-9a10-534547564941';
  static const rxUuid = '7a260002-4d2d-4c26-9a10-534547564941';
  static const txUuid = '7a260003-4d2d-4c26-9a10-534547564941';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  StreamSubscription<List<int>>? _notifications;
  final _messages = StreamController<String>.broadcast();

  Stream<String> get messages => _messages.stream;
  String? get deviceName => _device?.platformName;
  bool get connected => _rx != null && _device != null;

  Future<String> connect() async {
    await disconnect();
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (await FlutterBluePlus.isSupported == false) {
      throw Exception('Este teléfono no admite Bluetooth LE.');
    }
    final state = await FlutterBluePlus.adapterState
        .where((value) => value != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5));
    if (state != BluetoothAdapterState.on) {
      throw Exception('Enciende Bluetooth y vuelve a tocar Buscar Heltec.');
    }

    final found = Completer<BluetoothDevice>();
    late StreamSubscription<List<ScanResult>> scanSubscription;
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final name = result.device.platformName;
        if (name.startsWith('SV-MOVIL-')) {
          if (!found.isCompleted) found.complete(result.device);
          break;
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 12),
      );
      _device = await found.future.timeout(
        const Duration(seconds: 13),
        onTimeout: () => throw Exception(
          'No encontré SV-MOVIL. Verifica que el Heltec tenga la pantalla encendida.',
        ),
      );
    } finally {
      await FlutterBluePlus.stopScan();
      await scanSubscription.cancel();
    }

    await _device!.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 12),
    );
    final services = await _device!.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() != serviceUuid) continue;
      for (final characteristic in service.characteristics) {
        final uuid = characteristic.uuid.toString().toLowerCase();
        if (uuid == rxUuid) _rx = characteristic;
        if (uuid == txUuid) {
          await characteristic.setNotifyValue(true);
          _notifications = characteristic.onValueReceived.listen((bytes) {
            final text = utf8.decode(bytes, allowMalformed: true).trim();
            if (text.isNotEmpty) _messages.add(text);
          });
        }
      }
    }
    if (_rx == null || _notifications == null) {
      await disconnect();
      throw Exception(
        'El Heltec no tiene cargado el gateway Bluetooth actualizado.',
      );
    }
    return sendAndWait('STATUS', const ['GW_STATUS|']);
  }

  Future<String> testLink() => sendAndWait('LINK', const [
    'LINK_ACK|',
    'REJECT|',
  ], timeout: const Duration(seconds: 8));

  Future<String> requestPriority(String route, int stage, int seconds) =>
      sendAndWait('PRIORITY|$route|$stage|$seconds', const [
        'PRIORITY_ACK|',
        'REJECT|',
      ], timeout: const Duration(seconds: 10));

  Future<String> clearPriority(String route) => sendAndWait(
    'CLEAR|$route',
    const ['PRIORITY_ACK|', 'REJECT|'],
    timeout: const Duration(seconds: 10),
  );

  Future<String> queryConfiguration(String route) => sendAndWait(
    'CONFIG|$route',
    const ['CONFIG_ACK|', 'REJECT|'],
    timeout: const Duration(seconds: 10),
  );

  Future<String> sendAndWait(
    String command,
    List<String> prefixes, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final characteristic = _rx;
    if (characteristic == null) {
      throw Exception('Primero conecta el Heltec móvil.');
    }
    final response = messages.firstWhere(
      (value) => prefixes.any(value.startsWith),
    );
    await characteristic.write(utf8.encode(command), withoutResponse: true);
    return response.timeout(
      timeout,
      onTimeout: () =>
          throw Exception('Sin respuesta confirmada del enlace LoRa.'),
    );
  }

  Future<void> disconnect() async {
    await _notifications?.cancel();
    _notifications = null;
    _rx = null;
    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
  }
}
