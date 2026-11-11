import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'thermal_printer_catalog_service.dart';

class ThermalPrinterDevice {
  final String name;
  final String address;
  final String systemName;
  final bool isManaged;

  const ThermalPrinterDevice({
    required this.name,
    required this.address,
    String? systemName,
    this.isManaged = false,
  }) : systemName = systemName ?? name;

  factory ThermalPrinterDevice.fromMap(Map<dynamic, dynamic> map) {
    final address = (map['address'] ?? '').toString().trim();
    final name = (map['name'] ?? '').toString().trim();
    return ThermalPrinterDevice(
      name: name.isEmpty ? 'Impresora Bluetooth' : name,
      address: address,
      systemName: name.isEmpty ? 'Impresora Bluetooth' : name,
    );
  }

  ThermalPrinterDevice withManagedName(String managedName) {
    return ThermalPrinterDevice(
      name: managedName,
      address: address,
      systemName: systemName,
      isManaged: true,
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

  /// ESC/POS: margen izquierdo en cero y área imprimible de 576 puntos.
  /// 576 puntos equivalen a 48 caracteres con la fuente A de una impresora
  /// térmica de 80 mm a 203 dpi.
  static const List<int> escPos80mmPrintArea = <int>[
    0x1D, 0x4C, 0x00, 0x00, // GS L: margen izquierdo = 0.
    0x1D, 0x57, 0x40, 0x02, // GS W: ancho imprimible = 576 puntos.
  ];

  static bool get supportsBluetoothPrinting {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<List<ThermalPrinterDevice>> getBondedPrinters({
    bool resolveManagedNames = true,
  }) async {
    if (!supportsBluetoothPrinting) return const <ThermalPrinterDevice>[];

    final rawDevices = await _runWithPermissionRetry<List<dynamic>>(() async {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getBondedPrinters',
      );
      return result ?? const <dynamic>[];
    });

    final devices = rawDevices
        .whereType<Map<dynamic, dynamic>>()
        .map(ThermalPrinterDevice.fromMap)
        .where((device) => device.address.isNotEmpty)
        .toList(growable: false);

    if (!resolveManagedNames || devices.isEmpty) return devices;

    try {
      final aliases = await ThermalPrinterCatalogService.aliasesByMac();
      return devices
          .map((device) {
            final alias =
                aliases[ThermalPrinterCatalogService.normalizeMac(
                  device.address,
                )];
            return alias == null
                ? device
                : device.withManagedName(alias.displayName);
          })
          .toList(growable: false);
    } catch (_) {
      // La impresión nunca debe bloquearse si el catálogo remoto no responde.
      return devices;
    }
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
