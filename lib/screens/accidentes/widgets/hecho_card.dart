import 'package:flutter/material.dart';

import '../../../screens/accidentes/widgets/photo_block.dart';
import '../../../screens/accidentes/widgets/photos_strip.dart';

class HechoCard extends StatelessWidget {
  final Map<String, dynamic> hecho;

  final String folio;
  final String fecha;
  final String hora;
  final String situacion;
  final String perito;
  final String ubicacion;

  final String fotoHecho;
  final String fotoSituacion;
  final List<String> fotosVehiculos;
  final String fotoConvenio;

  final bool isDownloading;
  final bool isSending;
  final bool yaEnviado;

  final VoidCallback onTapShow;
  final VoidCallback onTapEdit;
  final VoidCallback? onDownload;
  final VoidCallback? onEnviarWhatsapp;

  const HechoCard({
    super.key,
    required this.hecho,
    required this.folio,
    required this.fecha,
    required this.hora,
    required this.situacion,
    required this.perito,
    required this.ubicacion,
    required this.fotoHecho,
    required this.fotoSituacion,
    required this.fotosVehiculos,
    required this.fotoConvenio,
    required this.isDownloading,
    required this.isSending,
    required this.yaEnviado,
    required this.onTapShow,
    required this.onTapEdit,
    required this.onDownload,
    required this.onEnviarWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapShow,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.directions_car),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Folio: $folio',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('Fecha: $fecha ${hora == '—' ? '' : hora}'.trim()),
                    Text('Ubicación: $ubicacion'),
                    Text('Situación: $situacion'),
                    Text('Perito: $perito'),
                    PhotoBlock(label: 'Foto del hecho', url: fotoHecho),
                    PhotoBlock(label: 'Foto de la situacion', url: fotoSituacion),
                    if (fotosVehiculos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Fotos de vehículos: ${fotosVehiculos.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    PhotosStrip(urls: fotosVehiculos),
                    PhotoBlock(label: 'Convenio / Descargo', url: fotoConvenio),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onEnviarWhatsapp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: yaEnviado
                              ? Colors.grey
                              : Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: isSending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                yaEnviado ? 'Enviado' : 'Enviar',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: isDownloading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download),
                          tooltip: 'Descargar informe',
                          onPressed: onDownload,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: onTapEdit,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
