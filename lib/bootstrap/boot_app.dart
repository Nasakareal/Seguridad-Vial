import 'package:flutter/material.dart';

import '../core/globals.dart';
import '../app/app.dart';
import 'bootstrap.dart';

class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  String step = 'Iniciando...';
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ok = await bootstrapApp(
      onStep: (s) {
        if (!mounted) return;
        setState(() => step = s);
      },
    );

    if (!mounted) return;
    setState(() => ready = ok);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: bootFatal,
      builder: (context, fatal, _) {
        if (fatal == null && ready) {
          return const SeguridadVialApp();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Seguridad Vial',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          fatal == null
                              ? step
                              : (ready
                                    ? 'Ocurrió un error dentro de la app.'
                                    : 'FALLÓ EN:\n$step'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (fatal == null)
                          const CircularProgressIndicator()
                        else
                          Text(
                            fatal,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
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
    );
  }
}
