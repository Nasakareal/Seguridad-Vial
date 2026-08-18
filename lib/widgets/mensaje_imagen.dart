import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/comunicacion_adjunto.dart';
import '../../services/comunicacion_service.dart';

class MensajeImagen extends StatefulWidget {
  final ComunicacionAdjunto adjunto;
  final ComunicacionService service;

  final double? width;
  final double? height;
  final double borderRadius;

  final BoxFit fit;

  final VoidCallback? onTap;

  const MensajeImagen({
    super.key,
    required this.adjunto,
    required this.service,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  State<MensajeImagen> createState() => _MensajeImagenState();
}

class _MensajeImagenState extends State<MensajeImagen> {
  late Future<Uint8List> _imagenFuture;

  @override
  void initState() {
    super.initState();

    _imagenFuture = _cargarImagen();
  }

  @override
  void didUpdateWidget(covariant MensajeImagen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.adjunto.url != widget.adjunto.url ||
        oldWidget.adjunto.id != widget.adjunto.id) {
      _imagenFuture = _cargarImagen();
    }
  }

  Future<Uint8List> _cargarImagen() {
    return widget.service.descargarAdjunto(widget.adjunto.url);
  }

  Future<void> _reintentar() async {
    setState(() {
      _imagenFuture = _cargarImagen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imagenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _contenedor(
            context,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return _contenedor(
            context,
            child: InkWell(
              onTap: _reintentar,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined, size: 31),
                    SizedBox(height: 5),
                    Text('Reintentar', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          );
        }

        final imagen = ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return _contenedor(
                context,
                child: InkWell(
                  onTap: _reintentar,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 31),
                  ),
                ),
              );
            },
          ),
        );

        if (widget.onTap == null) {
          return imagen;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: imagen,
          ),
        );
      },
    );
  }

  Widget _contenedor(BuildContext context, {required Widget child}) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
