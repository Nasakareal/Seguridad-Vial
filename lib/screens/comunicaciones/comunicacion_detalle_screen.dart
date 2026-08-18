import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/comunicacion.dart';
import '../../models/comunicacion_adjunto.dart';
import '../../models/comunicacion_destinatario.dart';
import '../../services/comunicacion_service.dart';

class ComunicacionDetalleScreen extends StatefulWidget {
  final ComunicacionService service;
  final int comunicacionId;

  const ComunicacionDetalleScreen({
    super.key,
    required this.service,
    required this.comunicacionId,
  });

  @override
  State<ComunicacionDetalleScreen> createState() =>
      _ComunicacionDetalleScreenState();
}

class _ComunicacionDetalleScreenState extends State<ComunicacionDetalleScreen> {
  ComunicacionDetalle? _detalle;

  bool _cargando = true;
  bool _procesandoEnterado = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final detalle = await widget.service.obtenerComunicacion(
        widget.comunicacionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detalle = detalle;
        _cargando = false;
        _error = null;
      });
    } on ComunicacionApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cargando = false;
        _error = 'No fue posible cargar la comunicación.';
      });
    }
  }

  Future<void> _confirmarEnterado() async {
    if (_procesandoEnterado || _detalle == null) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar enterado'),
          content: const Text(
            'Se registrará la fecha y hora en que confirmaste esta comunicación.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.done_all),
              label: const Text('Estoy enterado'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _procesandoEnterado = true;
    });

    try {
      await widget.service.marcarEnterado(widget.comunicacionId);

      await _cargar(silencioso: true);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Se registró tu confirmación de enterado.'),
          ),
        );
    } on ComunicacionApiException catch (e) {
      _mostrarError(e.mensaje);
    } catch (_) {
      _mostrarError('No fue posible registrar el enterado.');
    } finally {
      if (mounted) {
        setState(() {
          _procesandoEnterado = false;
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
        title: const Text('Comunicación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : () => _cargar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _construirBody(),
    );
  }

  Widget _construirBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(mensaje: _error!, onRetry: _cargar);
    }

    final detalle = _detalle;

    if (detalle == null) {
      return const Center(child: Text('No se encontró la comunicación.'));
    }

    final comunicacion = detalle.comunicacion;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        children: [
          _encabezado(comunicacion),
          const SizedBox(height: 14),
          _informacionGeneral(comunicacion),
          if (comunicacion.tieneTexto) ...[
            const SizedBox(height: 14),
            _contenido(comunicacion),
          ],
          if (comunicacion.tieneImagenes) ...[
            const SizedBox(height: 14),
            _adjuntos(comunicacion),
          ],
          if (!detalle.esRemitente) ...[
            const SizedBox(height: 14),
            _estadoDestinatario(detalle),
          ],
          if (detalle.esRemitente) ...[
            const SizedBox(height: 14),
            _resumenDestinatarios(detalle),
            const SizedBox(height: 14),
            _listaDestinatarios(detalle.destinatarios, comunicacion),
          ],
        ],
      ),
    );
  }

  Widget _encabezado(Comunicacion comunicacion) {
    final color = _colorTipo(comunicacion.tipo);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconoTipo(comunicacion.tipo),
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _textoTipo(comunicacion.tipo),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    comunicacion.titulo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fechaCompleta(comunicacion.enviadoAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _informacionGeneral(Comunicacion comunicacion) {
    final remitente = comunicacion.remitente?.nombreVisible ?? 'Usuario';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DatoFila(
              icon: Icons.person_outline,
              titulo: 'Remitente',
              valor: remitente,
            ),
            const Divider(height: 24),
            _DatoFila(
              icon: Icons.groups_outlined,
              titulo: 'Destinatario',
              valor: _textoDestino(comunicacion),
            ),
            const Divider(height: 24),
            _DatoFila(
              icon: Icons.verified_outlined,
              titulo: 'Confirmación',
              valor: comunicacion.requiereEnterado
                  ? 'Requiere enterado'
                  : 'No requiere enterado',
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido(Comunicacion comunicacion) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Contenido',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              comunicacion.contenido!.trim(),
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adjuntos(Comunicacion comunicacion) {
    final imagenes = comunicacion.adjuntos
        .where((item) => item.esImagen)
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  imagenes.length == 1
                      ? '1 imagen adjunta'
                      : '${imagenes.length} imágenes adjuntas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GaleriaAdjuntos(adjuntos: imagenes, service: widget.service),
          ],
        ),
      ),
    );
  }

  Widget _estadoDestinatario(ComunicacionDetalle detalle) {
    final comunicacion = detalle.comunicacion;

    final registro = detalle.registroDestinatario;

    if (registro == null) {
      return const SizedBox.shrink();
    }

    if (comunicacion.requiereEnterado && registro.estaEnterado) {
      return Card(
        margin: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.done_all, color: Colors.green, size: 27),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enterado',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirmado el ${_fechaCompleta(registro.enteradoAt)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (comunicacion.requiereEnterado) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.priority_high, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta comunicación requiere que confirmes de enterado.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _procesandoEnterado ? null : _confirmarEnterado,
                  icon: _procesandoEnterado
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all),
                  label: Text(
                    _procesandoEnterado ? 'Registrando...' : 'ENTERADO',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.done, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                registro.estaLeido
                    ? 'Leído el ${_fechaCompleta(registro.leidoAt)}'
                    : 'Comunicación recibida',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenDestinatarios(ComunicacionDetalle detalle) {
    final destinatarios = detalle.destinatarios;

    final leidos = destinatarios.where((item) => item.estaLeido).length;

    final enterados = destinatarios.where((item) => item.estaEnterado).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seguimiento',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ResumenNumero(
                    numero: destinatarios.length,
                    texto: 'Destinatarios',
                    icon: Icons.groups_outlined,
                  ),
                ),
                Expanded(
                  child: _ResumenNumero(
                    numero: leidos,
                    texto: 'Leídos',
                    icon: Icons.visibility_outlined,
                  ),
                ),
                if (detalle.comunicacion.requiereEnterado)
                  Expanded(
                    child: _ResumenNumero(
                      numero: enterados,
                      texto: 'Enterados',
                      icon: Icons.done_all,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaDestinatarios(
    List<ComunicacionDestinatario> destinatarios,
    Comunicacion comunicacion,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Text(
                'Destinatarios',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (destinatarios.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No hay destinatarios registrados.')),
              )
            else
              ...destinatarios.map((registro) {
                return _DestinatarioTile(
                  registro: registro,
                  requiereEnterado: comunicacion.requiereEnterado,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DatoFila extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;

  const _DatoFila({
    required this.icon,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResumenNumero extends StatelessWidget {
  final int numero;
  final String texto;
  final IconData icon;

  const _ResumenNumero({
    required this.numero,
    required this.texto,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 5),
        Text(
          numero.toString(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DestinatarioTile extends StatelessWidget {
  final ComunicacionDestinatario registro;

  final bool requiereEnterado;

  const _DestinatarioTile({
    required this.registro,
    required this.requiereEnterado,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String estado;

    if (requiereEnterado && registro.estaEnterado) {
      color = Colors.green;
      icon = Icons.done_all;
      estado = 'Enterado';
    } else if (registro.estaLeido) {
      if (requiereEnterado) {
        color = Colors.orange;
        icon = Icons.visibility_outlined;
        estado = 'Leído · falta enterado';
      } else {
        color = Colors.green;
        icon = Icons.done;
        estado = 'Leído';
      }
    } else {
      color = Colors.red;
      icon = Icons.schedule_outlined;
      estado = 'Pendiente';
    }

    return ListTile(
      leading: CircleAvatar(child: Text(_iniciales(registro.nombreVisible))),
      title: Text(
        registro.nombreVisible,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (registro.unidad != null || registro.turno != null)
            Text(
              [
                if (registro.unidad != null) registro.unidad!,
                if (registro.turno != null) registro.turno!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  estado,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaleriaAdjuntos extends StatelessWidget {
  final List<ComunicacionAdjunto> adjuntos;

  final ComunicacionService service;

  const _GaleriaAdjuntos({required this.adjuntos, required this.service});

  @override
  Widget build(BuildContext context) {
    if (adjuntos.isEmpty) {
      return const SizedBox.shrink();
    }

    if (adjuntos.length == 1) {
      return SizedBox(
        height: 240,
        width: double.infinity,
        child: _ImagenAdjunto(
          adjunto: adjuntos.first,
          service: service,
          todos: adjuntos,
          index: 0,
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: adjuntos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
      ),
      itemBuilder: (context, index) {
        return _ImagenAdjunto(
          adjunto: adjuntos[index],
          service: service,
          todos: adjuntos,
          index: index,
        );
      },
    );
  }
}

class _ImagenAdjunto extends StatefulWidget {
  final ComunicacionAdjunto adjunto;
  final ComunicacionService service;

  final List<ComunicacionAdjunto> todos;

  final int index;

  const _ImagenAdjunto({
    required this.adjunto,
    required this.service,
    required this.todos,
    required this.index,
  });

  @override
  State<_ImagenAdjunto> createState() => _ImagenAdjuntoState();
}

class _ImagenAdjuntoState extends State<_ImagenAdjunto> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();

    _future = widget.service.descargarAdjunto(widget.adjunto.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image_outlined, size: 42),
          );
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _VisorImagenes(
                  adjuntos: widget.todos,
                  service: widget.service,
                  indexInicial: widget.index,
                ),
              ),
            );
          },
          child: Hero(
            tag: 'comunicacion_adjunto_${widget.adjunto.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VisorImagenes extends StatefulWidget {
  final List<ComunicacionAdjunto> adjuntos;

  final ComunicacionService service;

  final int indexInicial;

  const _VisorImagenes({
    required this.adjuntos,
    required this.service,
    required this.indexInicial,
  });

  @override
  State<_VisorImagenes> createState() => _VisorImagenesState();
}

class _VisorImagenesState extends State<_VisorImagenes> {
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
                    size: 60,
                    color: Colors.white,
                  ),
                );
              }

              return InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: 'comunicacion_adjunto_${adjunto.id}',
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
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

class _EstadoError extends StatelessWidget {
  final String mensaje;

  final Future<void> Function() onRetry;

  const _EstadoError({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Colors.red, size: 55),
            const SizedBox(height: 15),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 18),
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

IconData _iconoTipo(String tipo) {
  switch (tipo.toLowerCase()) {
    case 'orden':
      return Icons.campaign_outlined;

    case 'aviso':
      return Icons.notifications_active_outlined;

    case 'mensaje':
      return Icons.chat_bubble_outline;

    default:
      return Icons.mail_outline;
  }
}

Color _colorTipo(String tipo) {
  switch (tipo.toLowerCase()) {
    case 'orden':
      return Colors.red;

    case 'aviso':
      return Colors.orange;

    case 'mensaje':
      return Colors.blue;

    default:
      return Colors.blueGrey;
  }
}

String _textoTipo(String tipo) {
  switch (tipo.toLowerCase()) {
    case 'orden':
      return 'ORDEN';

    case 'aviso':
      return 'AVISO';

    case 'mensaje':
      return 'MENSAJE';

    default:
      return tipo.toUpperCase();
  }
}

String _textoDestino(Comunicacion comunicacion) {
  switch (comunicacion.alcance) {
    case 'todos':
      return 'Todo el personal';

    case 'unidad':
      return comunicacion.unidad?.nombre ?? 'Unidad';

    case 'unidad_turno':
      final unidad = comunicacion.unidad?.nombre ?? 'Unidad';

      final turno = comunicacion.turno?.nombre ?? 'Turno';

      return '$unidad · $turno';

    case 'subdirectores':
      return 'Todos los Subdirectores';

    case 'rol':
      return comunicacion.rol?.nombre ?? 'Rol';

    case 'usuario':
      return comunicacion.destinatario?.nombreVisible ?? 'Usuario';

    default:
      return 'Destinatarios';
  }
}

String _fechaCompleta(DateTime? fecha) {
  if (fecha == null) {
    return '-';
  }

  final local = fecha.toLocal();

  final dia = local.day.toString().padLeft(2, '0');

  final mes = local.month.toString().padLeft(2, '0');

  final hora = local.hour.toString().padLeft(2, '0');

  final minuto = local.minute.toString().padLeft(2, '0');

  return '$dia/$mes/${local.year} $hora:$minuto';
}

String _iniciales(String nombre) {
  final partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((parte) => parte.isNotEmpty)
      .toList();

  if (partes.isEmpty) {
    return 'U';
  }

  if (partes.length == 1) {
    return partes.first.substring(0, 1).toUpperCase();
  }

  return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
      .toUpperCase();
}
