import 'package:flutter/material.dart';

import '../../models/conduce_legalidad.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/safe_network_image.dart';
import 'conduce_legalidad_module.dart';

class ConduceLegalidadCapturaShowScreen extends StatelessWidget {
  final ConduceLegalidadOperativo operativo;
  final ConduceLegalidadCaptura captura;
  final ConduceLegalidadModule module;

  const ConduceLegalidadCapturaShowScreen({
    super.key,
    required this.operativo,
    required this.captura,
    this.module = ConduceLegalidadModule.conduceLegalidad,
  });

  String get _folio =>
      '${operativo.ticketFolioPrefix}-${operativo.id}-${captura.id}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalle $_folio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(context),
          const SizedBox(height: 14),
          _DetailSection(
            icon: Icons.assignment_ind_outlined,
            title: 'Intervención',
            rows: [
              _DetailEntry('Folio', _folio),
              _DetailEntry('Fecha', captura.fecha),
              _DetailEntry('Hora', captura.hora),
              _DetailEntry('Capturó', captura.creador?.nombre),
              _DetailEntry('Agente', captura.agenteNombre),
              _DetailEntry('Número de placa', captura.agenteNumeroPlaca),
              _DetailEntry('Adscripción del agente', captura.agenteAdscripcion),
              _DetailEntry('Unidad del registro', captura.unidad?.nombre),
              _DetailEntry('Delegación', captura.delegacion?.nombre),
            ],
          ),
          const SizedBox(height: 14),
          _DetailSection(
            icon: Icons.location_on_outlined,
            title: 'Ubicación',
            rows: [
              _DetailEntry('Municipio', captura.municipio),
              _DetailEntry('Lugar', captura.lugar),
              _DetailEntry('Coordenadas', captura.coordenadasTexto),
              if ((captura.coordenadasTexto ?? '').trim().isEmpty &&
                  captura.lat != null &&
                  captura.lng != null)
                _DetailEntry('Coordenadas', '${captura.lat}, ${captura.lng}'),
            ],
          ),
          if (captura.fundamentos.isNotEmpty ||
              captura.fundamentoEfectivo != null) ...[
            const SizedBox(height: 14),
            _FundamentosSection(captura: captura),
          ],
          if ((captura.narrativa ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _TextSection(
              icon: Icons.notes_outlined,
              title: 'Narrativa',
              text: captura.narrativa!,
            ),
          ],
          if (captura.vehiculos.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...captura.vehiculos.indexed.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _VehiculoSection(index: item.$1 + 1, vehiculo: item.$2),
              ),
            ),
          ],
          if (captura.personas.isNotEmpty) ...[
            ...captura.personas.indexed.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PersonaSection(index: item.$1 + 1, persona: item.$2),
              ),
            ),
          ],
          if ((captura.observaciones ?? '').trim().isNotEmpty)
            _TextSection(
              icon: Icons.comment_outlined,
              title: 'Observaciones',
              text: captura.observaciones!,
            ),
          if (captura.fotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FotosSection(folio: _folio, fotos: captura.fotos),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _folio,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            module.operativoNombre,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderPill(
                icon: Icons.directions_car_outlined,
                text: '${captura.vehiculos.length} vehículos',
              ),
              _HeaderPill(
                icon: Icons.people_outline,
                text: '${captura.personas.length} personas',
              ),
              _HeaderPill(
                icon: Icons.photo_library_outlined,
                text: '${captura.fotos.length} fotos',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FundamentosSection extends StatelessWidget {
  final ConduceLegalidadCaptura captura;

  const _FundamentosSection({required this.captura});

  @override
  Widget build(BuildContext context) {
    final fundamentos = captura.fundamentos.isNotEmpty
        ? captura.fundamentos
        : <ConduceLegalidadFundamento>[
            if (captura.fundamentoEfectivo != null) captura.fundamentoEfectivo!,
          ];

    return _CardSection(
      icon: Icons.gavel_outlined,
      title: fundamentos.length == 1 ? 'Fundamento' : 'Fundamentos',
      child: Column(
        children: fundamentos.indexed.map((item) {
          final fundamento = item.$2;
          final legal = fundamento.fundamentoLegal?.trim() ?? '';
          return Padding(
            padding: EdgeInsets.only(
              bottom: item.$1 == fundamentos.length - 1 ? 0 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fundamento.display,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (legal.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(legal),
                ],
                const SizedBox(height: 5),
                Text(
                  fundamento.sancionResumen,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (item.$1 != fundamentos.length - 1)
                  const Divider(height: 22),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VehiculoSection extends StatelessWidget {
  final int index;
  final ConduceLegalidadVehiculo vehiculo;

  const _VehiculoSection({required this.index, required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final nombre = [
      vehiculo.marca,
      vehiculo.linea,
      vehiculo.modelo,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');

    return _DetailSection(
      icon: Icons.directions_car_outlined,
      title: 'Vehículo $index${nombre.isEmpty ? '' : ' · $nombre'}',
      rows: [
        _DetailEntry('Tipo general', vehiculo.tipoGeneral),
        _DetailEntry('Tipo o carrocería', vehiculo.tipo),
        _DetailEntry('Marca', vehiculo.marca),
        _DetailEntry('Línea', vehiculo.linea),
        _DetailEntry('Modelo', vehiculo.modelo),
        _DetailEntry('Color', vehiculo.color),
        _DetailEntry('Placas', vehiculo.placas, fallback: 'Sin placas'),
        _DetailEntry('Estado de placas', vehiculo.estadoPlacas),
        _DetailEntry('Número de serie', vehiculo.serie),
        _DetailEntry('Número de inventario', vehiculo.numeroInventario),
        if (vehiculo.capacidadPersonas > 0)
          _DetailEntry('Capacidad', '${vehiculo.capacidadPersonas} personas'),
        _DetailEntry('Tipo de servicio', vehiculo.tipoServicio),
        _DetailEntry(
          'Titular de tarjeta de circulación',
          vehiculo.tarjetaCirculacionNombre,
        ),
        _DetailEntry('Aseguradora', vehiculo.aseguradora),
        if (vehiculo.montoDanos != null)
          _DetailEntry(
            'Monto de daños',
            '\$${vehiculo.montoDanos!.toStringAsFixed(2)}',
          ),
        _DetailEntry('Partes dañadas', vehiculo.partesDanadas),
        if (vehiculo.antecedenteVehiculo)
          const _DetailEntry('Antecedente del vehículo', 'Sí'),
        if (vehiculo.retencionVehiculo)
          const _DetailEntry('Retención del vehículo', 'Sí'),
        _DetailEntry('Motivo de retención', vehiculo.motivoRetencion),
        _DetailEntry('Grúa', vehiculo.grua),
        _DetailEntry('Corralón', vehiculo.corralon),
        _DetailEntry('Observaciones', vehiculo.observaciones),
      ],
    );
  }
}

class _PersonaSection extends StatelessWidget {
  final int index;
  final ConduceLegalidadPersona persona;

  const _PersonaSection({required this.index, required this.persona});

  @override
  Widget build(BuildContext context) {
    final vigencia = persona.permanente
        ? 'Permanente'
        : persona.vigenciaLicencia;
    return _DetailSection(
      icon: Icons.badge_outlined,
      title: 'Persona $index · ${persona.nombreCompleto ?? 'Sin nombre'}',
      rows: [
        _DetailEntry('Nombre', persona.nombreCompleto),
        if (persona.edad != null) _DetailEntry('Edad', '${persona.edad} años'),
        if (persona.edad == null) _DetailEntry('Edad', persona.edadTexto),
        _DetailEntry('Teléfono', persona.telefono),
        _DetailEntry('Domicilio', persona.domicilio),
        _DetailEntry('Sexo', persona.sexo),
        _DetailEntry('Nacionalidad', persona.nacionalidad),
        _DetailEntry('Ocupación', persona.ocupacion),
        _DetailEntry('Estado civil', persona.estadoCivil),
        _DetailEntry('Tipo de licencia', persona.tipoLicencia),
        _DetailEntry('Estado de licencia', persona.estadoLicencia),
        _DetailEntry('Número de licencia', persona.numeroLicencia),
        _DetailEntry('Vigencia', vigencia),
        _DetailEntry('Edad aproximada', persona.edadAproximada),
        _DetailEntry('Complexión', persona.complexion),
        _DetailEntry('Estatura', persona.estatura),
        _DetailEntry('Tez', persona.tez),
        _DetailEntry('Cabello', persona.cabello),
        _DetailEntry(
          'Prenda superior',
          [persona.prendaSuperior, persona.colorSuperior]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(' · '),
        ),
        _DetailEntry(
          'Prenda inferior',
          [persona.prendaInferior, persona.colorInferior]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(' · '),
        ),
        _DetailEntry(
          'Calzado',
          [persona.calzado, persona.colorCalzado]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(' · '),
        ),
        if (persona.rasgosVisibles.isNotEmpty)
          _DetailEntry('Rasgos visibles', persona.rasgosVisibles.join(', ')),
        _DetailEntry('Observaciones', persona.observaciones),
      ],
    );
  }
}

class _FotosSection extends StatelessWidget {
  final String folio;
  final List<ConduceLegalidadFoto> fotos;

  const _FotosSection({required this.folio, required this.fotos});

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      icon: Icons.photo_library_outlined,
      title: 'Evidencias fotográficas (${fotos.length})',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fotos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final foto = fotos[index];
          final previewUrl = foto.previewUrl ?? '';
          final fullUrl = foto.fotoUrl ?? previewUrl;
          return Material(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: fullUrl.trim().isEmpty
                  ? null
                  : () => showPhotoViewer(
                      context: context,
                      title: '$folio · Foto ${index + 1}',
                      photoUrl: fullUrl,
                    ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(
                    previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_DetailEntry> rows;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) => row.visible).toList();
    return _CardSection(
      icon: icon,
      title: title,
      child: visibleRows.isEmpty
          ? Text(
              'Sin datos registrados.',
              style: TextStyle(color: Colors.grey.shade700),
            )
          : Column(
              children: visibleRows.indexed.map((item) {
                return Column(
                  children: [
                    if (item.$1 > 0) const Divider(height: 18),
                    _DetailRow(entry: item.$2),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _TextSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _TextSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      icon: icon,
      title: title,
      child: SelectableText(text, style: const TextStyle(height: 1.45)),
    );
  }
}

class _CardSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _CardSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailEntry {
  final String label;
  final Object? value;
  final String? fallback;

  const _DetailEntry(this.label, this.value, {this.fallback});

  String get text {
    final current = value?.toString().trim() ?? '';
    return current.isEmpty ? (fallback?.trim() ?? '') : current;
  }

  bool get visible => text.isNotEmpty;
}

class _DetailRow extends StatelessWidget {
  final _DetailEntry entry;

  const _DetailRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            entry.label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: SelectableText(entry.text)),
      ],
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
