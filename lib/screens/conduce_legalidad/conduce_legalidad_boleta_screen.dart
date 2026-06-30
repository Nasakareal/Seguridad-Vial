import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/conduce_legalidad.dart';
import '../../services/browser_print_service.dart';
import '../../services/conduce_legalidad_service.dart';
import '../../services/thermal_printer_service.dart';

class ConduceLegalidadBoletaScreen extends StatefulWidget {
  final ConduceLegalidadOperativo? initialOperativo;
  final ConduceLegalidadCaptura? initialCaptura;
  final int? operativoId;
  final int? capturaId;
  final bool preview;

  const ConduceLegalidadBoletaScreen({
    super.key,
    this.initialOperativo,
    this.initialCaptura,
    this.operativoId,
    this.capturaId,
    this.preview = false,
  });

  @override
  State<ConduceLegalidadBoletaScreen> createState() =>
      _ConduceLegalidadBoletaScreenState();
}

class _ConduceLegalidadBoletaScreenState
    extends State<ConduceLegalidadBoletaScreen> {
  bool _loading = true;
  String? _error;
  ConduceLegalidadOperativo? _operativo;
  ConduceLegalidadCaptura? _captura;
  bool _usingPreview = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final initialOperativo = widget.initialOperativo;
    final initialCaptura = widget.initialCaptura;
    if (initialOperativo != null && initialCaptura != null) {
      setState(() {
        _operativo = initialOperativo;
        _captura = initialCaptura;
        _usingPreview = false;
        _loading = false;
      });
      return;
    }

    final operativoId = widget.operativoId;
    final capturaId = widget.capturaId;
    if (widget.preview || operativoId == null || capturaId == null) {
      final sample = _BoletaPreviewData.create();
      setState(() {
        _operativo = sample.operativo;
        _captura = sample.captura;
        _usingPreview = true;
        _loading = false;
      });
      return;
    }

    try {
      final operativo = await ConduceLegalidadService.fetchOperativo(
        operativoId,
      );
      final captura = operativo.capturas
          .where((item) => item.id == capturaId)
          .cast<ConduceLegalidadCaptura?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (!mounted) return;
      if (captura == null) {
        setState(() {
          _error = 'No se encontro la captura #$capturaId en el operativo.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _operativo = operativo;
        _captura = captura;
        _usingPreview = false;
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

  Future<void> _print() async {
    final operativo = _operativo;
    final captura = _captura;
    if (_printing || operativo == null || captura == null) return;

    setState(() => _printing = true);
    try {
      if (ThermalPrinterService.supportsBluetoothPrinting) {
        final printer = await _selectBondedPrinter();
        if (!mounted || printer == null) return;

        await ThermalPrinterService.printEscPos(
          address: printer.address,
          bytes: _buildEscPosTicket(operativo, captura),
        );
        if (!mounted) return;

        _showSnackBar('Boleta enviada a ${printer.name}.');
        return;
      }

      final ok = await printCurrentBrowserPage();
      if (!ok && mounted) {
        _showSnackBar(
          'La impresion termica Bluetooth esta disponible desde la app Android.',
        );
      }
    } on ThermalPrinterException catch (e) {
      if (mounted) _showSnackBar(e.message);
    } catch (e) {
      if (mounted) _showSnackBar('No se pudo imprimir la boleta: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printTest() async {
    if (_printing) return;

    setState(() => _printing = true);
    try {
      if (!ThermalPrinterService.supportsBluetoothPrinting) {
        _showSnackBar(
          'La impresion termica Bluetooth esta disponible desde la app Android.',
        );
        return;
      }

      final printer = await _selectBondedPrinter();
      if (!mounted || printer == null) return;

      await ThermalPrinterService.printEscPos(
        address: printer.address,
        bytes: _buildEscPosTestTicket(),
      );
      if (!mounted) return;

      _showSnackBar('Prueba enviada a ${printer.name}.');
    } on ThermalPrinterException catch (e) {
      if (mounted) _showSnackBar(e.message);
    } catch (e) {
      if (mounted) _showSnackBar('No se pudo imprimir la prueba: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<ThermalPrinterDevice?> _selectBondedPrinter() async {
    final devices = await ThermalPrinterService.getBondedPrinters();
    if (!mounted) return null;

    if (devices.isEmpty) {
      _showSnackBar(
        'No encontre impresoras Bluetooth emparejadas. Empareja la impresora desde Android e intenta de nuevo.',
      );
      return null;
    }

    return _selectPrinter(devices);
  }

  Future<ThermalPrinterDevice?> _selectPrinter(
    List<ThermalPrinterDevice> devices,
  ) async {
    if (devices.length == 1) return devices.first;

    return showModalBottomSheet<ThermalPrinterDevice>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Selecciona impresora Bluetooth',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Usa una impresora termica ya emparejada.'),
              ),
              for (final device in devices)
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(device.name),
                  subtitle: Text(device.address),
                  onTap: () => Navigator.of(context).pop(device),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Boleta de infracción'),
        actions: [
          IconButton(
            tooltip: 'Imprimir',
            onPressed: _loading || _printing ? null : _print,
            icon: _printing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Prueba Bluetooth',
            onPressed: _printing ? null : _printTest,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BoletaStatusPanel(
            icon: Icons.error_outline,
            title: 'No se pudo cargar la boleta',
            message: _error!,
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    final operativo = _operativo;
    final captura = _captura;
    if (operativo == null || captura == null) {
      return const Center(child: Text('Boleta no disponible.'));
    }

    final vehiculos = captura.vehiculos.isEmpty
        ? <ConduceLegalidadVehiculo?>[null]
        : captura.vehiculos.cast<ConduceLegalidadVehiculo?>().toList();

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_usingPreview) ...[
            const _BoletaStatusPanel(
              icon: Icons.visibility_outlined,
              title: 'Previsualizacion local',
              message:
                  'Esta boleta usa datos de ejemplo. Desde una captura real se llenara con la informacion registrada.',
            ),
            const SizedBox(height: 14),
          ],
          Center(
            child: Column(
              children: [
                for (var i = 0; i < vehiculos.length; i++) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _BoletaPaper(
                      operativo: operativo,
                      captura: captura,
                      vehiculo: vehiculos[i],
                      persona: _personaFor(captura, i),
                      index: i,
                      total: vehiculos.length,
                      preview: _usingPreview,
                    ),
                  ),
                  if (i < vehiculos.length - 1) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ConduceLegalidadPersona? _personaFor(
    ConduceLegalidadCaptura captura,
    int index,
  ) {
    if (captura.personas.isEmpty) return null;
    if (captura.personas.length > index) return captura.personas[index];
    return captura.personas.first;
  }
}

class _BoletaPaper extends StatelessWidget {
  final ConduceLegalidadOperativo operativo;
  final ConduceLegalidadCaptura captura;
  final ConduceLegalidadVehiculo? vehiculo;
  final ConduceLegalidadPersona? persona;
  final int index;
  final int total;
  final bool preview;

  const _BoletaPaper({
    required this.operativo,
    required this.captura,
    required this.vehiculo,
    required this.persona,
    required this.index,
    required this.total,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = const TextStyle(
      color: Colors.black,
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.28,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: baseStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TicketCenter(
              children: [
                Text(
                  'SECRETARÍA DE SEGURIDAD PÚBLICA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                ),
                SizedBox(height: 8),
                Text(
                  'BOLETA DE NOTIFICACIÓN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  'OPERATIVO CONDUCE CON LEGALIDAD',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const _TicketDivider(),
            _TicketPair(label: 'Folio interno', value: _folio),
            _TicketPair(label: 'Municipio', value: _value(captura.municipio)),
            _TicketPair(label: 'Fecha', value: _value(captura.fecha)),
            _TicketPair(label: 'Hora', value: _value(captura.hora)),
            _TicketBlock(label: 'Lugar', value: _lugar),
            const _TicketDivider(),
            const _TicketSection('I. FUNDAMENTO JURÍDICO'),
            _TicketBlock(
              label: 'a) Artículo(s) que prevén la infracción',
              value: _fundamentoInfraccion,
            ),
            _TicketBlock(
              label: 'b) Artículo(s) que establecen la sanción',
              value: _fundamentoSancion,
            ),
            const _TicketDivider(),
            const _TicketSection('II. MOTIVACIÓN'),
            _TicketPair(label: 'Día', value: _value(captura.fecha)),
            _TicketPair(label: 'Hora', value: _value(captura.hora)),
            _TicketBlock(label: 'Lugar', value: _lugar),
            _TicketBlock(
              label: 'Descripción breve de la conducta',
              value: _conducta,
            ),
            const _TicketDivider(),
            const _TicketSection('PERSONA INFRACTORA'),
            _TicketPair(
              label: 'Nombre',
              value: _value(
                persona?.nombre,
                fallback: 'No presente o no proporcionado',
              ),
            ),
            _TicketBlock(
              label: 'Domicilio',
              value: _value(
                persona?.domicilio,
                fallback: 'No presente o no proporcionado',
              ),
            ),
            const _TicketDivider(),
            const _TicketSection('VEHÍCULO'),
            _TicketPair(
              label: 'Placas/permiso',
              value: _value(vehiculo?.placas, fallback: 'No capturado'),
            ),
            _TicketPair(
              label: 'Estado placas',
              value: _value(vehiculo?.estadoPlacas, fallback: 'No capturado'),
            ),
            _TicketBlock(label: 'Descripción', value: _vehiculoDescripcion),
            if (_mostrarInformacionLiberacion) ...[
              const _TicketDivider(),
              const _TicketSection('LIBERACIÓN DEL VEHÍCULO'),
              _TicketBlock(
                label: 'Trámite',
                value: _informacionLiberacionVehiculo,
              ),
            ],
            const _TicketDivider(),
            const _TicketSection('LICENCIA O PERMISO'),
            _TicketPair(
              label: 'Tipo',
              value: _value(persona?.tipoLicencia, fallback: 'No capturado'),
            ),
            _TicketPair(
              label: 'Número',
              value: _value(persona?.numeroLicencia, fallback: 'No capturado'),
            ),
            _TicketPair(
              label: 'Estado',
              value: _value(persona?.estadoLicencia, fallback: 'No capturado'),
            ),
            _TicketPair(label: 'Vigencia', value: _vigenciaLicencia),
            const _TicketDivider(),
            const _TicketSection('FIRMA Y MANIFESTACIÓN'),
            const Text('Firma de la persona infractora:'),
            const SizedBox(height: 30),
            const _SignatureLine(),
            const SizedBox(height: 10),
            const Text('Manifestación de inconformidad (opcional):'),
            const SizedBox(height: 8),
            const _HandwrittenLines(lines: 3),
            const _TicketDivider(),
            const _TicketSection('AGENTE'),
            _TicketPair(
              label: 'Nombre',
              value: _value(captura.creador?.nombre, fallback: 'No capturado'),
            ),
            _TicketPair(label: 'No. placa', value: _placaAgente),
            _TicketBlock(label: 'Adscripcion', value: _adscripcionAgente),
            const SizedBox(height: 18),
            const Text('Firma autógrafa/electrónica:'),
            const SizedBox(height: 30),
            const _SignatureLine(),
            const SizedBox(height: 8),
            Text(
              preview
                  ? 'PREVISUALIZACION LOCAL'
                  : 'Captura #${captura.id} / Operativo #${operativo.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  String get _folio {
    final suffix = total > 1 ? '-${index + 1}' : '';
    return 'CL-${operativo.id}-${captura.id}$suffix';
  }

  String get _lugar {
    final parts = <String>[
      if ((captura.lugar ?? '').trim().isNotEmpty) captura.lugar!.trim(),
      if ((operativo.lugar ?? '').trim().isNotEmpty &&
          operativo.lugar!.trim() != captura.lugar?.trim())
        operativo.lugar!.trim(),
    ];
    if (parts.isEmpty) return 'No capturado';
    return parts.join(' / ');
  }

  String get _fundamentoInfraccion {
    return _BoletaLegalText.fundamentoInfraccion(vehiculo, persona);
  }

  String get _fundamentoSancion {
    return _BoletaLegalText.fundamentoSancion(vehiculo, persona);
  }

  String get _conducta {
    return _BoletaLegalText.conducta(captura, vehiculo, persona);
  }

  String get _vehiculoDescripcion {
    final title = _joinUnique(
      [
        vehiculo?.marca,
        vehiculo?.linea,
        vehiculo?.modelo,
        vehiculo?.tipoGeneral,
        vehiculo?.tipo,
        vehiculo?.color,
      ],
      separator: ' ',
      fallback: '',
    );
    final serie = _value(vehiculo?.serie, fallback: '');
    final servicio = _value(vehiculo?.tipoServicio, fallback: '');
    return _joinUnique([
      title.isNotEmpty ? title : null,
      serie.isNotEmpty ? 'Serie: $serie' : null,
      servicio.isNotEmpty ? 'Servicio: $servicio' : null,
    ], fallback: 'No capturado');
  }

  String get _vigenciaLicencia {
    if (persona?.permanente == true) return 'Permanente';
    return _value(persona?.vigenciaLicencia, fallback: 'No capturado');
  }

  String get _placaAgente {
    return _value(
      captura.creador?.placa,
      fallback: 'Pendiente de captura en Personal',
    );
  }

  String get _adscripcionAgente {
    return _value(
      captura.creador?.adscripcion ??
          captura.unidad?.nombre ??
          captura.delegacion?.nombre,
      fallback: 'Pendiente de unidad',
    );
  }

  bool get _mostrarInformacionLiberacion {
    return _BoletaLegalText.requiereInformacionLiberacion(vehiculo);
  }

  String get _informacionLiberacionVehiculo {
    return _BoletaLegalText.informacionLiberacion(vehiculo);
  }
}

Uint8List _buildEscPosTicket(
  ConduceLegalidadOperativo operativo,
  ConduceLegalidadCaptura captura,
) {
  final vehiculos = captura.vehiculos.isEmpty
      ? <ConduceLegalidadVehiculo?>[null]
      : captura.vehiculos.cast<ConduceLegalidadVehiculo?>().toList();
  final writer = _ThermalTicketWriter();

  for (var i = 0; i < vehiculos.length; i++) {
    final data = _BoletaTicketData(
      operativo: operativo,
      captura: captura,
      vehiculo: vehiculos[i],
      persona: _personaForTicket(captura, i),
      index: i,
      total: vehiculos.length,
    );
    _writeThermalTicket(writer, data);
    if (i < vehiculos.length - 1) {
      writer.blank();
      writer.blank();
      writer.rule();
      writer.blank();
      writer.blank();
    }
  }

  final textBytes = _thermalEncode(writer.toString().replaceAll('\n', '\r\n'));
  return Uint8List.fromList(<int>[
    0x1B, 0x40, // Inicializa impresora.
    0x1B, 0x21, 0x00, // Modo normal.
    0x1D, 0x21, 0x00, // Tamaño normal.
    0x1B, 0x45, 0x00, // Negritas apagadas.
    0x1B, 0x74, 0x02, // Tabla CP850 para acentos en español.
    0x1B, 0x61, 0x00, // Alineación izquierda; el centrado va en texto.
    ...textBytes,
    0x0A,
    0x0A,
    0x0A,
  ]);
}

Uint8List _buildEscPosTestTicket() {
  final timestamp = DateTime.now().toString().split('.').first;
  final textBytes = _thermalEncode(
    'SEGURIDAD VIAL\r\n'
    'PRUEBA DE IMPRESIÓN\r\n'
    '$timestamp\r\n'
    'Descripción, prevén, infracción\r\n'
    'Si puedes leer esto, la impresora\r\n'
    'recibió texto ESC/POS desde la app.\r\n',
  );
  return Uint8List.fromList(<int>[
    0x1B,
    0x40,
    0x1B,
    0x21,
    0x00,
    0x1D,
    0x21,
    0x00,
    0x1B,
    0x45,
    0x00,
    0x1B,
    0x74,
    0x02,
    0x1B,
    0x61,
    0x01,
    ...textBytes,
    0x1B,
    0x61,
    0x00,
    0x0A,
    0x0A,
    0x0A,
  ]);
}

void _writeThermalTicket(_ThermalTicketWriter ticket, _BoletaTicketData data) {
  ticket.center('SECRETARÍA DE SEGURIDAD PÚBLICA');
  ticket.center('COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL');
  ticket.blank();
  ticket.center('BOLETA DE NOTIFICACIÓN');
  ticket.center('OPERATIVO CONDUCE CON LEGALIDAD');
  ticket.rule();
  ticket.pair('Folio interno', data.folio);
  ticket.pair('Municipio', _value(data.captura.municipio));
  ticket.pair('Fecha', _value(data.captura.fecha));
  ticket.pair('Hora', _value(data.captura.hora));
  ticket.block('Lugar', data.lugar);
  ticket.rule();
  ticket.section('I. FUNDAMENTO JURÍDICO');
  ticket.block(
    'a) Artículo(s) que prevén la infracción',
    data.fundamentoInfraccion,
  );
  ticket.block(
    'b) Artículo(s) que establecen la sanción',
    data.fundamentoSancion,
  );
  ticket.rule();
  ticket.section('II. MOTIVACIÓN');
  ticket.pair('Día', _value(data.captura.fecha));
  ticket.pair('Hora', _value(data.captura.hora));
  ticket.block('Lugar', data.lugar);
  ticket.block('Descripción breve de la conducta', data.conducta);
  ticket.rule();
  ticket.section('PERSONA INFRACTORA');
  ticket.pair(
    'Nombre',
    _value(data.persona?.nombre, fallback: 'No presente o no proporcionado'),
  );
  ticket.block(
    'Domicilio',
    _value(data.persona?.domicilio, fallback: 'No presente o no proporcionado'),
  );
  ticket.rule();
  ticket.section('VEHÍCULO');
  ticket.pair(
    'Placas/permiso',
    _value(data.vehiculo?.placas, fallback: 'No capturado'),
  );
  ticket.pair(
    'Estado placas',
    _value(data.vehiculo?.estadoPlacas, fallback: 'No capturado'),
  );
  ticket.block('Descripción', data.vehiculoDescripcion);
  if (data.mostrarInformacionLiberacion) {
    ticket.rule();
    ticket.section('LIBERACIÓN DEL VEHÍCULO');
    ticket.block('Trámite', data.informacionLiberacionVehiculo);
  }
  ticket.rule();
  ticket.section('LICENCIA O PERMISO');
  ticket.pair(
    'Tipo',
    _value(data.persona?.tipoLicencia, fallback: 'No capturado'),
  );
  ticket.pair(
    'Número',
    _value(data.persona?.numeroLicencia, fallback: 'No capturado'),
  );
  ticket.pair(
    'Estado',
    _value(data.persona?.estadoLicencia, fallback: 'No capturado'),
  );
  ticket.pair('Vigencia', data.vigenciaLicencia);
  ticket.rule();
  ticket.section('FIRMA Y MANIFESTACIÓN');
  ticket.line('Firma de la persona infractora:');
  ticket.blank();
  ticket.blank();
  ticket.line(_ThermalTicketWriter.repeat('_', _ThermalTicketWriter.width));
  ticket.blank();
  ticket.line('Manifestación de inconformidad');
  ticket.line('(opcional):');
  ticket.blank();
  ticket.line(_ThermalTicketWriter.repeat('_', _ThermalTicketWriter.width));
  ticket.blank();
  ticket.line(_ThermalTicketWriter.repeat('_', _ThermalTicketWriter.width));
  ticket.blank();
  ticket.line(_ThermalTicketWriter.repeat('_', _ThermalTicketWriter.width));
  ticket.rule();
  ticket.section('AGENTE');
  ticket.pair(
    'Nombre',
    _value(data.captura.creador?.nombre, fallback: 'No capturado'),
  );
  ticket.pair('No. placa', data.placaAgente);
  ticket.block('Adscripcion', data.adscripcionAgente);
  ticket.blank();
  ticket.line('Firma autógrafa/electrónica:');
  ticket.blank();
  ticket.blank();
  ticket.line(_ThermalTicketWriter.repeat('_', _ThermalTicketWriter.width));
  ticket.blank();
  ticket.center(
    'Captura #${data.captura.id} / Operativo #${data.operativo.id}',
  );
}

class _BoletaTicketData {
  final ConduceLegalidadOperativo operativo;
  final ConduceLegalidadCaptura captura;
  final ConduceLegalidadVehiculo? vehiculo;
  final ConduceLegalidadPersona? persona;
  final int index;
  final int total;

  const _BoletaTicketData({
    required this.operativo,
    required this.captura,
    required this.vehiculo,
    required this.persona,
    required this.index,
    required this.total,
  });

  String get folio {
    final suffix = total > 1 ? '-${index + 1}' : '';
    return 'CL-${operativo.id}-${captura.id}$suffix';
  }

  String get lugar {
    final parts = <String>[
      if ((captura.lugar ?? '').trim().isNotEmpty) captura.lugar!.trim(),
      if ((operativo.lugar ?? '').trim().isNotEmpty &&
          operativo.lugar!.trim() != captura.lugar?.trim())
        operativo.lugar!.trim(),
    ];
    if (parts.isEmpty) return 'No capturado';
    return parts.join(' / ');
  }

  String get fundamentoInfraccion {
    return _BoletaLegalText.fundamentoInfraccion(vehiculo, persona);
  }

  String get fundamentoSancion {
    return _BoletaLegalText.fundamentoSancion(vehiculo, persona);
  }

  String get conducta {
    return _BoletaLegalText.conducta(captura, vehiculo, persona);
  }

  String get vehiculoDescripcion {
    final title = _joinUnique(
      [
        vehiculo?.marca,
        vehiculo?.linea,
        vehiculo?.modelo,
        vehiculo?.tipoGeneral,
        vehiculo?.tipo,
        vehiculo?.color,
      ],
      separator: ' ',
      fallback: '',
    );
    final serie = _value(vehiculo?.serie, fallback: '');
    final servicio = _value(vehiculo?.tipoServicio, fallback: '');
    return _joinUnique([
      title.isNotEmpty ? title : null,
      serie.isNotEmpty ? 'Serie: $serie' : null,
      servicio.isNotEmpty ? 'Servicio: $servicio' : null,
    ], fallback: 'No capturado');
  }

  String get vigenciaLicencia {
    if (persona?.permanente == true) return 'Permanente';
    return _value(persona?.vigenciaLicencia, fallback: 'No capturado');
  }

  String get placaAgente {
    return _value(
      captura.creador?.placa,
      fallback: 'Pendiente de captura en Personal',
    );
  }

  String get adscripcionAgente {
    return _value(
      captura.creador?.adscripcion ??
          captura.unidad?.nombre ??
          captura.delegacion?.nombre,
      fallback: 'Pendiente de unidad',
    );
  }

  bool get mostrarInformacionLiberacion {
    return _BoletaLegalText.requiereInformacionLiberacion(vehiculo);
  }

  String get informacionLiberacionVehiculo {
    return _BoletaLegalText.informacionLiberacion(vehiculo);
  }
}

class _ThermalTicketWriter {
  static const int width = 32;

  final StringBuffer _buffer = StringBuffer();

  void center(String text) {
    for (final line in _wrapText(text, width)) {
      final padding = ((width - line.length) / 2)
          .floor()
          .clamp(0, width)
          .toInt();
      _buffer.writeln('${repeat(' ', padding)}$line');
    }
  }

  void section(String text) {
    blank();
    center(text);
  }

  void pair(String label, String value) {
    final cleanLabel = _thermalClean(label);
    final cleanValue = _thermalClean(value);
    final prefix = '$cleanLabel: ';
    final singleLine =
        !cleanValue.contains('\n') &&
        prefix.length + cleanValue.length <= width;
    if (singleLine) {
      line('$prefix$cleanValue');
      return;
    }

    line('$cleanLabel:');
    _writeWrappedParagraphs(cleanValue, indent: 2);
  }

  void block(String label, String value) {
    line('${_thermalClean(label)}:');
    _writeWrappedParagraphs(value, indent: 2);
  }

  void rule() {
    line(repeat('-', width));
  }

  void blank() {
    _buffer.writeln();
  }

  void line(String text) {
    _buffer.writeln(_thermalClean(text));
  }

  void _writeWrappedParagraphs(String text, {required int indent}) {
    final paragraphs = _thermalClean(text).split(RegExp(r'\r?\n'));
    for (final paragraph in paragraphs) {
      final lines = _wrapText(paragraph, width - indent);
      for (final line in lines) {
        _buffer.writeln('${repeat(' ', indent)}$line');
      }
    }
  }

  @override
  String toString() => _buffer.toString();

  static String repeat(String value, int count) {
    if (count <= 0) return '';
    return List<String>.filled(count, value).join();
  }
}

ConduceLegalidadPersona? _personaForTicket(
  ConduceLegalidadCaptura captura,
  int index,
) {
  if (captura.personas.isEmpty) return null;
  if (captura.personas.length > index) return captura.personas[index];
  return captura.personas.first;
}

class _BoletaInfractionEntry {
  final String label;
  final ConduceLegalidadFundamento? infraccion;
  final String? fallbackLegal;
  final ConduceLegalidadVehiculo? vehiculo;

  const _BoletaInfractionEntry({
    required this.label,
    required this.infraccion,
    required this.fallbackLegal,
    this.vehiculo,
  });
}

class _BoletaLegalText {
  static const String _normativa =
      'del Reglamento de la Ley de Movilidad y Seguridad Vial del Estado de Michoacán';

  static String fundamentoInfraccion(
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    final blocks = <String>[];
    for (final entry in _entries(vehiculo, persona)) {
      final referencias = _referenciasLegales(entry.infraccion);
      final fallback = referencias.isEmpty
          ? _sanitizedFallback(entry.fallbackLegal)
          : null;
      final lines = <String>[...referencias, if (fallback != null) fallback];
      if (lines.isNotEmpty) {
        blocks.add(_entryBlock(entry.label, lines));
      }
    }

    return blocks.isEmpty ? 'Pendiente de catálogo legal' : blocks.join('\n');
  }

  static String fundamentoSancion(
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    final blocks = <String>[];
    for (final entry in _entries(vehiculo, persona)) {
      final referencias = _referenciasLegales(entry.infraccion);
      final sancion = _sancionAplicable(
        entry.infraccion,
        entry.vehiculo,
        incluirRetencion: entry.vehiculo != null,
      );
      final fallback = sancion == null && referencias.isEmpty
          ? _sanitizedFallback(entry.fallbackLegal)
          : null;
      final lines = <String>[
        ...referencias,
        if (sancion != null) sancion,
        if (fallback != null) fallback,
      ];
      if (lines.isNotEmpty) {
        blocks.add(_entryBlock(entry.label, lines));
      }
    }

    if (blocks.isEmpty && requiereInformacionLiberacion(vehiculo)) {
      return 'Vehículo:\n- Sanción aplicable: remisión o retiro del vehículo al depósito.';
    }

    return blocks.isEmpty ? 'Pendiente de catálogo legal' : blocks.join('\n');
  }

  static String conducta(
    ConduceLegalidadCaptura captura,
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    final infraccionVehiculo = vehiculo?.infraccion;
    final infraccionPersona = persona?.infraccion;
    return _joinUnique([
      captura.narrativa,
      infraccionPersona?.narrativaSugerida,
      infraccionVehiculo?.narrativaSugerida,
      _conductaCatalogo(infraccionPersona),
      _conductaCatalogo(infraccionVehiculo),
      vehiculo?.observaciones,
      persona?.observaciones,
    ], fallback: 'No capturada');
  }

  static bool requiereInformacionLiberacion(
    ConduceLegalidadVehiculo? vehiculo,
  ) {
    final infraccion = vehiculo?.infraccion;
    return (vehiculo?.retencionVehiculo ?? false) ||
        (infraccion?.retencionVehiculo ?? false) ||
        (infraccion?.depositoSiSinPersonaHabilitada ?? false);
  }

  static String informacionLiberacion(ConduceLegalidadVehiculo? vehiculo) {
    final deposito = _cleanValue(vehiculo?.corralon);
    final retiro = deposito == null
        ? 'La entrega física se realizará conforme al depósito vehicular autorizado que corresponda.'
        : 'La entrega física se realizará en $deposito, previa autorización.';

    return 'Para iniciar el trámite de liberación del vehículo, la persona interesada deberá acudir a la Dirección de Justicia Cívica y Mediación Administrativa, ubicada en Periférico Paseo de la República #5000, Colonia Sentimientos de la Nación (C.P. 58178), en Morelia, Mich., de lunes a viernes de 09:00 a 18:00 horas, con identificación oficial y documentación que acredite propiedad o legítima posesión. Informes: 4433163728. $retiro';
  }

  static List<_BoletaInfractionEntry> _entries(
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    return <_BoletaInfractionEntry>[
      if (persona?.infraccion != null ||
          _cleanValue(persona?.fundamentoLegal) != null)
        _BoletaInfractionEntry(
          label: 'Persona infractora',
          infraccion: persona?.infraccion,
          fallbackLegal: persona?.fundamentoLegal,
        ),
      if (vehiculo?.infraccion != null ||
          _cleanValue(vehiculo?.fundamentoLegal) != null ||
          (vehiculo?.retencionVehiculo ?? false))
        _BoletaInfractionEntry(
          label: 'Vehículo',
          infraccion: vehiculo?.infraccion,
          fallbackLegal: vehiculo?.fundamentoLegal,
          vehiculo: vehiculo,
        ),
    ];
  }

  static String _entryBlock(String label, List<String> lines) {
    return '$label:\n${lines.map((line) => '- $line').join('\n')}';
  }

  static List<String> _referenciasLegales(
    ConduceLegalidadFundamento? infraccion,
  ) {
    if (infraccion == null) return const <String>[];

    final articulos = _numbers(infraccion.articulo);
    if (articulos.isNotEmpty) {
      final fraccion = _fracciones(infraccion.fraccion);
      final inciso = _incisos(infraccion.inciso);
      return articulos
          .map((articulo) {
            final partes = <String>['Artículo $articulo'];
            if (fraccion != null) partes.add(fraccion);
            if (inciso != null) partes.add(inciso);
            return '${partes.join(', ')} $_normativa.';
          })
          .toList(growable: false);
    }

    final corta = _cleanValue(infraccion.referenciaLegalCorta);
    if (corta == null || _looksLikeInternalCode(corta)) return const <String>[];

    final normalizada = corta
        .replaceAll(RegExp(r'\bArt\.\s*'), 'Artículo ')
        .replaceAll(RegExp(r'\bArticulos\b'), 'Artículos')
        .replaceAll(RegExp(r'\bArticulo\b'), 'Artículo')
        .replaceAll(RegExp(r'\bfracc\.\s*'), 'fracción ')
        .replaceAll(RegExp(r'\bfraccion\b'), 'fracción');
    return <String>[_sentence('$normalizada $_normativa')];
  }

  static String? _sancionAplicable(
    ConduceLegalidadFundamento? infraccion,
    ConduceLegalidadVehiculo? vehiculo, {
    bool incluirRetencion = true,
  }) {
    if (infraccion == null) {
      return requiereInformacionLiberacion(vehiculo)
          ? 'Sanción aplicable: remisión o retiro del vehículo al depósito.'
          : null;
    }

    final partes = <String>[
      if (infraccion.amonestacion) 'amonestación a la persona infractora',
      if (infraccion.arrestoPersona) 'arresto de la persona hasta por 36 horas',
      if (infraccion.suspensionLicencia)
        'suspensión de la licencia o permiso para conducir',
      if (infraccion.cancelacionLicencia)
        'cancelación de la licencia o permiso para conducir',
      if (infraccion.puntos > 0)
        'penalización de ${infraccion.puntos} ${infraccion.puntos == 1 ? 'punto' : 'puntos'} en la licencia para conducir',
      if (_cleanValue(infraccion.multaUmaTexto) != null)
        'multa de ${_cleanValue(infraccion.multaUmaTexto)}',
      if (incluirRetencion &&
          ((vehiculo?.retencionVehiculo ?? false) ||
              infraccion.retencionVehiculo))
        'remisión o retiro del vehículo al depósito',
      if (incluirRetencion &&
          !(vehiculo?.retencionVehiculo ?? false) &&
          !infraccion.retencionVehiculo &&
          infraccion.depositoSiSinPersonaHabilitada)
        'depósito del vehículo cuando no exista persona legalmente habilitada para hacerse cargo inmediato',
    ];

    if (partes.isEmpty) {
      final resumen = _cleanValue(infraccion.resumenSanciones);
      if (resumen == null || resumen == 'sin sanción registrada') return null;
      partes.add(resumen.replaceAll(' + ', '; '));
    }

    return 'Sanción aplicable: ${_humanJoin(partes)}.';
  }

  static String? _conductaCatalogo(ConduceLegalidadFundamento? infraccion) {
    final texto =
        _cleanValue(infraccion?.descripcion) ??
        _cleanValue(infraccion?.nombre) ??
        _cleanValue(infraccion?.textoOperativo);
    if (texto == null || _looksLikeInternalCode(texto)) return null;
    return 'La conducta asentada consiste en: ${_lowerFirst(texto)}.';
  }

  static String? _fracciones(String? raw) {
    final text = _cleanValue(raw);
    if (text == null) return null;
    final plural =
        text.contains(',') || text.contains('-') || text.contains(' y ');
    return '${plural ? 'fracciones' : 'fracción'} $text';
  }

  static String? _incisos(String? raw) {
    final text = _cleanValue(raw);
    if (text == null) return null;
    final values = text
        .split(RegExp(r'\s*(?:,|;|\sy\s)\s*'))
        .map(_cleanValue)
        .whereType<String>()
        .map((value) => value.endsWith(')') ? value : '$value)')
        .toList();
    if (values.isEmpty) return null;
    return values.length == 1
        ? 'inciso ${values.first}'
        : 'incisos ${_humanJoin(values)}';
  }

  static List<String> _numbers(String? raw) {
    final text = _cleanValue(raw);
    if (text == null) return const <String>[];
    return RegExp(r'\d+')
        .allMatches(text)
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet()
        .toList();
  }

  static String? _sanitizedFallback(String? raw) {
    final text = _cleanValue(raw);
    if (text == null) return null;

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map(_cleanValue)
        .whereType<String>()
        .where((line) => !_looksLikeInternalCode(line))
        .map(
          (line) => line
              .replaceAll(RegExp(r'\b(?:ART|OP_CL)[A-Z0-9_]{4,}\b'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  static String? _cleanValue(String? value) {
    final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String _humanJoin(List<String> values) {
    if (values.length <= 1) return values.join();
    if (values.length == 2) return '${values[0]} y ${values[1]}';
    return '${values.take(values.length - 1).join(', ')} y ${values.last}';
  }

  static String _sentence(String value) {
    final text = value.trim();
    return text.endsWith('.') ? text : '$text.';
  }

  static String _lowerFirst(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }

  static bool _looksLikeInternalCode(String value) {
    return RegExp(r'^(?:ART\d+|OP_CL)[A-Z0-9_]*$').hasMatch(value.trim());
  }
}

List<String> _wrapText(String text, int width) {
  final maxWidth = width <= 0 ? 1 : width;
  final normalized = _thermalClean(
    text,
  ).replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  if (normalized.isEmpty) return const <String>[''];

  final lines = <String>[];
  var current = '';
  for (final rawWord in normalized.split(' ')) {
    var word = rawWord;
    while (word.length > maxWidth) {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
      lines.add(word.substring(0, maxWidth));
      word = word.substring(maxWidth);
    }
    if (word.isEmpty) continue;

    if (current.isEmpty) {
      current = word;
    } else if (current.length + 1 + word.length <= maxWidth) {
      current = '$current $word';
    } else {
      lines.add(current);
      current = word;
    }
  }

  if (current.isNotEmpty) lines.add(current);
  return lines.isEmpty ? const <String>[''] : lines;
}

String _thermalClean(String value) {
  final replacements = <String, String>{
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
    '–': '-',
    '—': '-',
    '…': '...',
  };

  var text = value;
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text.replaceAll(
    RegExp(r'[^\x09\x0A\x0D\x20-\x7EáéíóúÁÉÍÓÚñÑüÜ¿¡°º]'),
    '',
  );
}

List<int> _thermalEncode(String value) {
  final bytes = <int>[];
  for (final rune in _thermalClean(value).runes) {
    if (rune <= 0x7F) {
      bytes.add(rune);
      continue;
    }

    final mapped = _cp850Bytes[String.fromCharCode(rune)];
    bytes.add(mapped ?? 0x3F);
  }
  return bytes;
}

const Map<String, int> _cp850Bytes = <String, int>{
  'á': 0xA0,
  'é': 0x82,
  'í': 0xA1,
  'ó': 0xA2,
  'ú': 0xA3,
  'Á': 0xB5,
  'É': 0x90,
  'Í': 0xD6,
  'Ó': 0xE0,
  'Ú': 0xE9,
  'ñ': 0xA4,
  'Ñ': 0xA5,
  'ü': 0x81,
  'Ü': 0x9A,
  '¿': 0xA8,
  '¡': 0xAD,
  '°': 0xF8,
  'º': 0xA7,
};

class _TicketCenter extends StatelessWidget {
  final List<Widget> children;

  const _TicketCenter({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _TicketDivider extends StatelessWidget {
  const _TicketDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black, width: 1)),
        ),
        child: SizedBox(height: 0),
      ),
    );
  }
}

class _TicketSection extends StatelessWidget {
  final String text;

  const _TicketSection(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TicketPair extends StatelessWidget {
  final String label;
  final String value;

  const _TicketPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TicketBlock extends StatelessWidget {
  final String label;
  final String value;

  const _TicketBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

class _SignatureLine extends StatelessWidget {
  const _SignatureLine();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      child: SizedBox(height: 1),
    );
  }
}

class _HandwrittenLines extends StatelessWidget {
  final int lines;

  const _HandwrittenLines({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines; i++) ...[
          const SizedBox(height: 18),
          const _SignatureLine(),
        ],
      ],
    );
  }
}

class _BoletaStatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _BoletaStatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class _BoletaPreviewData {
  final ConduceLegalidadOperativo operativo;
  final ConduceLegalidadCaptura captura;

  const _BoletaPreviewData({required this.operativo, required this.captura});

  static _BoletaPreviewData create() {
    final today = _date(DateTime.now());
    final now = TimeOfDay.now();
    final hour =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    const infraccion = ConduceLegalidadFundamento(
      id: 10,
      codigo: 'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
      nombre: 'Persona sin licencia y sin persona habilitada inmediata',
      articulo: '402; 700; 702',
      referenciaLegalCorta: 'Artículos 402, 700 y 702',
      puntos: 0,
      multaUmaTexto: 'Conforme a UMA vigente',
      retencionVehiculo: true,
      resumenSanciones: 'remisión o retiro del vehículo al depósito',
      fundamentoLegal:
          'Fundamento operativo compuesto relativo a licencia vigente y retiro del vehículo cuando no existe persona legalmente habilitada para hacerse cargo inmediato.',
      narrativaSugerida:
          'Conduce motocicleta sin licencia o permiso vigente, sin persona habilitada que pueda hacerse cargo inmediato del vehículo.',
    );

    return _BoletaPreviewData(
      operativo: ConduceLegalidadOperativo(
        id: 1,
        nombre: 'Operativo conduce con legalidad',
        fecha: today,
        horaInicio: hour,
        municipio: 'Morelia',
        lugar: 'Av. Camelinas y Ventura Puente',
        estado: 'activo',
        totalCapturas: 1,
        misCapturas: 1,
      ),
      captura: ConduceLegalidadCaptura(
        id: 125,
        operativoId: 1,
        creador: const ConduceLegalidadUserRef(
          id: 7,
          nombre: 'Agente de Seguridad Vial',
        ),
        unidad: const ConduceLegalidadRef(
          id: 1,
          nombre: 'Unidad de Atencion a Siniestros',
        ),
        delegacion: const ConduceLegalidadRef(id: 1, nombre: 'Morelia'),
        fecha: today,
        hora: hour,
        municipio: 'Morelia',
        lugar: 'Av. Camelinas y Ventura Puente',
        narrativa:
            'Se detecta motocicleta circulando durante operativo Conduce con Legalidad; la persona conductora no exhibe licencia vigente ni presenta persona habilitada inmediata.',
        canEdit: false,
        vehiculos: const [
          ConduceLegalidadVehiculo(
            marca: 'Italika',
            modelo: '2024',
            tipoGeneral: 'Motocicleta',
            linea: 'FT150',
            color: 'Negro',
            placas: 'ABC1D',
            estadoPlacas: 'Michoacán',
            serie: '3SCPFTDEMO0000001',
            tipoServicio: 'Particular',
            retencionVehiculo: true,
            motivoRetencion: 'Retencion por falta de licencia vigente.',
            infraccion: infraccion,
          ),
        ],
        personas: const [
          ConduceLegalidadPersona(
            nombre: 'Juan Perez Lopez',
            domicilio: 'Calle Ejemplo 123, Morelia, Michoacán',
            tipoLicencia: 'Motociclista',
            estadoLicencia: 'No exhibe',
            numeroLicencia: 'No proporcionado',
          ),
        ],
      ),
    );
  }

  static String _date(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

String _value(String? value, {String fallback = 'No proporcionado'}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

String _joinUnique(
  Iterable<String?> values, {
  String separator = '\n',
  required String fallback,
}) {
  final seen = <String>{};
  final parts = <String>[];
  for (final value in values) {
    final text = value?.trim();
    if (text == null || text.isEmpty) continue;
    final key = text.toLowerCase();
    if (!seen.add(key)) continue;
    parts.add(text);
  }
  if (parts.isEmpty) return fallback;
  return parts.join(separator);
}
