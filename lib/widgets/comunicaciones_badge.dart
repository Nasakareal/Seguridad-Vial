import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/comunicacion_notification_service.dart';
import '../../services/comunicacion_service.dart';

class ComunicacionesBadge extends StatefulWidget {
  final ComunicacionService service;
  final Widget child;
  final VoidCallback? onTap;
  final bool mostrarCero;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color textColor;
  final double minSize;

  const ComunicacionesBadge({
    super.key,
    required this.service,
    required this.child,
    this.onTap,
    this.mostrarCero = false,
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.color = Colors.red,
    this.textColor = Colors.white,
    this.minSize = 20,
  });

  @override
  State<ComunicacionesBadge> createState() => _ComunicacionesBadgeState();
}

class _ComunicacionesBadgeState extends State<ComunicacionesBadge> {
  final ComunicacionNotificationService _notificationService =
      ComunicacionNotificationService.instance;

  StreamSubscription<ComunicacionPushEvento>? _pushSubscription;

  int _noLeidas = 0;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();

    _actualizar();

    _pushSubscription = _notificationService.eventos.listen((evento) {
      if (evento.accion == ComunicacionPushAccion.recibida) {
        _actualizar();
      }
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _actualizar() async {
    if (_consultando) {
      return;
    }

    _consultando = true;

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
      _consultando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mostrar = widget.mostrarCero || _noLeidas > 0;

    Widget contenido = Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (mostrar)
          Positioned.fill(
            child: Align(
              alignment: widget.alignment,
              child: Transform.translate(
                offset: const Offset(7, -7),
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: widget.minSize,
                    minHeight: widget.minSize,
                  ),
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _noLeidas > 99 ? '99+' : _noLeidas.toString(),
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.onTap != null) {
      contenido = InkWell(
        onTap: () async {
          widget.onTap!();

          await Future.delayed(const Duration(milliseconds: 300));

          if (mounted) {
            await _actualizar();
          }
        },
        borderRadius: BorderRadius.circular(50),
        child: contenido,
      );
    }

    return contenido;
  }
}
