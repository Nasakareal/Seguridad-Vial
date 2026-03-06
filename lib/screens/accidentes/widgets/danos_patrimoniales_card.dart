import 'package:flutter/material.dart';
import '../../../models/hecho_form_data.dart';

class DanosPatrimonialesCard extends StatelessWidget {
  final HechoFormData data;
  final bool disabled;
  final TextEditingController propsCtrl;
  final TextEditingController montoCtrl;
  final VoidCallback onChanged;

  const DanosPatrimonialesCard({
    super.key,
    required this.data,
    required this.disabled,
    required this.propsCtrl,
    required this.montoCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daños patrimoniales',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Hubo daños patrimoniales?'),
              value: data.danosPatrimoniales,
              onChanged: disabled
                  ? null
                  : (v) {
                      data.danosPatrimoniales = v;
                      if (!v) {
                        data.propiedadesAfectadas = '';
                        data.montoDanos = '';
                        propsCtrl.clear();
                        montoCtrl.clear();
                      }
                      onChanged();
                    },
            ),
            if (data.danosPatrimoniales) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: propsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Propiedades afectadas (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (v) {
                  data.propiedadesAfectadas = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: montoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Monto daños patrimoniales (opcional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) {
                  data.montoDanos = v;
                  onChanged();
                },
                validator: (v) {
                  if (!data.danosPatrimoniales) return null;
                  final txt = (v ?? '').trim();
                  if (txt.isEmpty) return null;
                  final val = double.tryParse(txt.replaceAll(',', ''));
                  if (val == null) return 'Monto inválido';
                  if (val < 0) return 'No puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Si está activado, captura el monto o describe las propiedades.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
