import 'package:flutter/material.dart';

import '../core/municipios_michoacan.dart';

class MunicipioAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final bool requireSelection;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;

  const MunicipioAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    this.enabled = true,
    this.requireSelection = true,
    this.validator,
    this.onChanged,
    this.onSelected,
  });

  @override
  State<MunicipioAutocompleteField> createState() =>
      _MunicipioAutocompleteFieldState();
}

class _MunicipioAutocompleteFieldState
    extends State<MunicipioAutocompleteField> {
  bool _pickerOpen = false;

  String? _validate(String? value) {
    final external = widget.validator?.call(value);
    if (external != null) return external;

    final text = (value ?? '').trim();
    if (widget.requireSelection &&
        text.isNotEmpty &&
        !MunicipiosMichoacan.isKnown(text)) {
      return 'Selecciona un municipio de Michoacan.';
    }

    return null;
  }

  void _setSelected(String option) {
    widget.controller.value = TextEditingValue(
      text: option,
      selection: TextSelection.collapsed(offset: option.length),
    );
    widget.onChanged?.call(option);
    widget.onSelected?.call(option);
  }

  Future<void> _openPicker() async {
    if (!widget.enabled || _pickerOpen) return;

    FocusManager.instance.primaryFocus?.unfocus();
    _pickerOpen = true;
    String? selected;
    try {
      selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) =>
            _MunicipioPickerSheet(currentValue: widget.controller.text.trim()),
      );
    } finally {
      _pickerOpen = false;
    }

    if (!mounted || selected == null) return;
    _setSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      readOnly: true,
      decoration: widget.decoration.copyWith(
        suffixIcon: widget.decoration.suffixIcon ?? const Icon(Icons.search),
      ),
      validator: _validate,
      onTap: _openPicker,
    );
  }
}

class _MunicipioPickerSheet extends StatefulWidget {
  final String currentValue;

  const _MunicipioPickerSheet({required this.currentValue});

  @override
  State<_MunicipioPickerSheet> createState() => _MunicipioPickerSheetState();
}

class _MunicipioPickerSheetState extends State<_MunicipioPickerSheet> {
  final _queryController = TextEditingController();
  List<String> _matches = MunicipiosMichoacan.search('');

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Municipio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _queryController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar municipio',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  setState(() {
                    _matches = MunicipiosMichoacan.search(value);
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _matches.isEmpty
                    ? const Center(child: Text('Sin coincidencias.'))
                    : ListView.separated(
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final option = _matches[index];
                          return ListTile(
                            title: Text(option),
                            trailing: option == widget.currentValue
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.pop(context, option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
