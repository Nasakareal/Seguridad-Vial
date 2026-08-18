import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/comunicacion.dart';
import '../../models/comunicacion_adjunto.dart';
import '../../services/comunicacion_service.dart';
import 'mensaje_imagen.dart';

class MensajeBurbuja extends StatelessWidget {
  final Comunicacion mensaje;
  final ComunicacionService service;

  const MensajeBurbuja({
    super.key,
    required this.mensaje,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final esMio = mensaje.esMio;

    final colorBurbuja = esMio
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final colorTexto = esMio
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    final imagenes = mensaje.adjuntos
        .where((adjunto) => adjunto.esImagen)
        .toList();

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.fromLTRB(
          imagenes.isNotEmpty ? 5 : 12,
          imagenes.isNotEmpty ? 5 : 9,
          imagenes.isNotEmpty ? 5 : 12,
          6,
        ),
        decoration: BoxDecoration(
          color: colorBurbuja,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(esMio ? 18 : 5),
            bottomRight: Radius.circular(esMio ? 5 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (imagenes.isNotEmpty)
              _GaleriaMensaje(adjuntos: imagenes, service: service),
            if (imagenes.isNotEmpty && mensaje.tieneTexto)
              const SizedBox(height: 7),
            if (mensaje.tieneTexto)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: imagenes.isNotEmpty ? 7 : 0,
                    vertical: imagenes.isNotEmpty ? 2 : 0,
                  ),
                  child: Text(
                    mensaje.contenido!,
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: imagenes.isNotEmpty ? 7 : 0,
                right: imagenes.isNotEmpty ? 7 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _hora(mensaje.enviadoAt),
                    style: TextStyle(
                      color: colorTexto.withOpacity(.65),
                      fontSize: 10,
                    ),
                  ),
                  if (esMio) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done,
                      size: 13,
                      color: colorTexto.withOpacity(.65),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaleriaMensaje extends StatelessWidget {
  final List<ComunicacionAdjunto> adjuntos;
  final ComunicacionService service;

  const _GaleriaMensaje({required this.adjuntos, required this.service});

  @override
  Widget build(BuildContext context) {
    if (adjuntos.isEmpty) {
      return const SizedBox.shrink();
    }

    if (adjuntos.length == 1) {
      final adjunto = adjuntos.first;

      return MensajeImagen(
        adjunto: adjunto,
        service: service,
        width: 230,
        height: _altoImagenUnica(adjunto),
        borderRadius: 13,
        onTap: () {
          _abrirGaleria(context, adjuntos, service, indexInicial: 0);
        },
      );
    }

    final visibles = adjuntos.take(4).toList();

    return SizedBox(
      width: 235,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: visibles.length,
        itemBuilder: (context, index) {
          final adjunto = visibles[index];

          final restantes = adjuntos.length - 4;

          return Stack(
            fit: StackFit.expand,
            children: [
              MensajeImagen(
                adjunto: adjunto,
                service: service,
                width: 115,
                height: 115,
                borderRadius: 10,
                onTap: () {
                  _abrirGaleria(
                    context,
                    adjuntos,
                    service,
                    indexInicial: index,
                  );
                },
              ),
              if (index == 3 && restantes > 0)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _abrirGaleria(
                        context,
                        adjuntos,
                        service,
                        indexInicial: index,
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+$restantes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _altoImagenUnica(ComunicacionAdjunto adjunto) {
    final ratio = adjunto.relacionAspecto;

    if (ratio == null) {
      return 210;
    }

    if (ratio > 1.5) {
      return 155;
    }

    if (ratio < .75) {
      return 270;
    }

    return 210;
  }
}

class _VisorGaleriaMensaje extends StatefulWidget {
  final List<ComunicacionAdjunto> adjuntos;
  final ComunicacionService service;
  final int indexInicial;

  const _VisorGaleriaMensaje({
    required this.adjuntos,
    required this.service,
    required this.indexInicial,
  });

  @override
  State<_VisorGaleriaMensaje> createState() => _VisorGaleriaMensajeState();
}

class _VisorGaleriaMensajeState extends State<_VisorGaleriaMensaje> {
  late PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();

    _index = widget.indexInicial;

    _pageController = PageController(initialPage: widget.indexInicial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.adjuntos.length > 1
              ? '${_index + 1} de ${widget.adjuntos.length}'
              : widget.adjuntos.first.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.adjuntos.length,
        onPageChanged: (index) {
          setState(() {
            _index = index;
          });
        },
        itemBuilder: (context, index) {
          final adjunto = widget.adjuntos[index];

          return FutureBuilder<Uint8List>(
            future: widget.service.descargarAdjunto(adjunto.url),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || snapshot.data == null) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 60,
                  ),
                );
              }

              return InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void _abrirGaleria(
  BuildContext context,
  List<ComunicacionAdjunto> adjuntos,
  ComunicacionService service, {
  int indexInicial = 0,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _VisorGaleriaMensaje(
        adjuntos: adjuntos,
        service: service,
        indexInicial: indexInicial,
      ),
    ),
  );
}

String _hora(DateTime? fecha) {
  if (fecha == null) {
    return '';
  }

  final local = fecha.toLocal();

  final hora = local.hour.toString().padLeft(2, '0');

  final minuto = local.minute.toString().padLeft(2, '0');

  return '$hora:$minuto';
}
