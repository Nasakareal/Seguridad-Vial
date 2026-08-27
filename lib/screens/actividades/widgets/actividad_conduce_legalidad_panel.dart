import 'package:flutter/material.dart';

import '../../../models/conduce_legalidad.dart';
import '../../../core/vehiculos/vehiculo_taxonomia.dart';

class ActividadConduceLegalidadPanel extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<ConduceLegalidadFundamento> catalogo;
  final List<ConduceLegalidadFundamento?> seleccionados;
  final bool enabled;
  final VoidCallback onRetry;
  final ValueChanged<ConduceLegalidadFundamento?> onPrincipalChanged;
  final void Function(int, ConduceLegalidadFundamento?) onAdicionalChanged;
  final ValueChanged<int> onRemoveAdicional;
  final VoidCallback onAdd;
  final String introText;
  final String fieldLabel;
  final bool showVehicleTypeFilter;
  final String? vehicleType;
  final ValueChanged<String?>? onVehicleTypeChanged;

  const ActividadConduceLegalidadPanel({
    super.key,
    required this.loading,
    required this.error,
    required this.catalogo,
    required this.seleccionados,
    required this.enabled,
    required this.onRetry,
    required this.onPrincipalChanged,
    required this.onAdicionalChanged,
    required this.onRemoveAdicional,
    required this.onAdd,
    this.introText =
        'Esta actividad también alimentará el operativo activo de Conduce con Legalidad de tu unidad y delegación.',
    this.fieldLabel = 'Fundamento legal',
    this.showVehicleTypeFilter = false,
    this.vehicleType,
    this.onVehicleTypeChanged,
  });

  String _key(ConduceLegalidadFundamento item) =>
      '${item.id}|${item.codigo ?? ''}';

  List<ConduceLegalidadFundamento> _options(
    ConduceLegalidadFundamento? current,
  ) {
    final used = seleccionados
        .whereType<ConduceLegalidadFundamento>()
        .where((item) => current == null || _key(item) != _key(current))
        .map(_key)
        .toSet();
    return catalogo.where((item) => !used.contains(_key(item))).toList();
  }

  ConduceLegalidadFundamento? _canonical(ConduceLegalidadFundamento? current) {
    if (current == null) return null;
    for (final item in catalogo) {
      if (_key(item) == _key(current)) return item;
    }
    for (final item in catalogo) {
      if (item.id == current.id) return item;
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    final principal = seleccionados.isEmpty ? null : seleccionados.first;
    final principalValue = _canonical(principal);
    final principalOptions = _options(principal);
    if (principalValue != null &&
        !principalOptions.any((item) => identical(item, principalValue))) {
      principalOptions.add(principalValue);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(introText),
        const SizedBox(height: 12),
        if (showVehicleTypeFilter) ...[
          DropdownButtonFormField<String?>(
            value: vehicleType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de vehículo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos los tipos'),
              ),
              ...VehiculoTaxonomia.tiposGenerales.map(
                (item) => DropdownMenuItem<String?>(
                  value: item['value'],
                  child: Text(item['label'] ?? item['value'] ?? ''),
                ),
              ),
              const DropdownMenuItem<String?>(
                value: 'transporte_publico',
                child: Text('Transporte público'),
              ),
            ],
            onChanged: enabled ? onVehicleTypeChanged : null,
          ),
          const SizedBox(height: 10),
        ],
        _FundamentoPickerField(
          value: principalValue,
          options: principalOptions,
          label: fieldLabel,
          enabled: enabled,
          onChanged: onPrincipalChanged,
        ),
        if (principal != null) ...[
          const SizedBox(height: 8),
          _FundamentoInfo(fundamento: principal),
        ],
        ...seleccionados.skip(1).toList().asMap().entries.expand((entry) {
          final actualIndex = entry.key + 1;
          final fundamento = entry.value;
          final value = _canonical(fundamento);
          final options = _options(fundamento);
          if (value != null && !options.any((item) => identical(item, value))) {
            options.add(value);
          }
          return <Widget>[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _FundamentoPickerField(
                    value: value,
                    options: options,
                    label: 'Fundamento adicional $actualIndex',
                    enabled: enabled,
                    onChanged: (value) =>
                        onAdicionalChanged(actualIndex - 1, value),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar fundamento',
                  onPressed: enabled
                      ? () => onRemoveAdicional(actualIndex - 1)
                      : null,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            if (fundamento != null) ...[
              const SizedBox(height: 8),
              _FundamentoInfo(fundamento: fundamento),
            ],
          ];
        }),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed:
              enabled &&
                  seleccionados.isNotEmpty &&
                  seleccionados.every((item) => item != null) &&
                  seleccionados.length < catalogo.length
              ? onAdd
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Añadir otro fundamento'),
        ),
      ],
    );
  }
}

class _FundamentoPickerField extends StatelessWidget {
  final ConduceLegalidadFundamento? value;
  final List<ConduceLegalidadFundamento> options;
  final String label;
  final bool enabled;
  final ValueChanged<ConduceLegalidadFundamento?> onChanged;

  const _FundamentoPickerField({
    required this.value,
    required this.options,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<ConduceLegalidadFundamento>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FundamentoSearchSheet(options: options, title: label),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled && options.isNotEmpty ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  tooltip: 'Limpiar selección',
                  onPressed: enabled ? () => onChanged(null) : null,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value?.display ??
              (options.isEmpty
                  ? 'No hay fundamentos para estos filtros'
                  : 'Buscar por conducta, artículo o código...'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: value == null ? TextStyle(color: Colors.grey.shade700) : null,
        ),
      ),
    );
  }
}

class _FundamentoSearchSheet extends StatefulWidget {
  final List<ConduceLegalidadFundamento> options;
  final String title;

  const _FundamentoSearchSheet({required this.options, required this.title});

  @override
  State<_FundamentoSearchSheet> createState() => _FundamentoSearchSheetState();
}

class _FundamentoSearchSheetState extends State<_FundamentoSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .trim();
  }

  String _searchText(ConduceLegalidadFundamento item) {
    return _normalize(
      [
        item.codigo,
        item.nombre,
        item.articulo,
        item.fraccion,
        item.inciso,
        item.referenciaLegalCorta,
        item.etiquetaOperativa,
        item.textoOperativo,
        item.descripcion,
        item.fundamentoLegal,
        item.ambitoVehiculoTexto,
      ].whereType<String>().join(' '),
    );
  }

  List<ConduceLegalidadFundamento> get _filtered {
    final query = _normalize(_query);
    if (query.isEmpty) return widget.options;
    final words = query.split(' ').where((word) => word.isNotEmpty).toList();
    final result = widget.options.where((item) {
      final text = _searchText(item);
      return words.every(text.contains);
    }).toList();
    result.sort((a, b) {
      final aText = _searchText(a);
      final bText = _searchText(b);
      final aStarts = aText.startsWith(query) ? 0 : 1;
      final bStarts = bText.startsWith(query) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      return a.display.compareTo(b.display);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            ListTile(
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('${items.length} fundamentos disponibles'),
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Ej. placas, abandono, artículo 420...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No encontré fundamentos con esas palabras.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(
                            item.display,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              item.referenciaLegalCorta,
                              item.sancionResumen,
                            ].whereType<String>().join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundamentoInfo extends StatelessWidget {
  final ConduceLegalidadFundamento fundamento;

  const _FundamentoInfo({required this.fundamento});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${fundamento.fundamentoLegal ?? fundamento.display}\n'
        'Sanción: ${fundamento.sancionResumen}',
      ),
    );
  }
}
