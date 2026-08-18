import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/comunicacion_usuario.dart';
import '../../services/comunicacion_service.dart';

class ComunicacionCreateScreen extends StatefulWidget {
  final ComunicacionService service;

  const ComunicacionCreateScreen({super.key, required this.service});

  @override
  State<ComunicacionCreateScreen> createState() =>
      _ComunicacionCreateScreenState();
}

class _ComunicacionCreateScreenState extends State<ComunicacionCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _asuntoController = TextEditingController();

  final TextEditingController _contenidoController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  ComunicacionCatalogos? _catalogos;

  String? _tipo;
  String? _alcance;

  int? _unidadId;
  int? _turnoId;
  int? _roleId;

  ComunicacionUsuario? _usuarioSeleccionado;

  bool _requiereEnterado = false;
  bool _cargando = true;
  bool _enviando = false;

  String? _error;

  final List<XFile> _imagenes = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  @override
  void dispose() {
    _asuntoController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final catalogos = await widget.service.obtenerCatalogos();

      String? tipo;

      if (catalogos.permite('mensaje')) {
        tipo = 'mensaje';
      } else if (catalogos.permite('aviso')) {
        tipo = 'aviso';
      } else if (catalogos.permite('orden')) {
        tipo = 'orden';
      }

      String? alcance;

      if (tipo == 'mensaje') {
        alcance = 'usuario';
      } else {
        alcance = _primerAlcanceDisponible(catalogos);
      }

      int? unidadId;

      if (catalogos.unidades.length == 1) {
        unidadId = catalogos.unidades.first.id;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogos = catalogos;
        _tipo = tipo;
        _alcance = alcance;
        _unidadId = unidadId;
        _requiereEnterado = tipo == 'orden';
        _cargando = false;
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
        _error = 'No fue posible cargar la configuración de comunicaciones.';
      });
    }
  }

  String? _primerAlcanceDisponible(ComunicacionCatalogos catalogos) {
    const alcances = [
      'todos',
      'unidad',
      'unidad_turno',
      'subdirectores',
      'rol',
      'usuario',
    ];

    for (final alcance in alcances) {
      if (catalogos.permite(alcance)) {
        return alcance;
      }
    }

    return null;
  }

  void _cambiarTipo(String tipo) {
    final catalogos = _catalogos;

    if (catalogos == null) {
      return;
    }

    setState(() {
      _tipo = tipo;

      if (tipo == 'mensaje') {
        _alcance = 'usuario';
        _requiereEnterado = false;
        _asuntoController.clear();
      } else {
        if (_alcance == null ||
            _alcance == 'usuario' ||
            !catalogos.permite(_alcance!)) {
          _alcance = _primerAlcanceDisponible(catalogos);
        }

        if (tipo == 'orden') {
          _requiereEnterado = true;
        } else {
          _requiereEnterado = false;
        }
      }

      _limpiarDestinoNoUsado();
    });
  }

  void _cambiarAlcance(String alcance) {
    setState(() {
      _alcance = alcance;
      _limpiarDestinoNoUsado();
    });
  }

  void _limpiarDestinoNoUsado() {
    switch (_alcance) {
      case 'todos':
      case 'subdirectores':
        _turnoId = null;
        _roleId = null;
        _usuarioSeleccionado = null;
        break;

      case 'unidad':
        _turnoId = null;
        _roleId = null;
        _usuarioSeleccionado = null;
        break;

      case 'unidad_turno':
        _roleId = null;
        _usuarioSeleccionado = null;
        break;

      case 'rol':
        _turnoId = null;
        _usuarioSeleccionado = null;
        break;

      case 'usuario':
        _unidadId = null;
        _turnoId = null;
        _roleId = null;
        break;
    }
  }

  Future<void> _seleccionarUsuario() async {
    final usuario = await showModalBottomSheet<ComunicacionUsuario>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _SelectorUsuarioSheet(service: widget.service),
    );

    if (usuario == null || !mounted) {
      return;
    }

    setState(() {
      _usuarioSeleccionado = usuario;
    });
  }

  Future<void> _seleccionarImagenes() async {
    if (_imagenes.length >= 10) {
      _mostrarError('Ya alcanzaste el máximo de 10 imágenes.');
      return;
    }

    try {
      final seleccionadas = await _imagePicker.pickMultiImage(imageQuality: 90);

      if (seleccionadas.isEmpty) {
        return;
      }

      await _agregarImagenes(seleccionadas);
    } catch (_) {
      _mostrarError('No fue posible abrir la galería.');
    }
  }

  Future<void> _tomarFoto() async {
    if (_imagenes.length >= 10) {
      _mostrarError('Ya alcanzaste el máximo de 10 imágenes.');
      return;
    }

    try {
      final imagen = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (imagen == null) {
        return;
      }

      await _agregarImagenes([imagen]);
    } catch (_) {
      _mostrarError('No fue posible abrir la cámara.');
    }
  }

  Future<void> _agregarImagenes(List<XFile> nuevas) async {
    if (_imagenes.length + nuevas.length > 10) {
      _mostrarError('Puedes adjuntar un máximo de 10 imágenes.');
      return;
    }

    for (final archivo in nuevas) {
      try {
        final bytes = await archivo.length();

        if (bytes > 10 * 1024 * 1024) {
          _mostrarError('${archivo.name} supera los 10 MB.');
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
      _imagenes.addAll(nuevas);
    });
  }

  Future<void> _mostrarSelectorAdjunto() async {
    final opcion = await showModalBottomSheet<_OrigenImagen>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galería'),
                subtitle: const Text('Seleccionar una o varias imágenes'),
                onTap: () {
                  Navigator.of(context).pop(_OrigenImagen.galeria);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Cámara'),
                subtitle: const Text('Tomar una fotografía'),
                onTap: () {
                  Navigator.of(context).pop(_OrigenImagen.camara);
                },
              ),
            ],
          ),
        );
      },
    );

    if (opcion == _OrigenImagen.galeria) {
      await _seleccionarImagenes();
    }

    if (opcion == _OrigenImagen.camara) {
      await _tomarFoto();
    }
  }

  void _quitarImagen(int index) {
    setState(() {
      _imagenes.removeAt(index);
    });
  }

  bool _validarDestino() {
    switch (_alcance) {
      case 'unidad':
        if (_unidadId == null) {
          _mostrarError('Selecciona una unidad.');
          return false;
        }
        break;

      case 'unidad_turno':
        if (_unidadId == null) {
          _mostrarError('Selecciona una unidad.');
          return false;
        }

        if (_turnoId == null) {
          _mostrarError('Selecciona un turno.');
          return false;
        }
        break;

      case 'rol':
        if (_roleId == null) {
          _mostrarError('Selecciona un rol.');
          return false;
        }
        break;

      case 'usuario':
        if (_usuarioSeleccionado == null) {
          _mostrarError('Selecciona un usuario.');
          return false;
        }
        break;
    }

    return true;
  }

  Future<void> _enviar() async {
    if (_enviando) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tipo == null || _alcance == null) {
      _mostrarError('Selecciona el tipo y alcance de la comunicación.');
      return;
    }

    if (!_validarDestino()) {
      return;
    }

    final contenido = _contenidoController.text.trim();

    if (_tipo == 'mensaje' && contenido.isEmpty && _imagenes.isEmpty) {
      _mostrarError('Escribe un mensaje o adjunta al menos una imagen.');
      return;
    }

    setState(() {
      _enviando = true;
    });

    try {
      final comunicacion = await widget.service.enviarComunicacion(
        tipo: _tipo!,
        alcance: _alcance!,
        asunto: _tipo == 'mensaje' ? null : _asuntoController.text.trim(),
        contenido: contenido,
        unidadId: _unidadId,
        turnoId: _turnoId,
        roleId: _roleId,
        destinatarioUserId: _usuarioSeleccionado?.id,
        requiereEnterado: _tipo == 'orden' ? true : _requiereEnterado,
        imagenes: List<XFile>.from(_imagenes),
      );

      await SystemSound.play(SystemSoundType.click);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 45),
            title: const Text('Comunicación enviada'),
            content: Text(
              _tipo == 'mensaje'
                  ? 'El mensaje fue enviado correctamente.'
                  : '${_nombreTipo(_tipo!)} enviada correctamente.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(comunicacion);
    } on ComunicacionApiException catch (e) {
      _mostrarError(e.mensaje);
    } catch (_) {
      _mostrarError('No fue posible enviar la comunicación.');
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
      appBar: AppBar(title: const Text('Nueva comunicación')),
      body: _construirBody(),
    );
  }

  Widget _construirBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(mensaje: _error!, onRetry: _cargarCatalogos);
    }

    final catalogos = _catalogos;

    if (catalogos == null) {
      return const Center(child: Text('No fue posible cargar el módulo.'));
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
        children: [
          _seccionTipo(catalogos),
          const SizedBox(height: 14),
          _seccionDestino(catalogos),
          const SizedBox(height: 14),
          _seccionContenido(),
          const SizedBox(height: 14),
          _seccionAdjuntos(),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _enviando ? 'Enviando...' : 'Enviar comunicación',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionTipo(ComunicacionCatalogos catalogos) {
    final tipos = <_TipoOpcion>[];

    if (catalogos.permite('orden')) {
      tipos.add(
        const _TipoOpcion(
          id: 'orden',
          titulo: 'Orden',
          descripcion: 'Instrucción con confirmación obligatoria',
          icon: Icons.campaign_outlined,
          color: Colors.red,
        ),
      );
    }

    if (catalogos.permite('aviso')) {
      tipos.add(
        const _TipoOpcion(
          id: 'aviso',
          titulo: 'Aviso',
          descripcion: 'Información para uno o varios destinatarios',
          icon: Icons.notifications_active_outlined,
          color: Colors.orange,
        ),
      );
    }

    if (catalogos.permite('mensaje')) {
      tipos.add(
        const _TipoOpcion(
          id: 'mensaje',
          titulo: 'Mensaje',
          descripcion: 'Conversación directa con una persona',
          icon: Icons.chat_bubble_outline,
          color: Colors.blue,
        ),
      );
    }

    return _CardSeccion(
      titulo: 'Tipo de comunicación',
      icon: Icons.mark_email_unread_outlined,
      child: Column(
        children: tipos
            .map(
              (opcion) => _TipoSeleccionTile(
                opcion: opcion,
                seleccionado: _tipo == opcion.id,
                onTap: () => _cambiarTipo(opcion.id),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _seccionDestino(ComunicacionCatalogos catalogos) {
    final alcances = <_AlcanceOpcion>[];

    if (_tipo == 'mensaje') {
      alcances.add(
        const _AlcanceOpcion(
          id: 'usuario',
          nombre: 'Usuario específico',
          icon: Icons.person_outline,
        ),
      );
    } else {
      if (catalogos.permite('todos')) {
        alcances.add(
          const _AlcanceOpcion(
            id: 'todos',
            nombre: 'Todo el personal',
            icon: Icons.public_outlined,
          ),
        );
      }

      if (catalogos.permite('unidad')) {
        alcances.add(
          const _AlcanceOpcion(
            id: 'unidad',
            nombre: 'Unidad',
            icon: Icons.apartment_outlined,
          ),
        );
      }

      if (catalogos.permite('unidad_turno')) {
        alcances.add(
          const _AlcanceOpcion(
            id: 'unidad_turno',
            nombre: 'Unidad + turno',
            icon: Icons.schedule_outlined,
          ),
        );
      }

      if (catalogos.permite('subdirectores')) {
        alcances.add(
          const _AlcanceOpcion(
            id: 'subdirectores',
            nombre: 'Subdirectores',
            icon: Icons.supervisor_account_outlined,
          ),
        );
      }

      if (catalogos.permite('rol')) {
        alcances.add(
          const _AlcanceOpcion(
            id: 'rol',
            nombre: 'Rol',
            icon: Icons.badge_outlined,
          ),
        );
      }

      if (catalogos.permite('usuario')) {
        alcances.add(
          const _AlcanceOpcion(
            id: 'usuario',
            nombre: 'Usuario específico',
            icon: Icons.person_outline,
          ),
        );
      }
    }

    return _CardSeccion(
      titulo: 'Destinatarios',
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: alcances
                .map(
                  (opcion) => ChoiceChip(
                    avatar: Icon(opcion.icon, size: 18),
                    label: Text(opcion.nombre),
                    selected: _alcance == opcion.id,
                    onSelected: (_) {
                      _cambiarAlcance(opcion.id);
                    },
                  ),
                )
                .toList(),
          ),
          if (_alcance == 'unidad' ||
              _alcance == 'unidad_turno' ||
              _alcance == 'rol') ...[
            const SizedBox(height: 18),
          ],
          if (_alcance == 'unidad' ||
              _alcance == 'unidad_turno' ||
              _alcance == 'rol')
            _selectorUnidad(catalogos),
          if (_alcance == 'unidad_turno') ...[
            const SizedBox(height: 14),
            _selectorTurno(catalogos),
          ],
          if (_alcance == 'rol') ...[
            const SizedBox(height: 14),
            _selectorRol(catalogos),
          ],
          if (_alcance == 'usuario') ...[
            const SizedBox(height: 18),
            _selectorUsuario(),
          ],
        ],
      ),
    );
  }

  Widget _selectorUnidad(ComunicacionCatalogos catalogos) {
    return DropdownButtonFormField<int>(
      value: catalogos.unidades.any((item) => item.id == _unidadId)
          ? _unidadId
          : null,
      decoration: const InputDecoration(
        labelText: 'Unidad',
        prefixIcon: Icon(Icons.apartment_outlined),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: catalogos.unidades
          .map(
            (item) => DropdownMenuItem<int>(
              value: item.id,
              child: Text(item.nombre, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _unidadId = value;
        });
      },
    );
  }

  Widget _selectorTurno(ComunicacionCatalogos catalogos) {
    return DropdownButtonFormField<int>(
      value: catalogos.turnos.any((item) => item.id == _turnoId)
          ? _turnoId
          : null,
      decoration: const InputDecoration(
        labelText: 'Turno',
        prefixIcon: Icon(Icons.schedule_outlined),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: catalogos.turnos
          .map(
            (item) => DropdownMenuItem<int>(
              value: item.id,
              child: Text(item.nombre, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _turnoId = value;
        });
      },
    );
  }

  Widget _selectorRol(ComunicacionCatalogos catalogos) {
    return DropdownButtonFormField<int>(
      value: catalogos.roles.any((item) => item.id == _roleId) ? _roleId : null,
      decoration: const InputDecoration(
        labelText: 'Rol',
        prefixIcon: Icon(Icons.badge_outlined),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      items: catalogos.roles
          .map(
            (item) => DropdownMenuItem<int>(
              value: item.id,
              child: Text(item.nombre, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _roleId = value;
        });
      },
    );
  }

  Widget _selectorUsuario() {
    if (_usuarioSeleccionado == null) {
      return InkWell(
        onTap: _seleccionarUsuario,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_search_outlined),
              SizedBox(width: 12),
              Expanded(child: Text('Buscar y seleccionar usuario')),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Text(_usuarioSeleccionado!.iniciales)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _usuarioSeleccionado!.nombreVisible,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_usuarioSeleccionado!.detalle.isNotEmpty)
                  Text(
                    _usuarioSeleccionado!.detalle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cambiar usuario',
            onPressed: _seleccionarUsuario,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Quitar usuario',
            onPressed: () {
              setState(() {
                _usuarioSeleccionado = null;
              });
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _seccionContenido() {
    return _CardSeccion(
      titulo: 'Comunicación',
      icon: Icons.edit_note_outlined,
      child: Column(
        children: [
          if (_tipo != 'mensaje') ...[
            TextFormField(
              controller: _asuntoController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 180,
              decoration: const InputDecoration(
                labelText: 'Asunto',
                hintText: 'Escribe el asunto de la comunicación',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_tipo != 'mensaje' &&
                    (value == null || value.trim().isEmpty)) {
                  return 'El asunto es obligatorio.';
                }

                return null;
              },
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: _contenidoController,
            minLines: 6,
            maxLines: 12,
            maxLength: 10000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _tipo == 'mensaje' ? 'Mensaje' : 'Contenido',
              hintText: _tipo == 'mensaje'
                  ? 'Escribe un mensaje...'
                  : 'Escribe el contenido de la comunicación...',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (_tipo != 'mensaje' &&
                  (value == null || value.trim().isEmpty)) {
                return 'El contenido es obligatorio.';
              }

              return null;
            },
          ),
          if (_tipo == 'orden') ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.done_all, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Las órdenes requieren confirmación de enterado obligatoriamente.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tipo == 'aviso') ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requiere confirmación de enterado'),
              subtitle: const Text(
                'Los destinatarios deberán confirmar que recibieron y conocieron el aviso.',
              ),
              value: _requiereEnterado,
              onChanged: (value) {
                setState(() {
                  _requiereEnterado = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccionAdjuntos() {
    return _CardSeccion(
      titulo: 'Imágenes',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _imagenes.length >= 10 ? null : _mostrarSelectorAdjunto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _imagenes.isEmpty ? 'Adjuntar imágenes' : 'Agregar más imágenes',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_imagenes.length} de 10 imágenes',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_imagenes.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagenes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imagen = _imagenes[index];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(imagen.path),
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 92,
                              height: 92,
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
                            width: 25,
                            height: 25,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectorUsuarioSheet extends StatefulWidget {
  final ComunicacionService service;

  const _SelectorUsuarioSheet({required this.service});

  @override
  State<_SelectorUsuarioSheet> createState() => _SelectorUsuarioSheetState();
}

class _SelectorUsuarioSheetState extends State<_SelectorUsuarioSheet> {
  final TextEditingController _buscarController = TextEditingController();

  List<ComunicacionUsuario> _usuarios = [];

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuarios = await widget.service.obtenerDestinatarios(
        busqueda: _buscarController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _usuarios = usuarios;
        _cargando = false;
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
        _error = 'No fue posible cargar los usuarios.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .78,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seleccionar usuario',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _buscarController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: 'Nombre, apellido o correo...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _buscar,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _construirResultados()),
          ],
        ),
      ),
    );
  }

  Widget _construirResultados() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _buscar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_usuarios.isEmpty) {
      return const Center(child: Text('No se encontraron usuarios.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      itemCount: _usuarios.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final usuario = _usuarios[index];

        return ListTile(
          leading: CircleAvatar(child: Text(usuario.iniciales)),
          title: Text(usuario.nombreVisible),
          subtitle: usuario.detalle.isEmpty ? null : Text(usuario.detalle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).pop(usuario);
          },
        );
      },
    );
  }
}

class _CardSeccion extends StatelessWidget {
  final String titulo;
  final IconData icon;
  final Widget child;

  const _CardSeccion({
    required this.titulo,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TipoSeleccionTile extends StatelessWidget {
  final _TipoOpcion opcion;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TipoSeleccionTile({
    required this.opcion,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: seleccionado
            ? opcion.color.withOpacity(.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: seleccionado
                    ? opcion.color
                    : Theme.of(context).dividerColor,
                width: seleccionado ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: opcion.color.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(opcion.icon, color: opcion.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opcion.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opcion.descripcion,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (seleccionado) Icon(Icons.check_circle, color: opcion.color),
              ],
            ),
          ),
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

class _TipoOpcion {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icon;
  final Color color;

  const _TipoOpcion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icon,
    required this.color,
  });
}

class _AlcanceOpcion {
  final String id;
  final String nombre;
  final IconData icon;

  const _AlcanceOpcion({
    required this.id,
    required this.nombre,
    required this.icon,
  });
}

enum _OrigenImagen { galeria, camara }

String _nombreTipo(String tipo) {
  switch (tipo) {
    case 'orden':
      return 'Orden';

    case 'aviso':
      return 'Aviso';

    case 'mensaje':
      return 'Mensaje';

    default:
      return 'Comunicación';
  }
}
