import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/comunicacion.dart';
import '../../models/comunicacion_adjunto.dart';
import '../../models/comunicacion_usuario.dart';
import '../../services/comunicacion_notification_service.dart';
import '../../services/comunicacion_service.dart';

class ConversacionScreen extends StatefulWidget {
  final ComunicacionService service;
  final ComunicacionUsuario usuario;

  const ConversacionScreen({
    super.key,
    required this.service,
    required this.usuario,
  });

  @override
  State<ConversacionScreen> createState() => _ConversacionScreenState();
}

class _ConversacionScreenState extends State<ConversacionScreen> {
  final TextEditingController _textoController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final ImagePicker _imagePicker = ImagePicker();

  final ComunicacionNotificationService _notificationService =
      ComunicacionNotificationService.instance;

  StreamSubscription<ComunicacionPushEvento>? _pushSubscription;

  Timer? _refreshTimer;

  late ComunicacionUsuario _usuario;

  List<Comunicacion> _mensajes = [];
  List<XFile> _imagenesSeleccionadas = [];

  bool _cargando = true;
  bool _enviando = false;
  bool _actualizando = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _usuario = widget.usuario;

    _cargarConversacion();

    _pushSubscription = _notificationService.eventos.listen(_procesarPush);

    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_enviando && !_actualizando) {
        _cargarConversacion(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    _refreshTimer?.cancel();
    _textoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _procesarPush(ComunicacionPushEvento evento) {
    if (evento.accion != ComunicacionPushAccion.recibida ||
        evento.remitenteUserId != _usuario.id) {
      return;
    }

    _cargarConversacion(silencioso: true);
  }

  Future<void> _cargarConversacion({bool silencioso = false}) async {
    if (_actualizando) {
      return;
    }

    _actualizando = true;

    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final conversacion = await widget.service.obtenerConversacion(
        _usuario.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _usuario = conversacion.usuario;
        _mensajes = conversacion.mensajes;
        _cargando = false;
        _error = null;
      });

      _scrollAlFinal();
    } on ComunicacionApiException catch (e) {
      if (!mounted) {
        return;
      }

      if (!silencioso) {
        setState(() {
          _cargando = false;
          _error = e.mensaje;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (!silencioso) {
        setState(() {
          _cargando = false;
          _error = 'No fue posible cargar la conversación.';
        });
      }
    } finally {
      _actualizando = false;
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _mostrarSelectorImagen() async {
    if (_enviando || !_usuario.puedeEnviar) {
      return;
    }

    FocusScope.of(context).unfocus();

    final opcion = await showModalBottomSheet<_OrigenImagen>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Seleccionar de la galería'),
                subtitle: const Text('Puedes seleccionar varias imágenes'),
                onTap: () {
                  Navigator.of(context).pop(_OrigenImagen.galeria);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar fotografía'),
                onTap: () {
                  Navigator.of(context).pop(_OrigenImagen.camara);
                },
              ),
            ],
          ),
        );
      },
    );

    if (opcion == null) {
      return;
    }

    if (opcion == _OrigenImagen.galeria) {
      await _seleccionarGaleria();
    } else {
      await _tomarFoto();
    }
  }

  Future<void> _seleccionarGaleria() async {
    try {
      final archivos = await _imagePicker.pickMultiImage(imageQuality: 90);

      if (archivos.isEmpty) {
        return;
      }

      await _agregarImagenes(archivos);
    } catch (_) {
      _mostrarError('No fue posible abrir la galería.');
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final archivo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (archivo == null) {
        return;
      }

      await _agregarImagenes([archivo]);
    } catch (_) {
      _mostrarError('No fue posible abrir la cámara.');
    }
  }

  Future<void> _agregarImagenes(List<XFile> nuevas) async {
    final total = _imagenesSeleccionadas.length + nuevas.length;

    if (total > 10) {
      _mostrarError('Puedes enviar un máximo de 10 imágenes por mensaje.');

      return;
    }

    for (final archivo in nuevas) {
      try {
        final bytes = await archivo.length();

        if (bytes > 10 * 1024 * 1024) {
          _mostrarError('${archivo.name} supera el máximo de 10 MB.');

          return;
        }
      } catch (_) {
        _mostrarError('No fue posible leer una de las imágenes.');

        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _imagenesSeleccionadas.addAll(nuevas);
    });
  }

  void _quitarImagen(int index) {
    setState(() {
      _imagenesSeleccionadas.removeAt(index);
    });
  }

  Future<void> _enviar() async {
    if (_enviando || !_usuario.puedeEnviar) {
      return;
    }

    final texto = _textoController.text.trim();

    if (texto.isEmpty && _imagenesSeleccionadas.isEmpty) {
      return;
    }

    final imagenes = List<XFile>.from(_imagenesSeleccionadas);

    setState(() {
      _enviando = true;
    });

    try {
      final nueva = await widget.service.enviarMensaje(
        destinatarioUserId: _usuario.id,
        contenido: texto,
        imagenes: imagenes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _textoController.clear();
        _imagenesSeleccionadas.clear();

        if (!_mensajes.any((mensaje) => mensaje.id == nueva.id)) {
          _mensajes.add(nueva);
        }
      });

      _scrollAlFinal();

      await _cargarConversacion(silencioso: true);
    } on ComunicacionApiException catch (e) {
      _mostrarError(e.mensaje);
    } catch (_) {
      _mostrarError('No fue posible enviar el mensaje.');
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Text(
                _usuario.iniciales,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _usuario.nombreVisible,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_usuario.detalle.isNotEmpty)
                    Text(
                      _usuario.detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).appBarTheme.foregroundColor?.withOpacity(.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _actualizando
                ? null
                : () {
                    _cargarConversacion(silencioso: true);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _construirContenido()),
          if (!_usuario.puedeEnviar) _avisoSinPermiso(),
          _composer(),
        ],
      ),
    );
  }

  Widget _construirContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoErrorConversacion(
        mensaje: _error!,
        onRetry: () => _cargarConversacion(),
      );
    }

    if (_mensajes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarConversacion,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * .22),
            const Icon(Icons.chat_bubble_outline, size: 56),
            const SizedBox(height: 15),
            const Center(
              child: Text(
                'Aún no hay mensajes',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
              ),
            ),
            const SizedBox(height: 5),
            Center(
              child: Text(
                'Inicia la conversación con ${_usuario.nombreVisible}.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarConversacion,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 15, 12, 18),
        itemCount: _mensajes.length,
        itemBuilder: (context, index) {
          final mensaje = _mensajes[index];

          final mostrarFecha =
              index == 0 ||
              !_mismoDia(_mensajes[index - 1].enviadoAt, mensaje.enviadoAt);

          return Column(
            children: [
              if (mostrarFecha) _separadorFecha(mensaje.enviadoAt),
              _MensajeBurbuja(mensaje: mensaje, service: widget.service),
            ],
          );
        },
      ),
    );
  }

  Widget _separadorFecha(DateTime? fecha) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _fechaSeparador(fecha),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _avisoSinPermiso() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: Colors.orange.withOpacity(.12),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ya no tienes permiso para enviar mensajes a este usuario.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(.25),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imagenesSeleccionadas.isNotEmpty) _previewImagenes(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Adjuntar imagen',
                  onPressed: _usuario.puedeEnviar && !_enviando
                      ? _mostrarSelectorImagen
                      : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _textoController,
                    enabled: _usuario.puedeEnviar && !_enviando,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) {
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      _enviar();
                    },
                    decoration: InputDecoration(
                      hintText: 'Mensaje...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _botonEnviar(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonEnviar() {
    final tieneContenido =
        _textoController.text.trim().isNotEmpty ||
        _imagenesSeleccionadas.isNotEmpty;

    final habilitado = _usuario.puedeEnviar && !_enviando && tieneContenido;

    return SizedBox(
      width: 46,
      height: 46,
      child: FilledButton(
        onPressed: habilitado ? _enviar : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: _enviando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send, size: 20),
      ),
    );
  }

  Widget _previewImagenes() {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
        itemCount: _imagenesSeleccionadas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final archivo = _imagenesSeleccionadas[index];

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(archivo.path),
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 76,
                      height: 76,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    );
                  },
                ),
              ),
              Positioned(
                right: -5,
                top: -5,
                child: GestureDetector(
                  onTap: () => _quitarImagen(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 15,
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
}

class _MensajeBurbuja extends StatelessWidget {
  final Comunicacion mensaje;
  final ComunicacionService service;

  const _MensajeBurbuja({required this.mensaje, required this.service});

  @override
  Widget build(BuildContext context) {
    final esMio = mensaje.esMio;

    final color = esMio
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textoColor = esMio
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.fromLTRB(
          mensaje.tieneImagenes ? 5 : 12,
          mensaje.tieneImagenes ? 5 : 9,
          mensaje.tieneImagenes ? 5 : 12,
          6,
        ),
        decoration: BoxDecoration(
          color: color,
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
            if (mensaje.tieneImagenes)
              _GaleriaMensaje(
                adjuntos: mensaje.adjuntos
                    .where((adjunto) => adjunto.esImagen)
                    .toList(),
                service: service,
              ),
            if (mensaje.tieneImagenes && mensaje.tieneTexto)
              const SizedBox(height: 7),
            if (mensaje.tieneTexto)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mensaje.tieneImagenes ? 7 : 0,
                    vertical: mensaje.tieneImagenes ? 2 : 0,
                  ),
                  child: Text(
                    mensaje.contenido!,
                    style: TextStyle(
                      color: textoColor,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: mensaje.tieneImagenes ? 7 : 0,
                right: mensaje.tieneImagenes ? 7 : 0,
              ),
              child: Text(
                _hora(mensaje.enviadoAt),
                style: TextStyle(
                  color: textoColor.withOpacity(.65),
                  fontSize: 10,
                ),
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
      return _ImagenPrivada(
        adjunto: adjuntos.first,
        service: service,
        ancho: 230,
        alto: 210,
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
          final restante = adjuntos.length - 4;

          return Stack(
            fit: StackFit.expand,
            children: [
              _ImagenPrivada(
                adjunto: visibles[index],
                service: service,
                ancho: 115,
                alto: 115,
              ),
              if (index == 3 && restante > 0)
                GestureDetector(
                  onTap: () {
                    _abrirGaleria(
                      context,
                      adjuntos,
                      service,
                      indexInicial: index,
                    );
                  },
                  child: Container(
                    alignment: Alignment.center,
                    color: Colors.black54,
                    child: Text(
                      '+$restante',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
}

class _ImagenPrivada extends StatefulWidget {
  final ComunicacionAdjunto adjunto;
  final ComunicacionService service;
  final double ancho;
  final double alto;

  const _ImagenPrivada({
    required this.adjunto,
    required this.service,
    required this.ancho,
    required this.alto,
  });

  @override
  State<_ImagenPrivada> createState() => _ImagenPrivadaState();
}

class _ImagenPrivadaState extends State<_ImagenPrivada> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();

    _future = widget.service.descargarAdjunto(widget.adjunto.url);
  }

  @override
  void didUpdateWidget(covariant _ImagenPrivada oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.adjunto.url != widget.adjunto.url) {
      _future = widget.service.descargarAdjunto(widget.adjunto.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: widget.ancho,
            height: widget.alto,
            alignment: Alignment.center,
            color: Colors.black12,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            width: widget.ancho,
            height: widget.alto,
            alignment: Alignment.center,
            color: Colors.black12,
            child: const Icon(Icons.broken_image_outlined, size: 32),
          );
        }

        return GestureDetector(
          onTap: () {
            _abrirGaleria(context, [widget.adjunto], widget.service);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(
              snapshot.data!,
              width: widget.ancho,
              height: widget.alto,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}

class _GaleriaPantalla extends StatefulWidget {
  final List<ComunicacionAdjunto> adjuntos;

  final ComunicacionService service;
  final int indexInicial;

  const _GaleriaPantalla({
    required this.adjuntos,
    required this.service,
    required this.indexInicial,
  });

  @override
  State<_GaleriaPantalla> createState() => _GaleriaPantallaState();
}

class _GaleriaPantallaState extends State<_GaleriaPantalla> {
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

class _EstadoErrorConversacion extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() onRetry;

  const _EstadoErrorConversacion({
    required this.mensaje,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 55, color: Colors.red),
            const SizedBox(height: 15),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OrigenImagen { galeria, camara }

void _abrirGaleria(
  BuildContext context,
  List<ComunicacionAdjunto> adjuntos,
  ComunicacionService service, {
  int indexInicial = 0,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _GaleriaPantalla(
        adjuntos: adjuntos,
        service: service,
        indexInicial: indexInicial,
      ),
    ),
  );
}

bool _mismoDia(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }

  final uno = a.toLocal();
  final dos = b.toLocal();

  return uno.year == dos.year && uno.month == dos.month && uno.day == dos.day;
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

String _fechaSeparador(DateTime? fecha) {
  if (fecha == null) {
    return '';
  }

  final local = fecha.toLocal();

  final ahora = DateTime.now();

  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  final dia = DateTime(local.year, local.month, local.day);

  if (dia == hoy) {
    return 'Hoy';
  }

  if (dia == hoy.subtract(const Duration(days: 1))) {
    return 'Ayer';
  }

  final d = local.day.toString().padLeft(2, '0');

  final m = local.month.toString().padLeft(2, '0');

  return '$d/$m/${local.year}';
}
