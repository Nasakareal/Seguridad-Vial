import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/comunicacion.dart';
import '../../models/comunicacion_destinatario.dart';
import '../../models/comunicacion_usuario.dart';
import '../../services/comunicacion_notification_service.dart';
import '../../services/comunicacion_service.dart';
import 'comunicacion_create_screen.dart';
import 'comunicacion_detalle_screen.dart';
import 'conversacion_screen.dart';

class ComunicacionesScreen extends StatefulWidget {
  final ComunicacionService service;

  const ComunicacionesScreen({super.key, required this.service});

  @override
  State<ComunicacionesScreen> createState() => _ComunicacionesScreenState();
}

class _ComunicacionesScreenState extends State<ComunicacionesScreen> {
  final ComunicacionNotificationService _notificationService =
      ComunicacionNotificationService.instance;

  StreamSubscription<ComunicacionPushEvento>? _pushSubscription;

  List<ComunicacionDestinatario> _recibidas = [];
  List<Comunicacion> _enviadas = [];

  Map<String, bool> _capacidades = {};

  int _noLeidas = 0;
  int _totalRecibidas = 0;
  int _totalEnviadas = 0;

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _cargar();

    _pushSubscription = _notificationService.eventos.listen((evento) {
      if (evento.accion == ComunicacionPushAccion.recibida) {
        _cargar(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final bandeja = await widget.service.obtenerBandeja(perPage: 50);

      if (!mounted) {
        return;
      }

      setState(() {
        _recibidas = bandeja.recibidas;
        _enviadas = bandeja.enviadas;
        _capacidades = bandeja.capacidades;
        _noLeidas = bandeja.noLeidas;

        _totalRecibidas = bandeja.paginacionRecibidas.total;

        _totalEnviadas = bandeja.paginacionEnviadas.total;

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
        _error = 'No fue posible cargar las comunicaciones.';
      });
    }
  }

  Future<void> _abrirRecibida(ComunicacionDestinatario registro) async {
    final comunicacion = registro.comunicacion;

    if (comunicacion == null) {
      return;
    }

    if (comunicacion.esMensaje && comunicacion.remitenteUserId > 0) {
      final usuario =
          comunicacion.remitente ??
          ComunicacionUsuario(
            id: comunicacion.remitenteUserId,
            nombre: 'Usuario',
          );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ConversacionScreen(service: widget.service, usuario: usuario),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ComunicacionDetalleScreen(
            service: widget.service,
            comunicacionId: comunicacion.id,
          ),
        ),
      );
    }

    if (mounted) {
      await _cargar(silencioso: true);
    }
  }

