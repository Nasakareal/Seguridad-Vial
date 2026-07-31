import 'package:flutter/material.dart';

import '../../../models/conduce_legalidad.dart';

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
        const Text(
          'Esta actividad también alimentará el operativo activo de Conduce '
          'con Legalidad de tu unidad y delegación.',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ConduceLegalidadFundamento?>(
          value: principalValue,
          isExpanded: true,
          itemHeight: null,
          menuMaxHeight: MediaQuery.of(context).size.height * .55,
          decoration: const InputDecoration(
            labelText: 'Fundamento legal',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.gavel_outlined),
          ),
          selectedItemBuilder: (context) => [
            const Text(
              'Seleccione un fundamento...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ...principalOptions.map(
              (item) => Text(
                item.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          items: [
            const DropdownMenuItem<ConduceLegalidadFundamento?>(
              value: null,
              child: Text('Seleccione un fundamento...'),
            ),
            ...principalOptions.map(
              (item) => DropdownMenuItem<ConduceLegalidadFundamento?>(
                value: item,
                child: _FundamentoMenuOption(fundamento: item),
              ),
            ),
          ],
          onChanged: enabled ? onPrincipalChanged : null,
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
                  child: DropdownButtonFormField<ConduceLegalidadFundamento?>(
                    value: value,
                    isExpanded: true,
                    itemHeight: null,
                    menuMaxHeight: MediaQuery.of(context).size.height * .55,
                    decoration: InputDecoration(
                      labelText: 'Fundamento adicional $actualIndex',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.gavel_outlined),
                    ),
                    selectedItemBuilder: (context) => [
                      const Text(
                        'Seleccione un fundamento...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ...options.map(
                        (item) => Text(
                          item.display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    items: [
                      const DropdownMenuItem<ConduceLegalidadFundamento?>(
                        value: null,
                        child: Text('Seleccione un fundamento...'),
                      ),
                      ...options.map(
                        (item) => DropdownMenuItem<ConduceLegalidadFundamento?>(
                          value: item,
                          child: _FundamentoMenuOption(fundamento: item),
                        ),
                      ),
                    ],
                    onChanged: enabled
                        ? (value) => onAdicionalChanged(actualIndex - 1, value)
                        : null,
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

class _FundamentoMenuOption extends StatelessWidget {
  final ConduceLegalidadFundamento fundamento;

  const _FundamentoMenuOption({required this.fundamento});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fundamento.display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            fundamento.sancionResumen,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
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
