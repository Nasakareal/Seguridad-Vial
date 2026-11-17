import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'widgets/archivo_ui.dart';

class ArchivoQrResult {
  final String tipo;
  final String uuid;
  const ArchivoQrResult({required this.tipo, required this.uuid});
}

class ArchivoEscanerQrScreen extends StatefulWidget {
  final String? requiredType;
  const ArchivoEscanerQrScreen({super.key, this.requiredType});
  @override
  State<ArchivoEscanerQrScreen> createState() => _ArchivoEscanerQrScreenState();
}

class _ArchivoEscanerQrScreenState extends State<ArchivoEscanerQrScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  final _manual = TextEditingController();
  bool _processing = false;

  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  @override
  void dispose() {
    _scanner.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _read(String raw) async {
    if (_processing) return;
    _processing = true;
    final match = _uuidPattern.firstMatch(raw);
    if (match == null) {
      if (mounted) archivoToast(context, 'QR no válido: se esperaba un UUID.', error: true);
      _processing = false;
      return;
    }
    final lower = raw.toLowerCase();
    final tipo = lower.contains('/libros/qr/') ? 'libro'
      : lower.contains('/bloques/qr/') ? 'bloque'
      : widget.requiredType;
    if (tipo == null) {
      final chosen = await showDialog<String>(context: context, builder: (context) => AlertDialog(
        title: const Text('Tipo de etiqueta'),
        content: const Text('El QR contiene un UUID sin identificar si corresponde a libro o bloque.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'libro'), child: const Text('Libro')),
          FilledButton(onPressed: () => Navigator.pop(context, 'bloque'), child: const Text('Bloque')),
        ],
      ));
      if (!mounted || chosen == null) { _processing = false; return; }
      Navigator.pop(context, ArchivoQrResult(tipo: chosen, uuid: match.group(0)!.toLowerCase()));
      return;
    }
    if (widget.requiredType != null && tipo != widget.requiredType) {
      if (mounted) archivoToast(context, 'Necesitas escanear un QR de ${widget.requiredType}.', error: true);
      _processing = false;
      return;
    }
    if (mounted) Navigator.pop(context, ArchivoQrResult(tipo: tipo, uuid: match.group(0)!.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Escanear etiqueta', subtitle: 'Identificación QR de libro o bloque',
    actions: [IconButton(onPressed: () => _scanner.toggleTorch(), icon: const Icon(Icons.flash_on_outlined))],
    child: ListView(padding: const EdgeInsets.all(14), children: [
      SizedBox(height: 320, child: ClipRRect(borderRadius: BorderRadius.circular(18),
        child: MobileScanner(
          controller: _scanner,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final raw = barcode.rawValue;
              if (raw != null && raw.isNotEmpty) { _read(raw); break; }
            }
          },
        ),
      )),
      const SizedBox(height: 14),
      const Card(child: Padding(padding: EdgeInsets.all(12),
        child: Text('Apunta la cámara a la etiqueta física. También puedes introducir el UUID manualmente durante las pruebas.'))),
      const SizedBox(height: 12),
      TextField(controller: _manual, decoration: archivoInput('UUID o enlace del QR', icon: Icons.qr_code)),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: () => _read(_manual.text.trim()),
        icon: const Icon(Icons.check), label: const Text('Identificar etiqueta')),
    ]),
  );
}
