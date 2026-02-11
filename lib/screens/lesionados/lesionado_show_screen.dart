import 'package:flutter/material.dart';

class LesionadoShowScreen extends StatelessWidget {
  const LesionadoShowScreen({super.key});

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _boolSiNo(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Sí' : 'No';
    final s = v.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'si' || s == 'sí') return 'Sí';
    if (s == '0' || s == 'false' || s == 'no') return 'No';
    return _safeText(v);
  }

  Color _tipoColor(String tipo) {
    switch (tipo) {
      case 'Leve':
        return Colors.green;
      case 'Moderada':
        return Colors.orange;
      case 'Grave':
        return Colors.red;
      case 'Fallecido':
        return Colors.black87;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    Map<String, dynamic>? it;
    int hechoId = 0;

    // Esperado ideal: {'hechoId': 123, 'item': {...}}
    if (args is Map) {
      if (args['item'] is Map) {
        it = Map<String, dynamic>.from(args['item'] as Map);
        hechoId = int.tryParse((args['hechoId'] ?? '0').toString()) ?? 0;
      } else {
        // por si te mandaron directo el item
        it = Map<String, dynamic>.from(args);
        final hid = it['hecho_id'] ?? it['hechos_id'] ?? it['accidente_id'];
        hechoId = int.tryParse((hid ?? '0').toString()) ?? 0;
      }
    }

    if (it == null) {
      return const Scaffold(
        body: Center(child: Text('No se recibió información del lesionado')),
      );
    }

    final id = int.tryParse((it['id'] ?? '0').toString()) ?? 0;

    final nombre = _safeText(it['nombre']);
    final edad = it['edad'];
    final sexo = it['sexo'];
    final tipoLesion = _safeText(it['tipo_lesion']);
    final hospitalizado = it['hospitalizado'];
    final hospital = it['hospital'];
    final atencionEnSitio = it['atencion_en_sitio'];
    final ambulancia = it['ambulancia'];
    final paramedico = it['paramedico'];
    final observaciones = it['observaciones'];
    final createdAt = it['created_at'] ?? it['fecha'] ?? it['fecha_registro'];

    final tipoColor = _tipoColor(tipoLesion);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('Lesionado #$id'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _CardShell(
            title: 'Datos generales',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Nombre', nombre),
                _row('ID', '$id'),
                if (hechoId > 0) _row('Hecho', '$hechoId'),
                if (edad != null) _row('Edad', _safeText(edad)),
                if (sexo != null) _row('Sexo', _safeText(sexo)),
                if (createdAt != null) _row('Registrado', _safeText(createdAt)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Tipo lesión:', style: _labelStyle),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tipoColor.withOpacity(.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tipoColor.withOpacity(.25)),
                      ),
                      child: Text(
                        tipoLesion.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: tipoColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _CardShell(
            title: 'Atención médica',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Hospitalizado', _boolSiNo(hospitalizado)),
                if (_boolSiNo(hospitalizado) == 'Sí')
                  _row('Hospital', _safeText(hospital)),
                _row('Atención en sitio', _boolSiNo(atencionEnSitio)),
                if (ambulancia != null && _safeText(ambulancia) != '—')
                  _row('Ambulancia', _safeText(ambulancia)),
                if (paramedico != null && _safeText(paramedico) != '—')
                  _row('Paramédico', _safeText(paramedico)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (observaciones != null && _safeText(observaciones) != '—')
            _CardShell(
              title: 'Observaciones',
              child: Text(
                _safeText(observaciones),
                style: const TextStyle(fontSize: 14),
              ),
            ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (hechoId <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se pudo abrir editar: falta hechoId.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pushNamed(
                      context,
                      '/lesionados/edit',
                      arguments: {'hechoId': hechoId, 'item': it},
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Regresar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: _labelStyle)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontWeight: FontWeight.w800,
  color: Color(0xFF334155),
);

class _CardShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