  Future<void> _abrirEnviada(Comunicacion comunicacion) async {
    if (comunicacion.esMensaje && comunicacion.destinatarioUserId != null) {
      final usuario =
          comunicacion.destinatario ??
          ComunicacionUsuario(
            id: comunicacion.destinatarioUserId!,
            nombre: 'Usuario',
          );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ConversacionScreen(service: widget.service, usuario: usuario),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ComunicacionDetalleScreen(
            service: widget.service,
            comunicacionId: comunicacion.id,
          ),
        ),
      );
    }

    if (mounted) {
      await _cargar(silencioso: true);
    }
  }

  Future<void> _nuevaComunicacion() async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComunicacionCreateScreen(service: widget.service),
      ),
    );

    if (resultado != null && mounted) {
      await _cargar(silencioso: true);
    }
  }

  bool get _puedeCrearComunicacion {
    return _capacidades['mensaje'] == true ||
        _capacidades['aviso'] == true ||
        _capacidades['orden'] == true;
  }

  int get _pendientesEnterado {
    return _recibidas.where((registro) {
      final comunicacion = registro.comunicacion;

      return comunicacion != null &&
          comunicacion.requiereEnterado &&
          !registro.estaEnterado;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunicaciones'),
          actions: [
            if (_puedeCrearComunicacion)
              IconButton(
                tooltip: 'Nueva comunicación',
                onPressed: _nuevaComunicacion,
                icon: const Icon(Icons.add_circle_outline),
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando ? null : () => _cargar(),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Recibidas'),
                    if (_noLeidas > 0) ...[
                      const SizedBox(width: 7),
                      _BadgeNumero(numero: _noLeidas, color: Colors.red),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enviadas'),
                    if (_totalEnviadas > 0) ...[
                      const SizedBox(width: 7),
                      Text(
                        _totalEnviadas > 999
                            ? '999+'
                            : _totalEnviadas.toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _construirBody(),
        floatingActionButton: _puedeCrearComunicacion
            ? FloatingActionButton.extended(
                onPressed: _nuevaComunicacion,
                icon: const Icon(Icons.add),
                label: const Text('Nueva comunicación'),
              )
            : null,
      ),
    );
  }

  Widget _construirBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(mensaje: _error!, onRetry: _cargar);
    }

    return TabBarView(children: [_listaRecibidas(), _listaEnviadas()]);
  }

  Widget _listaRecibidas() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          _ResumenPrincipal(
            totalRecibidas: _totalRecibidas,
            noLeidas: _noLeidas,
            pendientesEnterado: _pendientesEnterado,
          ),
          const SizedBox(height: 14),
          if (_recibidas.isEmpty)
            const _EstadoVacio(
              icon: Icons.inbox_outlined,
              titulo: 'Sin comunicaciones',
              descripcion: 'No tienes comunicaciones recibidas.',
            )
          else
            ..._recibidas.map((registro) {
              final comunicacion = registro.comunicacion;

              if (comunicacion == null) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TarjetaRecibida(
                  registro: registro,
                  onTap: () => _abrirRecibida(registro),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _listaEnviadas() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          _ResumenEnviadas(total: _totalEnviadas),
          const SizedBox(height: 14),
          if (_enviadas.isEmpty)
            const _EstadoVacio(
              icon: Icons.send_outlined,
              titulo: 'Sin comunicaciones enviadas',
              descripcion: 'Todavía no has enviado comunicaciones.',
            )
          else
            ..._enviadas.map(
              (comunicacion) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TarjetaEnviada(
                  comunicacion: comunicacion,
                  onTap: () => _abrirEnviada(comunicacion),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResumenPrincipal extends StatelessWidget {
  final int totalRecibidas;
  final int noLeidas;
  final int pendientesEnterado;

  const _ResumenPrincipal({
    required this.totalRecibidas,
    required this.noLeidas,
    required this.pendientesEnterado,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _ResumenDato(
                icon: Icons.mail_outline,
                numero: totalRecibidas,
                texto: 'Recibidas',
              ),
            ),
            Container(
              width: 1,
              height: 46,
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _ResumenDato(
                icon: Icons.mark_email_unread_outlined,
                numero: noLeidas,
                texto: 'Sin leer',
                color: noLeidas > 0 ? Colors.red : null,
              ),
            ),
            Container(
              width: 1,
              height: 46,
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _ResumenDato(
                icon: Icons.done_all,
                numero: pendientesEnterado,
                texto: 'Por enterar',
                color: pendientesEnterado > 0 ? Colors.orange : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenEnviadas extends StatelessWidget {
  final int total;

  const _ResumenEnviadas({required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comunicaciones enviadas',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total comunicaciones registradas',
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
}

class _ResumenDato extends StatelessWidget {
  final IconData icon;
  final int numero;
  final String texto;
  final Color? color;

  const _ResumenDato({
    required this.icon,
    required this.numero,
    required this.texto,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final actual = color ?? Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Icon(icon, size: 20, color: actual),
        const SizedBox(height: 4),
        Text(
          numero > 999 ? '999+' : numero.toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: actual,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TarjetaRecibida extends StatelessWidget {
  final ComunicacionDestinatario registro;

  final VoidCallback onTap;

  const _TarjetaRecibida({required this.registro, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final comunicacion = registro.comunicacion!;

    final noLeida = !registro.estaLeido;

    final remitente = comunicacion.remitente?.nombreVisible ?? 'Usuario';

    final titulo = comunicacion.esMensaje ? remitente : comunicacion.titulo;

    final descripcion = comunicacion.tieneTexto
        ? comunicacion.contenido!.trim()
        : comunicacion.tieneImagenes
        ? 'Imagen adjunta'
        : 'Comunicación';

    final color = _colorTipo(comunicacion.tipo, context);

    return Material(
      color: noLeida ? color.withOpacity(.08) : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: noLeida
                  ? color.withOpacity(.35)
                  : Theme.of(context).dividerColor.withOpacity(.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TipoAvatar(comunicacion: comunicacion),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: noLeida
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              _TipoChip(tipo: comunicacion.tipo),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fechaCorta(comunicacion.enviadoAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (!comunicacion.esMensaje) ...[
                      const SizedBox(height: 4),
                      Text(
                        remitente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: noLeida
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(.75),
                      ),
                    ),
                    if (comunicacion.tieneImagenes) ...[
                      const SizedBox(height: 8),
                      const _MiniEstado(
                        icon: Icons.photo_outlined,
                        texto: 'Contiene imágenes',
                      ),
                    ],
                    if (comunicacion.requiereEnterado) ...[
                      const SizedBox(height: 9),
                      _EstadoEnterado(registro: registro),
                    ],
                  ],
                ),
              ),
              if (noLeida) ...[
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaEnviada extends StatelessWidget {
  final Comunicacion comunicacion;
  final VoidCallback onTap;

  const _TarjetaEnviada({required this.comunicacion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final destino = _textoDestino(comunicacion);

    final descripcion = comunicacion.tieneTexto
        ? comunicacion.contenido!.trim()
        : comunicacion.tieneImagenes
        ? 'Imagen adjunta'
        : 'Comunicación';

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TipoAvatar(comunicacion: comunicacion),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  comunicacion.esMensaje
                                      ? destino
                                      : comunicacion.titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              _TipoChip(tipo: comunicacion.tipo),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fechaCorta(comunicacion.enviadoAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (!comunicacion.esMensaje) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.groups_outlined, size: 14),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              destino,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (comunicacion.destinatariosCount != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _MiniEstado(
                            icon: Icons.people_outline,
                            texto:
                                '${comunicacion.destinatariosCount ?? 0} destinatarios',
                          ),
                          _MiniEstado(
                            icon: Icons.visibility_outlined,
                            texto: '${comunicacion.leidosCount ?? 0} leídos',
                          ),
                          if (comunicacion.requiereEnterado)
                            _MiniEstado(
                              icon: Icons.done_all,
                              texto:
                                  '${comunicacion.enteradosCount ?? 0} enterados',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipoChip extends StatelessWidget {
  final String tipo;

  const _TipoChip({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final color = _colorTipo(tipo, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _nombreTipo(tipo),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TipoAvatar extends StatelessWidget {
  final Comunicacion comunicacion;

  const _TipoAvatar({required this.comunicacion});

  @override
  Widget build(BuildContext context) {
    final color = _colorTipo(comunicacion.tipo, context);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        shape: BoxShape.circle,
      ),
      child: Icon(_iconoTipo(comunicacion.tipo), color: color, size: 22),
    );
  }
}

class _EstadoEnterado extends StatelessWidget {
  final ComunicacionDestinatario registro;

  const _EstadoEnterado({required this.registro});

  @override
  Widget build(BuildContext context) {
    if (registro.estaEnterado) {
      return const _MiniEstado(
        icon: Icons.done_all,
        texto: 'Enterado',
        color: Colors.green,
      );
    }

    if (registro.estaLeido) {
      return const _MiniEstado(
        icon: Icons.visibility_outlined,
        texto: 'Pendiente de enterado',
        color: Colors.orange,
      );
    }

    return const _MiniEstado(
      icon: Icons.schedule_outlined,
      texto: 'Pendiente',
      color: Colors.red,
    );
  }
}

class _MiniEstado extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color? color;

  const _MiniEstado({required this.icon, required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    final actual = color ?? Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: actual),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            color: actual,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BadgeNumero extends StatelessWidget {
  final int numero;
  final Color color;

  const _BadgeNumero({required this.numero, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        numero > 99 ? '99+' : numero.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;

  const _EstadoVacio({
    required this.icon,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              icon,
              size: 58,
              color: Theme.of(context).colorScheme.primary.withOpacity(.5),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(.65),
              ),
            ),
          ],
        ),
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
            const Icon(Icons.cloud_off_outlined, size: 55, color: Colors.red),
            const SizedBox(height: 16),
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

Color _colorTipo(String tipo, BuildContext context) {
  switch (tipo.toLowerCase()) {
    case 'orden':
      return Colors.red;

    case 'aviso':
      return Colors.orange;

    case 'mensaje':
      return Theme.of(context).colorScheme.primary;

    default:
      return Theme.of(context).colorScheme.secondary;
  }
}

String _nombreTipo(String tipo) {
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
      return 'Subdirectores';

    case 'rol':
      return comunicacion.rol?.nombre ?? 'Rol';

    case 'usuario':
      return comunicacion.destinatario?.nombreVisible ?? 'Usuario';

    default:
      return 'Destinatarios';
  }
}

String _fechaCorta(DateTime? fecha) {
  if (fecha == null) {
    return '';
  }

  final local = fecha.toLocal();

  final ahora = DateTime.now();

  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  final dia = DateTime(local.year, local.month, local.day);

  final hora = local.hour.toString().padLeft(2, '0');

  final minuto = local.minute.toString().padLeft(2, '0');

  if (dia == hoy) {
    return '$hora:$minuto';
  }

  final ayer = hoy.subtract(const Duration(days: 1));

  if (dia == ayer) {
    return 'Ayer';
  }

  final d = local.day.toString().padLeft(2, '0');

  final m = local.month.toString().padLeft(2, '0');

  return '$d/$m';
}
