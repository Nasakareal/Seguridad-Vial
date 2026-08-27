import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/actividad.dart';
import '../../services/browser_print_service.dart';
import '../../services/thermal_printer_service.dart';

const String actividadCorralonAvisoSiniestros =
    'Puede recoger su vehículo en la Unidad de Atención a Siniestros, '
    'ubicada en Periférico Independencia #5000, col. Sentimientos de la '
    'Nación, Morelia, Michoacán, en un horario de 9:00 a. m. a 3:00 p. m., '
    'de lunes a viernes.';

class ActividadCorralonTicketScreen extends StatefulWidget {
  final Actividad actividad;

  const ActividadCorralonTicketScreen({super.key, required this.actividad});

  @override
  State<ActividadCorralonTicketScreen> createState() =>
      _ActividadCorralonTicketScreenState();
}

class _ActividadCorralonTicketScreenState
    extends State<ActividadCorralonTicketScreen> {
  bool _printing = false;

  Future<void> _print() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      if (!ThermalPrinterService.supportsBluetoothPrinting) {
        final ok = await printCurrentBrowserPage();
        if (!ok && mounted) {
          _snack('La impresión térmica Bluetooth está disponible en Android.');
        }
        return;
      }

      final paper = await _selectPaper();
      if (!mounted || paper == null) return;
      final printers = await ThermalPrinterService.getBondedPrinters();
      if (!mounted) return;
      if (printers.isEmpty) {
        _snack('Empareja una impresora Bluetooth e intenta de nuevo.');
        return;
      }
      final printer = printers.length == 1
          ? printers.first
          : await _selectPrinter(printers);
      if (!mounted || printer == null) return;

      await ThermalPrinterService.printEscPos(
        address: printer.address,
        bytes: _buildEscPos(widget.actividad, paper.columns),
      );
      if (mounted) _snack('Notificación enviada a ${printer.name}.');
    } on ThermalPrinterException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('No se pudo imprimir: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<_Paper?> _selectPaper() {
    return showModalBottomSheet<_Paper>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Tamaño del ticket',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final paper in _Paper.values)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(paper.label),
                onTap: () => Navigator.pop(context, paper),
              ),
          ],
        ),
      ),
    );
  }

  Future<ThermalPrinterDevice?> _selectPrinter(
    List<ThermalPrinterDevice> printers,
  ) {
    return showModalBottomSheet<ThermalPrinterDevice>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Selecciona impresora',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final printer in printers)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(printer.name),
                subtitle: Text(printer.address),
                onTap: () => Navigator.pop(context, printer),
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final actividad = widget.actividad;
    final vehiculo = actividad.vehiculos.isEmpty
        ? null
        : actividad.vehiculos.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Notificación de infracción'),
        actions: [
          IconButton(
            tooltip: 'Imprimir ticket',
            onPressed: _printing ? null : _print,
            icon: _printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 18),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SECRETARÍA DE SEGURIDAD PÚBLICA',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Text(
                    'COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'BOLETA DE NOTIFICACIÓN\nAL CORRALÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const Divider(height: 28),
                  _pair('Folio', 'ACT-${actividad.id}'),
                  _pair(
                    'Motivo',
                    actividad.subcategoria?.nombre ?? 'Al corralón',
                  ),
                  _pair(
                    'Fecha y hora',
                    _join([actividad.fecha, actividad.hora]),
                  ),
                  _pair('Lugar', _join([actividad.lugar, actividad.municipio])),
                  const Divider(height: 28),
                  const Text(
                    'INFRACCIÓN',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  for (final item in actividad.infraccionesActividad) ...[
                    Text(
                      item.display,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if ((item.fundamentoLegal ?? '').trim().isNotEmpty)
                      Text(item.fundamentoLegal!.trim()),
                    Text('Sanción: ${item.sancionResumen}'),
                    const SizedBox(height: 10),
                  ],
                  const Divider(height: 28),
                  const Text(
                    'VEHÍCULO',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  _pair(
                    'Descripción',
                    _join([
                      vehiculo?.marca,
                      vehiculo?.linea,
                      vehiculo?.modelo,
                      vehiculo?.tipo,
                      vehiculo?.color,
                    ]),
                  ),
                  _pair('Placas', vehiculo?.placas ?? 'Sin placas'),
                  _pair('Serie', vehiculo?.serie ?? 'No capturada'),
                  _pair('Corralón', vehiculo?.corralon ?? 'No capturado'),
                  const Divider(height: 28),
                  if (actividad.creadaPorUnidadSiniestros) ...[
                    const Text(
                      'INFORMACIÓN PARA RECOGER EL VEHÍCULO',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(actividadCorralonAvisoSiniestros),
                    const Divider(height: 28),
                  ],
                  _pair('Agente', actividad.nombre),
                  const SizedBox(height: 24),
                  const Text(
                    'MANIFESTACIÓN DE INCONFORMIDAD',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'En caso de inconformidad, la persona infractora podrá manifestarla en este espacio:',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Manifiesto inconformidad:   SÍ [   ]    NO [   ]',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  const Text('________________________________________'),
                  const SizedBox(height: 18),
                  const Text('________________________________________'),
                  const SizedBox(height: 32),
                  const Text(
                    '____________________________',
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Firma de la persona infractora',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _printing ? null : _print,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimir notificación'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pair(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value.trim().isEmpty ? 'No capturado' : value),
          ],
        ),
      ),
    );
  }
}

enum _Paper {
  paper80('80 mm', 48),
  paper58('58 mm', 32);

  final String label;
  final int columns;
  const _Paper(this.label, this.columns);
}

String _join(Iterable<String?> values) {
  return values
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .join(' ');
}

Uint8List _buildEscPos(Actividad actividad, int width) {
  final vehicle = actividad.vehiculos.isEmpty
      ? null
      : actividad.vehiculos.first;
  final lines = <String>[
    ..._center('SECRETARIA DE SEGURIDAD PUBLICA', width),
    ..._center('AGRUPAMIENTO DE SEGURIDAD VIAL', width),
    '',
    ..._center('BOLETA DE NOTIFICACION', width),
    ..._center('AL CORRALON', width),
    _repeat('-', width),
    ..._wrap('Folio: ACT-${actividad.id}', width),
    ..._wrap(
      'Motivo: ${actividad.subcategoria?.nombre ?? 'AL CORRALON'}',
      width,
    ),
    ..._wrap('Fecha: ${_join([actividad.fecha, actividad.hora])}', width),
    ..._wrap('Lugar: ${_join([actividad.lugar, actividad.municipio])}', width),
    _repeat('-', width),
    ..._center('INFRACCION', width),
    for (final item in actividad.infraccionesActividad) ...[
      ..._wrap(item.display, width),
      ..._wrap(
        'Fundamento: ${item.fundamentoLegal ?? item.referenciaLegalCorta ?? 'No capturado'}',
        width,
      ),
      ..._wrap('Sancion: ${item.sancionResumen}', width),
      '',
    ],
    _repeat('-', width),
    ..._center('VEHICULO', width),
    ..._wrap(
      'Descripcion: ${_join([vehicle?.marca, vehicle?.linea, vehicle?.modelo, vehicle?.tipo, vehicle?.color])}',
      width,
    ),
    ..._wrap('Placas: ${vehicle?.placas ?? 'SIN PLACAS'}', width),
    ..._wrap('Serie: ${vehicle?.serie ?? 'NO CAPTURADA'}', width),
    ..._wrap('Corralon: ${vehicle?.corralon ?? 'NO CAPTURADO'}', width),
    _repeat('-', width),
    if (actividad.creadaPorUnidadSiniestros) ...[
      ..._center('INFORMACION PARA RECOGER EL VEHICULO', width),
      ..._wrap(actividadCorralonAvisoSiniestros, width),
      _repeat('-', width),
    ],
    ..._wrap('Agente: ${actividad.nombre}', width),
    '',
    ..._center('MANIFESTACION DE INCONFORMIDAD', width),
    ..._wrap(
      'En caso de inconformidad, la persona infractora podra manifestarla en este espacio:',
      width,
    ),
    ..._wrap('Manifiesto inconformidad: SI [ ]  NO [ ]', width),
    '',
    _repeat('_', width),
    '',
    _repeat('_', width),
    '',
    '',
    _repeat('_', width),
    ..._center('FIRMA DE LA PERSONA INFRACTORA', width),
  ];
  final text = '${lines.join('\r\n')}\r\n\r\n\r\n\r\n\r\n';
  return Uint8List.fromList(<int>[
    0x1B,
    0x40,
    0x1B,
    0x21,
    0x00,
    0x1B,
    0x61,
    0x00,
    ..._ascii(text).codeUnits,
  ]);
}

List<String> _center(String value, int width) {
  return _wrap(value, width).map((line) {
    final spaces = ((width - line.length) ~/ 2).clamp(0, width).toInt();
    return '${_repeat(' ', spaces)}$line';
  }).toList();
}

List<String> _wrap(String value, int width) {
  final words = _ascii(value).replaceAll(RegExp(r'\s+'), ' ').trim().split(' ');
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    if (word.isEmpty) continue;
    if (current.isEmpty) {
      current = word;
    } else if (current.length + word.length + 1 <= width) {
      current = '$current $word';
    } else {
      lines.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines.isEmpty ? <String>[''] : lines;
}

String _ascii(String value) {
  const accents = 'ÁÉÍÓÚÜÑáéíóúüñ';
  const plain = 'AEIOUUNaeiouun';
  var result = value;
  for (var index = 0; index < accents.length; index += 1) {
    result = result.replaceAll(accents[index], plain[index]);
  }
  return result.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '');
}

String _repeat(String value, int count) {
  return List<String>.filled(count.clamp(0, 200).toInt(), value).join();
}
