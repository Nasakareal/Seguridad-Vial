import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tracking_service.dart';
import '../widgets/location_disclosure_dialog.dart';

class LocationConsentScreen extends StatefulWidget {
  final Widget next;

  const LocationConsentScreen({super.key, required this.next});

  @override
  State<LocationConsentScreen> createState() => _LocationConsentScreenState();
}

class _LocationConsentScreenState extends State<LocationConsentScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _deny() async {
    if (_busy) return;

    if (Platform.isAndroid) {
      await SystemNavigator.pop();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _accept() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await LocationDisclosure.show(context);
      if (!ok) {
        await _deny();
        return;
      }

      if (!mounted) return;
      final started = await TrackingService.startAfterConsent(context);
      if (!started) {
        setState(() {
          _error =
              'No se pudo activar la ubicación obligatoria. Revisa permisos, ubicación precisa y segundo plano en Ajustes.';
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => widget.next),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al activar la ubicación.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Permiso de ubicación'),
          backgroundColor: Colors.blue,
          elevation: 0,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const outerPadding = 16.0;
              final minHeight = constraints.maxHeight > outerPadding * 2
                  ? constraints.maxHeight - outerPadding * 2
                  : 0.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(outerPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Para ver patrullas en tiempo real',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'La app necesita enviar tu ubicación incluso en segundo plano para mostrar patrullas activas y coordinar el servicio. Para continuar deberá quedar activo “Permitir siempre” y, en iPhone, “Ubicación precisa”.',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.blue.withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  'Se solicitará “Permitir siempre” y, en Android, ejecución sin restricciones de batería.',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.red.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, actionConstraints) {
                                  final stackActions =
                                      actionConstraints.maxWidth < 360 ||
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1) >
                                          1.25;

                                  final denyButton = OutlinedButton(
                                    onPressed: _busy ? null : _deny,
                                    child: const Text('No acepto'),
                                  );
                                  final acceptButton = ElevatedButton(
                                    onPressed: _busy ? null : _accept,
                                    child: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Aceptar y continuar',
                                            textAlign: TextAlign.center,
                                          ),
                                  );

                                  if (stackActions) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        acceptButton,
                                        const SizedBox(height: 10),
                                        denyButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: denyButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: acceptButton),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
