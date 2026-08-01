import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/conduce_legalidad.dart';
import '../../services/browser_print_service.dart';
import '../../services/conduce_legalidad_service.dart';
import '../../services/thermal_printer_service.dart';
import 'conduce_legalidad_module.dart';

class ConduceLegalidadBoletaScreen extends StatefulWidget {
  final ConduceLegalidadOperativo? initialOperativo;
  final ConduceLegalidadCaptura? initialCaptura;
  final int? operativoId;
  final int? capturaId;
  final bool preview;
  final ConduceLegalidadModule module;

  const ConduceLegalidadBoletaScreen({
    super.key,
    this.initialOperativo,
    this.initialCaptura,
    this.operativoId,
    this.capturaId,
    this.preview = false,
    this.module = ConduceLegalidadModule.conduceLegalidad,
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
      final sample = _BoletaPreviewData.create(module: widget.module);
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
        final paperSize = await _selectPaperSize();
        if (!mounted || paperSize == null) return;

        final printer = await _selectBondedPrinter();
        if (!mounted || printer == null) return;

        await ThermalPrinterService.printEscPos(
          address: printer.address,
          bytes: _buildEscPosTicket(operativo, captura, paperSize),
        );
        if (!mounted) return;

        _showSnackBar('Boleta ${paperSize.label} enviada a ${printer.name}.');
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

      final paperSize = await _selectPaperSize();
      if (!mounted || paperSize == null) return;

      final printer = await _selectBondedPrinter();
      if (!mounted || printer == null) return;

      await ThermalPrinterService.printEscPos(
        address: printer.address,
        bytes: _buildEscPosTestTicket(paperSize),
      );
      if (!mounted) return;

      _showSnackBar('Prueba ${paperSize.label} enviada a ${printer.name}.');
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

  Future<_ThermalPaperSize?> _selectPaperSize() async {
    return showModalBottomSheet<_ThermalPaperSize>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Selecciona tamaño de ticket',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Elige el ancho del papel térmico.'),
              ),
              for (final size in _ThermalPaperSize.values)
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(size.label),
                  subtitle: Text(size.description),
                  onTap: () => Navigator.of(context).pop(size),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
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
            _TicketCenter(
              children: [
                const Text(
                  'SECRETARÍA DE SEGURIDAD PÚBLICA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 1),
                const Text(
                  'COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                ),
                const SizedBox(height: 5),
                const Text(
                  'BOLETA DE NOTIFICACIÓN',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 1),
                Text(
                  operativo.ticketOperativoTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const _TicketDivider(),
            _TicketPairRow(
              leftLabel: 'Folio',
              leftValue: _folio,
              rightLabel: 'Municipio',
              rightValue: _value(captura.municipio),
            ),
            _TicketPairRow(
              leftLabel: 'Fecha',
              leftValue: _value(captura.fecha),
              rightLabel: 'Hora',
              rightValue: _value(captura.hora),
            ),
            _TicketBlock(label: 'Lugar', value: _lugar),
            const _TicketDivider(),
            const _TicketSection('I. FUNDAMENTO JURÍDICO'),
            _TicketBlock(
              label: 'a) Artículo(s) infringido(s)',
              value: _fundamentoInfraccion,
            ),
            _TicketBlock(
              label: 'b) Los cuales ameritan',
              value: _fundamentoSancion,
            ),
            const _TicketDivider(),
            const _TicketSection('II. MOTIVACIÓN'),
            _TicketPairRow(
              leftLabel: 'Día',
              leftValue: _value(captura.fecha),
              rightLabel: 'Hora',
              rightValue: _value(captura.hora),
            ),
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
                persona?.nombreCompleto,
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
            _TicketPairRow(
              leftLabel: 'Placas/permiso',
              leftValue: _value(vehiculo?.placas, fallback: 'No capturado'),
              rightLabel: 'Estado placas',
              rightValue: _value(
                vehiculo?.estadoPlacas,
                fallback: 'No capturado',
              ),
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
            _TicketPairRow(
              leftLabel: 'Tipo',
              leftValue: _value(
                persona?.tipoLicencia,
                fallback: 'No capturado',
              ),
              rightLabel: 'Número',
              rightValue: _value(
                persona?.numeroLicencia,
                fallback: 'No capturado',
              ),
            ),
            _TicketPairRow(
              leftLabel: 'Estado',
              leftValue: _value(
                persona?.estadoLicencia,
                fallback: 'No capturado',
              ),
              rightLabel: 'Vigencia',
              rightValue: _vigenciaLicencia,
            ),
            const _TicketDivider(),
            const _TicketSection('FIRMA Y MANIFESTACIÓN'),
            const Text('Firma de la persona infractora:'),
            const SizedBox(height: 24),
            const _SignatureLine(),
            const SizedBox(height: 6),
            const Text('Manifestación de inconformidad (opcional):'),
            const SizedBox(height: 4),
            const _HandwrittenLines(lines: 3),
            const _TicketDivider(),
            const _TicketSection('AGENTE'),
            _TicketPair(
              label: 'Nombre',
              value: _value(captura.creador?.nombre, fallback: 'No capturado'),
            ),
            _TicketPair(label: 'No. placa', value: _placaAgente),
            _TicketBlock(label: 'Adscripcion', value: _adscripcionAgente),
            const SizedBox(height: 12),
            const Text('Firma autógrafa/electrónica:'),
            const SizedBox(height: 24),
            const _SignatureLine(),
            const SizedBox(height: 5),
            Text(
              preview
                  ? 'PREVISUALIZACION LOCAL'
                  : 'Captura #${captura.id} / Operativo #${operativo.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Supervisó: Luis Eduardo Lugo Ordorica',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text(
              'Subdirector de Vialidades Urbanas',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  String get _folio {
    final suffix = total > 1 ? '-${index + 1}' : '';
    return '${operativo.ticketFolioPrefix}-${operativo.id}-${captura.id}$suffix';
  }

  String get _lugar {
    final operativoDireccion = operativo.direccionCompleta;
    final parts = <String>[
      if ((captura.lugar ?? '').trim().isNotEmpty) captura.lugar!.trim(),
      if (operativoDireccion.trim().isNotEmpty &&
          operativo.lugarConNumero.trim() != captura.lugar?.trim())
        operativoDireccion.trim(),
    ];
    if (parts.isEmpty) return 'No capturado';
    return parts.join(' / ');
  }

  String get _fundamentoInfraccion {
    return ConduceLegalidadBoletaLegalText.fundamentoInfraccion(
      captura,
      vehiculo,
      persona,
    );
  }

  String get _fundamentoSancion {
    return ConduceLegalidadBoletaLegalText.fundamentoSancion(
      captura,
      vehiculo,
      persona,
    );
  }

  String get _conducta {
    return ConduceLegalidadBoletaLegalText.conducta(captura, vehiculo, persona);
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
    return ConduceLegalidadBoletaLegalText.requiereInformacionLiberacion(
      vehiculo,
    );
  }

  String get _informacionLiberacionVehiculo {
    return ConduceLegalidadBoletaLegalText.informacionLiberacion(
      vehiculo,
      esDelegaciones: operativo.unidadId == 2 || captura.unidad?.id == 2,
      delegacion: operativo.delegacion ?? captura.delegacion,
    );
  }
}

Uint8List _buildEscPosTicket(
  ConduceLegalidadOperativo operativo,
  ConduceLegalidadCaptura captura,
  _ThermalPaperSize paperSize,
) {
  final vehiculos = captura.vehiculos.isEmpty
      ? <ConduceLegalidadVehiculo?>[null]
      : captura.vehiculos.cast<ConduceLegalidadVehiculo?>().toList();
  final writer = ThermalTicketRowFormatter(width: paperSize.columns);

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
    0x1B, 0x21, 0x00, // Fuente A normal y legible.
    0x1B, 0x4D, 0x00, // Selecciona fuente A explícitamente.
    0x1D, 0x21, 0x00, // Tamaño normal.
    0x1B, 0x45, 0x00, // Negritas apagadas.
    0x1B, 0x61, 0x00, // Alineación izquierda; el centrado va en texto.
    ...textBytes,
    ..._thermalTicketBottomFeed,
  ]);
}

Uint8List _buildEscPosTestTicket(_ThermalPaperSize paperSize) {
  final timestamp = DateTime.now().toString().split('.').first;
  final textBytes = _thermalEncode(
    'SEGURIDAD VIAL\r\n'
    'PRUEBA DE IMPRESIÓN\r\n'
    'Ticket ${paperSize.label}\r\n'
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
    0x1B,
    0x4D,
    0x00,
    0x1D,
    0x21,
    0x00,
    0x1B,
    0x45,
    0x00,
    0x1B,
    0x61,
    0x01,
    ...textBytes,
    0x1B,
    0x61,
    0x00,
    ..._thermalTicketBottomFeed,
  ]);
}

const List<int> _thermalTicketBottomFeed = <int>[
  0x0A,
  0x0A,
  0x0A,
  0x0A,
  0x0A,
  0x0A,
  0x0A,
];

void _writeThermalTicket(
  ThermalTicketRowFormatter ticket,
  _BoletaTicketData data,
) {
  ticket.center('SECRETARÍA DE SEGURIDAD PÚBLICA');
  ticket.center('COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL');
  ticket.blank();
  ticket.center('BOLETA DE NOTIFICACIÓN');
  ticket.center(data.operativo.ticketOperativoTitle);
  ticket.rule();
  ticket.pairRow(
    'Folio',
    data.folio,
    'Municipio',
    _value(data.captura.municipio),
  );
  ticket.pairRow(
    'Fecha',
    _value(data.captura.fecha),
    'Hora',
    _value(data.captura.hora),
  );
  ticket.block('Lugar', data.lugar);
  ticket.rule();
  ticket.section('I. FUNDAMENTO JURÍDICO');
  ticket.block('a) Artículo(s) infringido(s)', data.fundamentoInfraccion);
  ticket.block('b) Los cuales ameritan', data.fundamentoSancion);
  ticket.rule();
  ticket.section('II. MOTIVACIÓN');
  ticket.pairRow(
    'Día',
    _value(data.captura.fecha),
    'Hora',
    _value(data.captura.hora),
  );
  ticket.block('Lugar', data.lugar);
  ticket.block('Descripción breve de la conducta', data.conducta);
  ticket.rule();
  ticket.section('PERSONA INFRACTORA');
  ticket.pair(
    'Nombre',
    _value(
      data.persona?.nombreCompleto,
      fallback: 'No presente o no proporcionado',
    ),
  );
  ticket.block(
    'Domicilio',
    _value(data.persona?.domicilio, fallback: 'No presente o no proporcionado'),
  );
  ticket.rule();
  ticket.section('VEHÍCULO');
  ticket.pairRow(
    'Placas/permiso',
    _value(data.vehiculo?.placas, fallback: 'No capturado'),
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
  ticket.pairRow(
    'Tipo',
    _value(data.persona?.tipoLicencia, fallback: 'No capturado'),
    'Número',
    _value(data.persona?.numeroLicencia, fallback: 'No capturado'),
  );
  ticket.pairRow(
    'Estado',
    _value(data.persona?.estadoLicencia, fallback: 'No capturado'),
    'Vigencia',
    data.vigenciaLicencia,
  );
  ticket.rule();
  ticket.section('FIRMA Y MANIFESTACIÓN');
  ticket.line('Firma de la persona infractora:');
  ticket.blank();
  ticket.blank();
  ticket.line(ThermalTicketRowFormatter.repeat('_', ticket.width));
  ticket.blank();
  ticket.line('Manifestación de inconformidad');
  ticket.line('(opcional):');
  ticket.blank();
  ticket.line(ThermalTicketRowFormatter.repeat('_', ticket.width));
  ticket.blank();
  ticket.line(ThermalTicketRowFormatter.repeat('_', ticket.width));
  ticket.blank();
  ticket.line(ThermalTicketRowFormatter.repeat('_', ticket.width));
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
  ticket.line(ThermalTicketRowFormatter.repeat('_', ticket.width));
  ticket.blank();
  ticket.center(
    'Captura #${data.captura.id} / Operativo #${data.operativo.id}',
  );
  ticket.blank();
  ticket.center('Supervisó: Luis Eduardo Lugo Ordorica');
  ticket.center('Subdirector de Vialidades Urbanas');
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
    return '${operativo.ticketFolioPrefix}-${operativo.id}-${captura.id}$suffix';
  }

  String get lugar {
    final operativoDireccion = operativo.direccionCompleta;
    final parts = <String>[
      if ((captura.lugar ?? '').trim().isNotEmpty) captura.lugar!.trim(),
      if (operativoDireccion.trim().isNotEmpty &&
          operativo.lugarConNumero.trim() != captura.lugar?.trim())
        operativoDireccion.trim(),
    ];
    if (parts.isEmpty) return 'No capturado';
    return parts.join(' / ');
  }

  String get fundamentoInfraccion {
    return ConduceLegalidadBoletaLegalText.fundamentoInfraccion(
      captura,
      vehiculo,
      persona,
    );
  }

  String get fundamentoSancion {
    return ConduceLegalidadBoletaLegalText.fundamentoSancion(
      captura,
      vehiculo,
      persona,
    );
  }

  String get conducta {
    return ConduceLegalidadBoletaLegalText.conducta(captura, vehiculo, persona);
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
    return ConduceLegalidadBoletaLegalText.requiereInformacionLiberacion(
      vehiculo,
    );
  }

  String get informacionLiberacionVehiculo {
    return ConduceLegalidadBoletaLegalText.informacionLiberacion(
      vehiculo,
      esDelegaciones: operativo.unidadId == 2 || captura.unidad?.id == 2,
      delegacion: operativo.delegacion ?? captura.delegacion,
    );
  }
}

class ThermalTicketRowFormatter {
  final int width;

  final StringBuffer _buffer = StringBuffer();

  ThermalTicketRowFormatter({required this.width});

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

  void pairRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) {
    final left = '${_thermalClean(leftLabel)}: ${_thermalClean(leftValue)}';
    final right = '${_thermalClean(rightLabel)}: ${_thermalClean(rightValue)}';
    final spaces = width - left.length - right.length;
    if (!left.contains('\n') && !right.contains('\n') && spaces >= 2) {
      line('$left${repeat(' ', spaces)}$right');
      return;
    }

    pair(leftLabel, leftValue);
    pair(rightLabel, rightValue);
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

enum _ThermalPaperSize {
  paper80mm('80 mm', 'Letra normal, 48 columnas', 48),
  paper58mm('58 mm', 'Letra normal, 32 columnas', 32);

  final String label;
  final String description;
  final int columns;

  const _ThermalPaperSize(this.label, this.description, this.columns);
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

class ConduceLegalidadBoletaLegalText {
  static const String _normativa =
      'del Reglamento de la Ley de Movilidad y Seguridad Vial del Estado de Michoacán';

  static String fundamentoInfraccion(
    ConduceLegalidadCaptura captura,
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    final blocks = <String>[];
    for (final entry in _entries(captura, vehiculo, persona)) {
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
    ConduceLegalidadCaptura captura,
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    final consecuencias = <MapEntry<String, String>>[];
    for (final entry in _entries(captura, vehiculo, persona)) {
      final sancion = _sancionAplicable(
        entry.infraccion,
        entry.vehiculo,
        incluirRetencion: entry.vehiculo != null,
      );
      if (sancion != null) {
        consecuencias.add(MapEntry(entry.label, _compactSancion(sancion)));
      }
    }

    if (consecuencias.isEmpty && requiereInformacionLiberacion(vehiculo)) {
      return 'remisión o retiro del vehículo al depósito.';
    }

    if (consecuencias.length == 1) return consecuencias.first.value;
    if (consecuencias.isEmpty) return 'consecuencia pendiente de catálogo.';

    return consecuencias
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }

  static String _compactSancion(String value) {
    final text = value
        .replaceFirst(RegExp(r'^Sanción aplicable:\s*'), '')
        .trim();
    return _lowerFirst(text);
  }

  static String conducta(
    ConduceLegalidadCaptura captura,
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    final infraccionesCaptura = captura.fundamentos.isNotEmpty
        ? captura.fundamentos
        : [if (captura.infraccion != null) captura.infraccion!];
    final infraccionVehiculo = vehiculo?.infraccion;
    final infraccionPersona = persona?.infraccion;
    return _joinUnique([
      captura.narrativa,
      ...infraccionesCaptura.map((item) => item.narrativaSugerida),
      infraccionPersona?.narrativaSugerida,
      infraccionVehiculo?.narrativaSugerida,
      ...infraccionesCaptura.map(_conductaCatalogo),
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

  static String informacionLiberacion(
    ConduceLegalidadVehiculo? vehiculo, {
    bool esDelegaciones = false,
    ConduceLegalidadRef? delegacion,
  }) {
    final deposito = _cleanValue(vehiculo?.corralon);
    final retiro = deposito == null
        ? 'La entrega física se realizará conforme al depósito vehicular autorizado que corresponda.'
        : 'La entrega física se realizará en $deposito, previa autorización.';

    if (esDelegaciones) {
      final nombre = _cleanValue(delegacion?.nombre);
      final direccion = _cleanValue(delegacion?.direccionCompleta);
      final oficina = nombre == null
          ? 'la delegación correspondiente'
          : 'la Delegación de $nombre';
      final ubicacion = direccion == null ? '' : ', ubicada en $direccion';

      return 'Para iniciar el trámite de liberación del vehículo, la persona interesada deberá acudir a $oficina$ubicacion, en su horario de atención, con identificación oficial y documentación que acredite propiedad o legítima posesión. $retiro';
    }

    return 'Para iniciar el trámite de liberación del vehículo, la persona interesada deberá acudir a la Dirección de Justicia Cívica y Mediación Administrativa, ubicada en Periférico Paseo de la República #5000, Colonia Sentimientos de la Nación (C.P. 58178), en Morelia, Mich., de lunes a viernes de 09:00 a 18:00 horas, con identificación oficial y documentación que acredite propiedad o legítima posesión. Informes: 4433163728. $retiro';
  }

  static List<_BoletaInfractionEntry> _entries(
    ConduceLegalidadCaptura captura,
    ConduceLegalidadVehiculo? vehiculo,
    ConduceLegalidadPersona? persona,
  ) {
    if (captura.fundamentos.isNotEmpty) {
      final multiples = captura.fundamentos.length > 1;
      return captura.fundamentos
          .asMap()
          .entries
          .map((entry) {
            final fundamento = entry.value;
            return _BoletaInfractionEntry(
              label: multiples ? 'Fundamento ${entry.key + 1}' : 'Intervención',
              infraccion: fundamento,
              fallbackLegal: fundamento.fundamentoLegal,
              vehiculo: vehiculo,
            );
          })
          .toList(growable: false);
    }

    if (captura.infraccion != null ||
        _cleanValue(captura.fundamentoLegal) != null) {
      return <_BoletaInfractionEntry>[
        _BoletaInfractionEntry(
          label: 'Intervención',
          infraccion: captura.infraccion,
          fallbackLegal: captura.fundamentoLegal,
          vehiculo: vehiculo,
        ),
      ];
    }

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
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'Å': 'A',
    'Æ': 'AE',
    'Ç': 'C',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ñ': 'N',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'Œ': 'OE',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ý': 'Y',
    'Ÿ': 'Y',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'œ': 'oe',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ß': 'ss',
    '¿': '?',
    '¡': '!',
    '°': ' grados',
    'º': 'o',
    'ª': 'a',
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
    '–': '-',
    '—': '-',
    '…': '...',
    ' ': ' ',
  };

  var text = value;
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'), '');
}

List<int> _thermalEncode(String value) => _thermalClean(value).codeUnits;

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
      padding: EdgeInsets.symmetric(vertical: 6),
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
      padding: const EdgeInsets.only(bottom: 4),
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 102,
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

class _TicketPairRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  const _TicketPairRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _TicketInlinePair(leftLabel, leftValue)),
          const SizedBox(width: 8),
          Expanded(child: _TicketInlinePair(rightLabel, rightValue)),
        ],
      ),
    );
  }
}

class _TicketInlinePair extends StatelessWidget {
  final String label;
  final String value;

  const _TicketInlinePair(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
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
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
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
          const SizedBox(height: 14),
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

  static _BoletaPreviewData create({
    ConduceLegalidadModule module = ConduceLegalidadModule.conduceLegalidad,
  }) {
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
        nombre: module.operativoNombre,
        tipoOperativo: module.id,
        fecha: today,
        horaInicio: hour,
        municipio: 'Morelia',
        lugar: 'Av. Camelinas y Ventura Puente',
        colonia: 'Félix Ireta',
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
