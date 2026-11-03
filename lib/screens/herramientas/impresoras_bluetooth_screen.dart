import 'package:flutter/material.dart';

import '../../services/thermal_printer_catalog_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../widgets/app_drawer.dart';

class ImpresorasBluetoothScreen extends StatefulWidget {
  const ImpresorasBluetoothScreen({super.key});

  @override
  State<ImpresorasBluetoothScreen> createState() =>
      _ImpresorasBluetoothScreenState();
}

class _ImpresorasBluetoothScreenState extends State<ImpresorasBluetoothScreen> {
  List<ThermalPrinterCatalogEntry> _entries = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ThermalPrinterCatalogService.index(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ThermalPrinterCatalogService.cleanError(error);
        _loading = false;
      });
    }
  }

  Future<void> _openForm([ThermalPrinterCatalogEntry? entry]) async {
    List<ThermalPrinterDevice> paired = const [];
    if (ThermalPrinterService.supportsBluetoothPrinting) {
      try {
        paired = await ThermalPrinterService.getBondedPrinters(
          resolveManagedNames: false,
        );
      } catch (_) {
        paired = const [];
      }
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<_PrinterFormValue>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PrinterFormSheet(entry: entry, paired: paired),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ThermalPrinterCatalogService.save(
        id: entry?.id,
        displayName: result.displayName,
        macAddress: result.macAddress,
        hardwareName: result.hardwareName,
        active: result.active,
      );
      if (!mounted) return;
      _snack(
        entry == null ? 'Impresora registrada.' : 'Impresora actualizada.',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _snack(ThermalPrinterCatalogService.cleanError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(ThermalPrinterCatalogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar impresora'),
        content: Text(
          '¿Eliminar ${entry.displayName}? Los usuarios volverán a verla con '
          'el nombre Bluetooth del fabricante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ThermalPrinterCatalogService.delete(entry.id);
      if (!mounted) return;
      _snack('Impresora eliminada.');
      await _load();
    } catch (error) {
      if (mounted) {
        _snack(ThermalPrinterCatalogService.cleanError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Impresoras Bluetooth'),
        backgroundColor: const Color(0xFF7A1747),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AppDrawer(trackingOn: false),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7A1747),
        foregroundColor: Colors.white,
        onPressed: _saving ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Stack(
        children: [
          _body(),
          if (_saving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Card(
            color: const Color(0xFFEFF6FF),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Solo Superadmin administra este catálogo. Los demás '
                      'usuarios únicamente verán estos nombres al elegir una '
                      'impresora emparejada.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.print_disabled_outlined, size: 64),
                  SizedBox(height: 12),
                  Text('No hay impresoras registradas.'),
                ],
              ),
            )
          else
            for (final entry in _entries)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: entry.active
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    foregroundColor: entry.active
                        ? const Color(0xFF166534)
                        : Colors.grey,
                    child: const Icon(Icons.print_outlined),
                  ),
                  title: Text(
                    entry.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${entry.macAddress}'
                    '${entry.hardwareName == null ? '' : '\nBluetooth: ${entry.hardwareName}'}'
                    '${entry.active ? '' : '\nDesactivada'}',
                  ),
                  isThreeLine: entry.hardwareName != null || !entry.active,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _openForm(entry);
                      if (value == 'delete') _delete(entry);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                  onTap: () => _openForm(entry),
                ),
              ),
        ],
      ),
    );
  }
}

class _PrinterFormValue {
  final String displayName;
  final String macAddress;
  final String? hardwareName;
  final bool active;

  const _PrinterFormValue({
    required this.displayName,
    required this.macAddress,
    required this.hardwareName,
    required this.active,
  });
}

class _PrinterFormSheet extends StatefulWidget {
  final ThermalPrinterCatalogEntry? entry;
  final List<ThermalPrinterDevice> paired;

  const _PrinterFormSheet({required this.entry, required this.paired});

  @override
  State<_PrinterFormSheet> createState() => _PrinterFormSheetState();
}

class _PrinterFormSheetState extends State<_PrinterFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mac;
  late final TextEditingController _hardwareName;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry?.displayName ?? '');
    _mac = TextEditingController(text: widget.entry?.macAddress ?? '');
    _hardwareName = TextEditingController(
      text: widget.entry?.hardwareName ?? '',
    );
    _active = widget.entry?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    _hardwareName.dispose();
    super.dispose();
  }

  void _usePaired(ThermalPrinterDevice device) {
    setState(() {
      _mac.text = ThermalPrinterCatalogService.normalizeMac(device.address);
      _hardwareName.text = device.systemName;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PrinterFormValue(
        displayName: _name.text.trim(),
        macAddress: ThermalPrinterCatalogService.normalizeMac(_mac.text),
        hardwareName: _hardwareName.text.trim().isEmpty
            ? null
            : _hardwareName.text.trim(),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.entry == null ? 'Registrar impresora' : 'Editar impresora',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nombre visible',
                hintText: 'UAS-001 o LAZARO-001',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Escribe un nombre visible.';
                if (text.length > 80) return 'Máximo 80 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mac,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Dirección MAC',
                hintText: '86:67:7A:62:D8:C3',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  ThermalPrinterCatalogService.isValidMac(value ?? '')
                  ? null
                  : 'Escribe una MAC válida de 12 dígitos.',
            ),
            if (widget.paired.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Impresoras emparejadas en este teléfono',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              for (final device in widget.paired)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.systemName),
                  subtitle: Text(device.address),
                  trailing: const Text('Usar'),
                  onTap: () => _usePaired(device),
                ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _hardwareName,
              decoration: const InputDecoration(
                labelText: 'Nombre Bluetooth original (opcional)',
                hintText: 'BT-802',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Disponible para los usuarios'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
