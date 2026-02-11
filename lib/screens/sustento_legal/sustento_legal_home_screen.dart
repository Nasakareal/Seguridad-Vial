import 'package:flutter/material.dart';

class SustentoLegalHomeScreen extends StatelessWidget {
  const SustentoLegalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sustento Legal Operativo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar fundamento legal',
            onPressed: () {
              Navigator.pushNamed(context, '/sustento-legal/buscar');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _card(
              context,
              icon: Icons.security,
              title: 'Control\nPreventivo',
              categoriaId: 'control_preventivo',
            ),
            _card(
              context,
              icon: Icons.search,
              title: 'Revisión /\nInspección',
              categoriaId: 'revision',
            ),
            _card(
              context,
              icon: Icons.person_off,
              title: 'Detención',
              categoriaId: 'detencion',
            ),
            _card(
              context,
              icon: Icons.directions_car,
              title: 'Aseguramiento\nde Vehículo',
              categoriaId: 'aseguramiento',
            ),
            _card(
              context,
              icon: Icons.car_crash,
              title: 'Siniestros\nde Tránsito',
              categoriaId: 'siniestros',
            ),
            _card(
              context,
              icon: Icons.local_parking,
              title: 'Resguardo /\nCorralón',
              categoriaId: 'resguardo_remision',
            ),
            _card(
              context,
              icon: Icons.rule,
              title: 'Procedimiento\nAdministrativo',
              categoriaId: 'procedimiento_admin',
            ),
            _card(
              context,
              icon: Icons.gavel,
              title: 'Uso de\nla Fuerza',
              categoriaId: 'uso_fuerza',
            ),
            _card(
              context,
              icon: Icons.record_voice_over,
              title: 'Derechos\nde Personas',
              categoriaId: 'derechos',
            ),
            _card(
              context,
              icon: Icons.inventory_2,
              title: 'Cadena de\nCustodia',
              categoriaId: 'cadena_custodia',
            ),
            _card(
              context,
              icon: Icons.assignment,
              title: 'Primer\nRespondiente',
              categoriaId: 'primer_respondiente',
            ),
            _card(
              context,
              icon: Icons.edit_document,
              title: 'Documentación\ny Actas',
              categoriaId: 'documentacion',
            ),
            _card(
              context,
              icon: Icons.analytics,
              title: 'Peritaje /\nDictamen Vial',
              categoriaId: 'peritaje_vial',
            ),
            _card(
              context,
              icon: Icons.health_and_safety,
              title: 'Lesionados\ny Atención',
              categoriaId: 'lesionados',
            ),
            _card(
              context,
              icon: Icons.warning,
              title: 'Riesgo Vial\ny Prevención',
              categoriaId: 'riesgo_vial',
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String categoriaId,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/sustento-legal/categoria',
          arguments: {
            'categoriaId': categoriaId,
            'titulo': title.replaceAll('\n', ' '),
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade100),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.blue.shade700),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
