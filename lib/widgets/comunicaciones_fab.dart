import 'dart:async';

import 'package:flutter/material.dart';

import '../../screens/comunicaciones/comunicaciones_screen.dart';
import '../../services/comunicacion_notification_service.dart';
import '../../services/comunicacion_service.dart';

class ComunicacionesFab extends StatefulWidget {
  final ComunicacionService service;
  final String? heroTag;
  final double size;

  const ComunicacionesFab({
    super.key,
    required this.service,
    this.heroTag = 'comunicaciones_fab',
    this.size = 58,
  });

  @override
  State<ComunicacionesFab> createState() => _ComunicacionesFabState();
}

class _ComunicacionesFabState extends State<ComunicacionesFab> {
  final ComunicacionNotificationService _notificationService =
      ComunicacionNotificationService.instance;

  StreamSubscription<ComunicacionPushEvento>? _pushSubscription;

  int _noLeidas = 0;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();

    _actualizarContador();

    _pushSubscription = _notificationService.eventos.listen((evento) {
      if (evento.accion == ComunicacionPushAccion.recibida) {
        _actualizarContador();
      }
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _actualizarContador() async {
    if (_cargando) {
      return;
    }

    _cargando = true;

    try {
      final resultado = await widget.service.obtenerNoLeidas();

      if (!mounted) {
        return;
      }

      setState(() {
        _noLeidas = resultado.count;
      });
    } catch (_) {
    } finally {
      _cargando = false;
    }
  }

  Future<void> _abrirComunicaciones() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComunicacionesScreen(service: widget.service),
      ),
    );

    if (mounted) {
      await _actualizarContador();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 8,
      height: widget.size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: FloatingActionButton(
                heroTag: widget.heroTag,
                onPressed: _abrirComunicaciones,
                tooltip: 'Mensajes',
                shape: const CircleBorder(),
                child: const Icon(Icons.chat_bubble),
              ),
            ),
          ),
          if (_noLeidas > 0)
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 23,
                    minHeight: 23,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _noLeidas > 99 ? '99+' : _noLeidas.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
