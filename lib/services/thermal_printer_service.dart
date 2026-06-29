import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ThermalPrinterDevice {
  final String name;
  final String address;

  const ThermalPrinterDevice({required this.name, required this.address});

  factory ThermalPrinterDevice.fromMap(Map<dynamic, dynamic> map) {
    final address = (map['address'] ?? '').toString().trim();
    final name = (map['name'] ?? '').toString().trim();
    return ThermalPrinterDevice(
      name: name.isEmpty ? 'Impresora Bluetooth' : name,
      address: address,
    );
  }
}

class ThermalPrinterException implements Exception {
  final String message;

  const ThermalPrinterException(this.message);

  factory ThermalPrinterException.fromPlatform(PlatformException exception) {
    final message = exception.message?.trim();
    switch (exception.code) {
      case 'PERMISSION_DENIED':
        return const ThermalPrinterException(
          'Activa el permiso de Bluetooth para poder imprimir la boleta.',
        );
      case 'NO_ADAPTER':
        return const ThermalPrinterException(
          'Este dispositivo no reporta Bluetooth disponible.',
        );
      case 'BLUETOOTH_DISABLED':
        return const ThermalPrinterException(
          'Activa Bluetooth y vuelve a intentar la impresion.',
        );
      case 'DEVICE_NOT_FOUND':
        return const ThermalPrinterException(
          'No encontre esa impresora entre los dispositivos emparejados.',
        );
      case 'INVALID_ARGUMENTS':
        return const ThermalPrinterException(
          'Faltan datos para mandar la boleta a la impresora.',
        );
      case 'PRINT_FAILED':
        return ThermalPrinterException(
          message == null || message.isEmpty
              ? 'No se pudo mandar la boleta a la impresora.'
              : message,
        );
      default:
        return ThermalPrinterException(
          message == null || message.isEmpty
              ? 'No se pudo completar la impresion Bluetooth.'
              : message,
        );
    }
  }

  @override
  String toString() => message;
}

class ThermalPrinterService {
  static const MethodChannel _channel = MethodChannel(
    'seguridad_vial_app/thermal_printer',
  );

  static bool get supportsBluetoothPrinting {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<List<ThermalPrinterDevice>> getBondedPrinters() async {
    if (!supportsBluetoothPrinting) return const <ThermalPrinterDevice>[];

    final rawDevices = await _runWithPermissionRetry<List<dynamic>>(() async {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getBondedPrinters',
      );
      return result ?? const <dynamic>[];
    });

    return rawDevices
        .whereType<Map<dynamic, dynamic>>()
        .map(ThermalPrinterDevice.fromMap)
        .where((device) => device.address.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> printEscPos({
    required String address,
    required Uint8List bytes,
  }) async {
    if (!supportsBluetoothPrinting) {
      throw const ThermalPrinterException(
        'La impresion termica Bluetooth esta disponible desde Android.',
      );
    }

    await _runWithPermissionRetry<void>(() async {
      await _channel.invokeMethod<void>('printEscPos', <String, dynamic>{
        'address': address,
        'bytes': bytes,
      });
    });
  }

  static Future<T> _runWithPermissionRetry<T>(
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on PlatformException catch (exception) {
      if (exception.code != 'PERMISSION_DENIED') {
        throw ThermalPrinterException.fromPlatform(exception);
      }

      final status = await Permission.bluetoothConnect.request();
      if (!status.isGranted) {
        throw const ThermalPrinterException(
          'Activa el permiso de Bluetooth para poder imprimir la boleta.',
        );
      }

      try {
        return await action();
      } on PlatformException catch (retryException) {
        throw ThermalPrinterException.fromPlatform(retryException);
      }
    }
  }
}
