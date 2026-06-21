import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/routes.dart';
import '../../core/licencias/licencia_barcode_payload.dart';
import '../../core/licencias/licencia_qr_parser.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/licencia_puntos_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';

class LicenciasPuntosScreen extends StatefulWidget {
  const LicenciasPuntosScreen({super.key});

  @override
  State<LicenciasPuntosScreen> createState() => _LicenciasPuntosScreenState();
}

class _LicenciasPuntosScreenState extends State<LicenciasPuntosScreen> {
  final _biometricAuth = BiometricAuthService();
  final _numeroCtrl = TextEditingController();
  final _titularCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _capacitacionReferenciaCtrl = TextEditingController();
  final _capacitacionDescripcionCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _shiftChecking = true;
  bool _shiftAllowed = false;
  bool _biometricChecking = true;
  bool _biometricVerified = false;
  bool _initializedArgs = false;
  bool _pendingInitialSearch = false;
  String? _error;
  String? _shiftError;
  String? _biometricError;
  LicenciaPuntosMeta? _meta;
  LicenciaPuntoCuenta? _cuenta;
  LicenciaQrData? _lastScan;
  int? _infraccionId;
  int? _hechoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepareModuleAccess());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedArgs) return;
    _initializedArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _numeroCtrl.text = (args['numero_licencia'] ?? '').toString().trim();
      _titularCtrl.text = (args['titular_nombre'] ?? '').toString().trim();
      _tipoCtrl.text =
          LicenciaTipoCatalog.normalize(
            (args['tipo_licencia'] ?? '').toString(),
          ) ??
          '';
      _telefonoCtrl.text = _telefonoMx10((args['telefono'] ?? '').toString());
      _hechoId = int.tryParse((args['hecho_id'] ?? '').toString());
      if (_numeroCtrl.text.trim().isNotEmpty) {
        _pendingInitialSearch = true;
      }
    }
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _titularCtrl.dispose();
    _tipoCtrl.dispose();
    _telefonoCtrl.dispose();
    _referenciaCtrl.dispose();
    _descripcionCtrl.dispose();
    _capacitacionReferenciaCtrl.dispose();
    _capacitacionDescripcionCtrl.dispose();
    _puntosCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meta = await LicenciaPuntosService.meta();
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _infraccionId = meta.infracciones.isNotEmpty
            ? meta.infracciones.first.id
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = LicenciaPuntosService.cleanExceptionMessage(e);
      });
    }
  }

  Future<void> _prepareModuleAccess() async {
    setState(() {
      _shiftChecking = true;
      _shiftAllowed = false;
      _shiftError = null;
      _loading = false;
      _error = null;
    });

    final access = await AuthService.licensePointsSiniestrosShiftAccess();
    if (!mounted) return;

    if (!access.allowed) {
      setState(() {
        _shiftChecking = false;
        _shiftAllowed = false;
        _shiftError = access.message;
      });
      return;
    }

    setState(() {
      _shiftChecking = false;
      _shiftAllowed = true;
    });
    await _unlockModuleWithBiometrics();
  }

  Future<void> _unlockModuleWithBiometrics() async {
    setState(() {
      _biometricChecking = true;
      _biometricError = null;
      _loading = false;
      _error = null;
    });

    final result = await _biometricAuth.verify(
      localizedReason:
          'Verifica tu identidad con huella o rostro para entrar a Puntos de licencia.',
    );
    if (!mounted) return;

    if (!result.allowed) {
      setState(() {
        _biometricChecking = false;
        _biometricVerified = false;
        _biometricError = result.message;
      });
      return;
    }

    setState(() {
      _biometricChecking = false;
      _biometricVerified = true;
      _loading = true;
    });

    await _loadMeta();
    if (!mounted) return;

    if (_pendingInitialSearch && _numeroCtrl.text.trim().isNotEmpty) {
      _pendingInitialSearch = false;
      await _buscar();
    }
  }

  Future<bool> _verifyBiometricForAction(String localizedReason) async {
    final result = await _biometricAuth.verify(
      localizedReason: localizedReason,
    );
    if (result.allowed) return true;
    if (mounted) _showSnack(result.message);
    return false;
  }

  Future<bool> _ensureSiniestrosWorkingTurn() async {
    final access = await AuthService.licensePointsSiniestrosShiftAccess();
    if (access.allowed) return true;

    if (mounted) _showSnack(access.message);
    return false;
  }

  Future<bool> _ensureSecurePasswordForDiscount() async {
    if (await AuthService.canDiscountLicensePointsByPasswordGate()) {
      return true;
    }
    if (!mounted) return false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Actualiza tu contraseña'),
          content: const Text(
            'Para quitar puntos a licencias, todo usuario de Siniestros debe cambiar primero su contraseña por una segura. El rol Subdirector está exceptuado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Después'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(
                  dialogContext,
                ).pushNamed(AppRoutes.changePassword);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, result == true);
              },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Cambiar contraseña'),
            ),
          ],
        );
      },
    );

    if (changed == true &&
        await AuthService.canDiscountLicensePointsByPasswordGate()) {
      return true;
    }

    if (mounted) {
      _showSnack(
        'Debes cambiar tu contraseña por una segura antes de quitar puntos.',
      );
    }
    return false;
  }

  Future<void> _buscar() async {
    final numero = _numeroCtrl.text.trim();
    if (numero.isEmpty) {
      _showSnack('Escanea o captura el número de licencia.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cuenta = await LicenciaPuntosService.buscarPorNumero(numero);
      if (!mounted) return;
      setState(() {
        _cuenta = cuenta;
        if (_titularCtrl.text.trim().isEmpty) {
          _titularCtrl.text = cuenta.titularNombre;
        }
        if (_tipoCtrl.text.trim().isEmpty) {
          _tipoCtrl.text =
              LicenciaTipoCatalog.normalize(cuenta.tipoLicencia) ?? '';
        }
        if (_telefonoCtrl.text.trim().isEmpty) {
          _telefonoCtrl.text = _telefonoMx10(cuenta.telefono);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = LicenciaPuntosService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanLicencia() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _LicenciaPuntosScannerScreen()),
    );
    final text = raw?.trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final parsed = LicenciaPuntosService.parseLicencia(text);
    if ((parsed.numeroLicencia ?? '').trim().isEmpty) {
      _showSnack('No pude leer el número de licencia. Intenta de nuevo.');
      return;
    }

    setState(() {
      _lastScan = parsed;
      _numeroCtrl.text = parsed.numeroLicencia ?? '';
      if ((parsed.nombre ?? '').trim().isNotEmpty) {
        _titularCtrl.text = parsed.nombre!;
      }
      final tipoLicencia = LicenciaTipoCatalog.normalize(parsed.tipoLicencia);
      if ((tipoLicencia ?? '').trim().isNotEmpty) {
        _tipoCtrl.text = tipoLicencia!;
      }
    });

    await _buscar();
  }

  Future<void> _aplicarDescuento() async {
    final infraccionId = _infraccionId;
    if (infraccionId == null || infraccionId <= 0) {
      _showSnack('Selecciona una penalización.');
      return;
    }
    if (_numeroCtrl.text.trim().isEmpty) {
      _showSnack('Falta el número de licencia.');
      return;
    }
    final telefono = _telefonoMx10(_telefonoCtrl.text);
    final telefonoError = _telefonoError(telefono);
    if (telefonoError != null) {
      _showSnack(telefonoError);
      return;
    }

    final shiftAllowed = await _ensureSiniestrosWorkingTurn();
    if (!shiftAllowed) return;

    final passwordAllowed = await _ensureSecurePasswordForDiscount();
    if (!passwordAllowed) return;

    setState(() => _busy = true);
    try {
      final authorized = await _verifyBiometricForAction(
        'Verifica con huella o rostro antes de restar puntos de la licencia.',
      );
      if (!authorized) return;

      final updated = await LicenciaPuntosService.registrarInfraccion(
        cuentaId: _cuenta?.id,
        numeroLicencia: _numeroCtrl.text,
        titularNombre: _titularCtrl.text,
        tipoLicencia: _tipoCtrl.text,
        telefono: telefono,
        infraccionId: infraccionId,
        hechoId: _hechoId,
        referencia: _referenciaCtrl.text,
        descripcion: _descripcionCtrl.text,
      );
      if (!mounted) return;
      setState(() => _cuenta = updated);
      _showSnack('Penalización aplicada correctamente.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(LicenciaPuntosService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acreditarCapacitacion() async {
    final cuenta = _cuenta;
    final cuentaId = cuenta?.id;
    if (cuentaId == null || cuentaId <= 0) {
      _showSnack('Primero busca una licencia registrada.');
      return;
    }
    final saldoMaximo = _meta?.saldoMaximo ?? 12;
    final maxPuntos = (saldoMaximo - cuenta!.saldoActual)
        .clamp(0, saldoMaximo)
        .toInt();
    if (maxPuntos <= 0) {
      _showSnack('La licencia ya tiene el tope de $saldoMaximo puntos.');
      return;
    }
    final puntos = int.tryParse(_puntosCtrl.text.trim()) ?? 0;
    if (puntos < 1 || puntos > maxPuntos) {
      _showSnack('Los puntos deben estar entre 1 y $maxPuntos.');
      return;
    }

    final shiftAllowed = await _ensureSiniestrosWorkingTurn();
    if (!shiftAllowed) return;

    setState(() => _busy = true);
    try {
      final authorized = await _verifyBiometricForAction(
        'Verifica con huella o rostro antes de acreditar puntos a la licencia.',
      );
      if (!authorized) return;

      final updated = await LicenciaPuntosService.acreditarCapacitacion(
        cuentaId: cuentaId,
        puntos: puntos,
        referencia: _capacitacionReferenciaCtrl.text,
        descripcion: _capacitacionDescripcionCtrl.text,
      );
      if (!mounted) return;
      setState(() => _cuenta = updated);
      _showSnack('Puntos acreditados correctamente.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(LicenciaPuntosService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final abilities = meta?.abilities;
    final writesLocked = abilities?.moduleWritesLocked ?? true;
    final cuenta = _cuenta;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Puntos de licencia'),
        actions: const [AccountMenuAction()],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: !_shiftAllowed
            ? _ShiftGateView(
                checking: _shiftChecking,
                message: _shiftError,
                onRetry: _shiftChecking
                    ? null
                    : () => unawaited(_prepareModuleAccess()),
                onExit: () => Navigator.maybePop(context),
              )
            : !_biometricVerified
            ? _BiometricGateView(
                checking: _biometricChecking,
                message: _biometricError,
                onRetry: _biometricChecking
                    ? null
                    : () => unawaited(_prepareModuleAccess()),
                onExit: () => Navigator.maybePop(context),
              )
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadMeta,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _HeroCard(onScan: _busy ? null : _scanLicencia),
                    const SizedBox(height: 14),
                    if (writesLocked)
                      const _NoticeCard(
                        title: 'Herramienta en desarrollo',
                        text:
                            'Puedes consultar licencias, pero los movimientos están bloqueados. De momento solo Superadmin puede sumar o restar puntos.',
                        icon: Icons.lock_clock,
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorCard(message: _error!, onRetry: _loadMeta),
                    ],
                    const SizedBox(height: 14),
                    _LookupCard(
                      busy: _busy,
                      numeroCtrl: _numeroCtrl,
                      titularCtrl: _titularCtrl,
                      tipoCtrl: _tipoCtrl,
                      tiposLicencia:
                          meta?.tiposLicencia ?? LicenciaTipoCatalog.options,
                      telefonoCtrl: _telefonoCtrl,
                      onSearch: _buscar,
                      onScan: _scanLicencia,
                    ),
                    if (_lastScan != null) ...[
                      const SizedBox(height: 12),
                      _ScanSummaryCard(data: _lastScan!),
                    ],
                    const SizedBox(height: 14),
                    _CuentaCard(cuenta: cuenta),
                    if (meta != null &&
                        (abilities?.canRestarPuntos ?? false)) ...[
                      const SizedBox(height: 14),
                      _DiscountActionCard(
                        busy: _busy,
                        meta: meta,
                        infraccionId: _infraccionId,
                        referenciaCtrl: _referenciaCtrl,
                        descripcionCtrl: _descripcionCtrl,
                        onInfraccionChanged: (value) {
                          setState(() => _infraccionId = value);
                        },
                        onRestar: _aplicarDescuento,
                      ),
                    ],
                    if (meta != null &&
                        (abilities?.canSumarPuntos ?? false)) ...[
                      const SizedBox(height: 14),
                      _RecoveryActionCard(
                        busy: _busy,
                        meta: meta,
                        cuenta: cuenta,
                        referenciaCtrl: _capacitacionReferenciaCtrl,
                        descripcionCtrl: _capacitacionDescripcionCtrl,
                        puntosCtrl: _puntosCtrl,
                        onSumar: _acreditarCapacitacion,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _HistoryCard(cuenta: cuenta),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ShiftGateView extends StatelessWidget {
  final bool checking;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback onExit;

  const _ShiftGateView({
    required this.checking,
    required this.message,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Validando turno activo...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      children: [
        _Panel(
          icon: Icons.lock_clock,
          title: 'Módulo bloqueado por turno',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message ??
                    'El backend no confirmó que estés trabajando actualmente. Por seguridad, el módulo queda bloqueado.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Validar de nuevo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Salir del módulo'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BiometricGateView extends StatelessWidget {
  final bool checking;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback onExit;

  const _BiometricGateView({
    required this.checking,
    required this.message,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Solicitando verificación biométrica...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      children: [
        _Panel(
          icon: Icons.fingerprint,
          title: 'Biometría obligatoria',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message ??
                    'Para usar puntos de licencia necesitas huella o rostro registrado en este dispositivo.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Verificar de nuevo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Salir del módulo'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback? onScan;

  const _HeroCard({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_outlined, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          const Text(
            'Escanea la licencia y revisa puntos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1. Escanear código. 2. Revisar nombre y saldo. 3. Aplicar acción solo si tienes permiso.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .92),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear licencia'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupCard extends StatelessWidget {
  final bool busy;
  final TextEditingController numeroCtrl;
  final TextEditingController titularCtrl;
  final TextEditingController tipoCtrl;
  final Map<String, String> tiposLicencia;
  final TextEditingController telefonoCtrl;
  final Future<void> Function() onSearch;
  final Future<void> Function() onScan;

  const _LookupCard({
    required this.busy,
    required this.numeroCtrl,
    required this.titularCtrl,
    required this.tipoCtrl,
    required this.tiposLicencia,
    required this.telefonoCtrl,
    required this.onSearch,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.manage_search,
      title: 'Datos leídos',
      child: Column(
        children: [
          TextField(
            controller: numeroCtrl,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Número de licencia',
              helperText:
                  'Este dato es el importante. Revísalo antes de guardar.',
              prefixIcon: Icon(Icons.pin),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => busy ? null : onSearch(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titularCtrl,
            decoration: const InputDecoration(
              labelText: 'Titular',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: LicenciaTipoCatalog.normalize(tipoCtrl.text),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de licencia',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            hint: const Text('Seleccionar'),
            items: tiposLicencia.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: busy ? null : (value) => tipoCtrl.text = value ?? '',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'WhatsApp del titular (10 dígitos)',
              helperText: 'Ejemplo: 4434765057. No escribas 521.',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onSearch,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(busy ? 'Buscando...' : 'Buscar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CuentaCard extends StatelessWidget {
  final LicenciaPuntoCuenta? cuenta;

  const _CuentaCard({required this.cuenta});

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    if (c == null) {
      return const _NoticeCard(
        title: 'Sin licencia consultada',
        text: 'Escanea o captura el número de licencia para revisar su saldo.',
        icon: Icons.info_outline,
      );
    }

    final color = _saldoColor(c.saldoActual);
    return _Panel(
      icon: Icons.scoreboard_outlined,
      title: c.cuentaRegistrada
          ? 'Saldo actual'
          : 'Sin movimientos registrados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '${c.saldoActual}',
                  style: TextStyle(
                    color: color,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ ${c.saldoMaximo} puntos',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoLine(label: 'Licencia', value: c.numeroLicencia),
          _InfoLine(
            label: 'Tipo',
            value: c.tipoLicenciaLabel.isEmpty
                ? 'Pendiente'
                : c.tipoLicenciaLabel,
          ),
          _InfoLine(
            label: 'Titular',
            value: c.titularNombre.isEmpty ? 'Pendiente' : c.titularNombre,
          ),
          _InfoLine(
            label: 'Estado',
            value: c.estadoLabel.isEmpty ? 'Vigente' : c.estadoLabel,
          ),
          _InfoLine(
            label: 'WhatsApp',
            value: c.telefono.isEmpty ? 'Pendiente' : _telefonoMx10(c.telefono),
          ),
          _InfoLine(
            label: 'Recuperación',
            value: c.fechaRecuperacion.isEmpty
                ? 'Saldo completo o sin fecha'
                : _fmtDate(c.fechaRecuperacion),
          ),
          if (!c.cuentaRegistrada) ...[
            const SizedBox(height: 10),
            Text(
              'No hay descuentos registrados. Para consulta se asume saldo completo.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscountActionCard extends StatelessWidget {
  final bool busy;
  final LicenciaPuntosMeta meta;
  final int? infraccionId;
  final TextEditingController referenciaCtrl;
  final TextEditingController descripcionCtrl;
  final ValueChanged<int?> onInfraccionChanged;
  final Future<void> Function() onRestar;

  const _DiscountActionCard({
    required this.busy,
    required this.meta,
    required this.infraccionId,
    required this.referenciaCtrl,
    required this.descripcionCtrl,
    required this.onInfraccionChanged,
    required this.onRestar,
  });

  @override
  Widget build(BuildContext context) {
    LicenciaPuntoInfraccion? selectedInfraccion;
    for (final item in meta.infracciones) {
      if (item.id == infraccionId) {
        selectedInfraccion = item;
        break;
      }
    }
    return _Panel(
      icon: Icons.remove_circle_outline,
      title: 'Restar puntos por penalización',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meta.infracciones.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Text(
                'Primero registra penalizaciones en Admin Settings. La app no permite inventar puntos manuales.',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<int>(
              value: infraccionId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Penalización del catálogo',
                border: OutlineInputBorder(),
              ),
              items: meta.infracciones
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text('${item.nombre} (-${item.puntos})'),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : onInfraccionChanged,
            ),
            const SizedBox(height: 10),
            _AutomaticDiscountNotice(infraccion: selectedInfraccion),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: referenciaCtrl,
            decoration: const InputDecoration(
              labelText: 'Referencia / folio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descripcionCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción breve',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: busy || meta.infracciones.isEmpty ? null : onRestar,
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(
              busy ? 'Procesando...' : 'Aplicar descuento automático',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryActionCard extends StatelessWidget {
  final bool busy;
  final LicenciaPuntosMeta meta;
  final LicenciaPuntoCuenta? cuenta;
  final TextEditingController referenciaCtrl;
  final TextEditingController descripcionCtrl;
  final TextEditingController puntosCtrl;
  final Future<void> Function() onSumar;

  const _RecoveryActionCard({
    required this.busy,
    required this.meta,
    required this.cuenta,
    required this.referenciaCtrl,
    required this.descripcionCtrl,
    required this.puntosCtrl,
    required this.onSumar,
  });

  @override
  Widget build(BuildContext context) {
    final saldoMaximo = meta.saldoMaximo;
    final maxRecuperable = cuenta == null
        ? saldoMaximo
        : (saldoMaximo - cuenta!.saldoActual).clamp(0, saldoMaximo).toInt();
    final puedeCapturar = cuenta?.id != null && maxRecuperable > 0 && !busy;
    final helper = cuenta?.id == null
        ? 'Primero busca una licencia registrada.'
        : maxRecuperable <= 0
        ? 'La licencia ya tiene el tope de $saldoMaximo puntos.'
        : 'Máximo a recuperar ahora: $maxRecuperable. El tope legal es $saldoMaximo.';

    return _Panel(
      icon: Icons.school_outlined,
      title: 'Recuperar puntos por capacitación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Esta sección es aparte del descuento por penalización. Úsala sólo para cursos validados por Fomento.',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: puntosCtrl,
            enabled: puedeCapturar,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
              _MaxIntInputFormatter(maxRecuperable > 0 ? maxRecuperable : 0),
            ],
            decoration: InputDecoration(
              labelText: 'Puntos a recuperar por curso',
              helperText: helper,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: referenciaCtrl,
            decoration: const InputDecoration(
              labelText: 'Referencia del curso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descripcionCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción del curso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: puedeCapturar ? onSumar : null,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Acreditar capacitación'),
          ),
        ],
      ),
    );
  }
}

class _MaxIntInputFormatter extends TextInputFormatter {
  final int max;

  const _MaxIntInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final value = int.tryParse(text);
    if (value == null) return oldValue;
    if (max <= 0) return const TextEditingValue();
    if (value <= max) return newValue;

    final clamped = max.toString();
    return TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
  }
}

class _AutomaticDiscountNotice extends StatelessWidget {
  final LicenciaPuntoInfraccion? infraccion;

  const _AutomaticDiscountNotice({required this.infraccion});

  @override
  Widget build(BuildContext context) {
    final puntos = infraccion?.puntos ?? 0;
    final nombre = infraccion?.nombre ?? 'Selecciona una penalización';
    final fundamento = infraccion?.fundamentoLegal.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rule, color: Color(0xFFB91C1C)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  puntos > 0
                      ? '$nombre resta $puntos punto${puntos == 1 ? '' : 's'} automáticamente. Ese valor viene del catálogo en Admin Settings.'
                      : 'Selecciona la penalización. Los puntos se toman del catálogo en Admin Settings.',
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                if (fundamento.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    fundamento,
                    style: const TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final LicenciaPuntoCuenta? cuenta;

  const _HistoryCard({required this.cuenta});

  @override
  Widget build(BuildContext context) {
    final movimientos =
        cuenta?.movimientos ?? const <LicenciaPuntoMovimiento>[];
    if (movimientos.isEmpty) {
      return const _NoticeCard(
        title: 'Sin historial',
        text: 'Cuando existan descuentos o recuperaciones aparecerán aquí.',
        icon: Icons.history,
      );
    }

    return _Panel(
      icon: Icons.history,
      title: 'Historial',
      child: Column(
        children: movimientos.take(12).map((mov) {
          final color = mov.puntos < 0
              ? const Color(0xFFDC2626)
              : (mov.puntos > 0 ? const Color(0xFF16A34A) : Colors.grey);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              mov.infraccionNombre.isNotEmpty
                  ? mov.infraccionNombre
                  : mov.tipo.replaceAll('_', ' '),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                if (mov.descripcion.isNotEmpty) mov.descripcion,
                if (mov.infraccionFundamentoLegal.isNotEmpty)
                  mov.infraccionFundamentoLegal,
                if (mov.referencia.isNotEmpty) 'Folio: ${mov.referencia}',
                'Saldo ${mov.saldoAnterior} -> ${mov.saldoNuevo}',
              ].join('\n'),
            ),
            trailing: Text(
              mov.puntos > 0 ? '+${mov.puntos}' : '${mov.puntos}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ScanSummaryCard extends StatelessWidget {
  final LicenciaQrData data;

  const _ScanSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.fact_check_outlined,
      title: 'Lectura del código',
      child: Column(
        children: [
          _InfoLine(label: 'Número', value: data.numeroLicencia ?? 'No leído'),
          _InfoLine(label: 'Nombre', value: data.nombre ?? 'No leído'),
          _InfoLine(
            label: 'Nacimiento',
            value: data.fechaNacimiento == null
                ? 'No leído'
                : _fmtDate(data.fechaNacimiento!.toIso8601String()),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Panel({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _NoticeCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: icon,
      title: title,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF991B1B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenciaPuntosScannerScreen extends StatefulWidget {
  const _LicenciaPuntosScannerScreen();

  @override
  State<_LicenciaPuntosScannerScreen> createState() =>
      _LicenciaPuntosScannerScreenState();
}

class _LicenciaPuntosScannerScreenState
    extends State<_LicenciaPuntosScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    cameraResolution: const Size(1920, 1080),
    lensType: CameraLensType.normal,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: false,
    initialZoom: 0,
  );
  final ImagePicker _picker = ImagePicker();

  bool _handled = false;

  bool _finishCapture(BarcodeCapture capture) {
    if (_handled) return true;

    for (final barcode in capture.barcodes) {
      final raw = LicenciaBarcodePayload.fromBarcode(barcode)?.trim() ?? '';
      if (raw.isEmpty) continue;

      _handled = true;
      unawaited(_controller.stop());
      if (!mounted) return true;
      Navigator.pop(context, raw);
      return true;
    }

    return false;
  }

  void _handleDetect(BarcodeCapture capture) {
    _finishCapture(capture);
  }

  Future<void> _scanFromPhoto() async {
    if (_handled) return;

    await _controller.stop();
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
      );
      if (picked == null || !mounted || _handled) return;

      final capture = await _controller.analyzeImage(picked.path);
      if (capture != null && _finishCapture(capture)) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo leer el QR en la foto. Tómala más cerca, bien enfocada y con el QR completo.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo analizar la foto: $e')),
      );
    } finally {
      if (mounted && !_handled) {
        unawaited(_controller.start());
      }
    }
  }

  Future<void> _focusAt(Offset localPosition, Size size) async {
    if (!_controller.value.isInitialized || !_controller.value.isRunning) {
      return;
    }

    final dx = size.width <= 0
        ? 0.5
        : (localPosition.dx / size.width).clamp(0.0, 1.0).toDouble();
    final dy = size.height <= 0
        ? 0.5
        : (localPosition.dy / size.height).clamp(0.0, 1.0).toDouble();

    try {
      await _controller.setFocusPoint(Offset(dx, dy));
    } catch (_) {
      // Some devices ignore manual focus while the analyzer is busy.
    }
  }

  Future<void> _focusCenter() async {
    if (!_controller.value.isInitialized || !_controller.value.isRunning) {
      return;
    }

    try {
      await _controller.setFocusPoint(const Offset(0.5, 0.5));
    } catch (_) {
      // Best effort only; scanning still works on devices without tap focus.
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear licencia'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Quitar zoom',
            icon: const Icon(Icons.zoom_out_map),
            onPressed: () => unawaited(_controller.resetZoomScale()),
          ),
          IconButton(
            tooltip: 'Enfocar',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => unawaited(_focusCenter()),
          ),
          IconButton(
            tooltip: 'Tomar foto',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => unawaited(_scanFromPhoto()),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                unawaited(_focusAt(details.localPosition, previewSize)),
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  fit: BoxFit.contain,
                  onDetect: _handleDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudo iniciar la cámara.\n\n$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                Center(
                  child: Container(
                    width: (constraints.maxWidth - 48).clamp(240.0, 340.0),
                    height: (constraints.maxWidth - 48).clamp(240.0, 340.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'QR de licencia: ponlo completo dentro del cuadro, sin acercarlo demasiado. Toca el QR para enfocar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.72),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: const Text(
                      'Si no lee en vivo, toca el icono de cámara y toma una foto nítida del QR completo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _saldoColor(int saldo) {
  if (saldo <= 0) return const Color(0xFF111827);
  if (saldo <= 2) return const Color(0xFFDC2626);
  if (saldo <= 4) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}

String _fmtDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'N/A';
  try {
    final dt = DateTime.parse(value).toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  } catch (_) {
    return value;
  }
}

String _telefonoMx10(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D+'), '');
  if (digits.length == 13 && digits.startsWith('521')) {
    digits = digits.substring(3);
  } else if (digits.length == 12 && digits.startsWith('52')) {
    digits = digits.substring(2);
  }
  return digits;
}

String? _telefonoError(String telefono) {
  if (telefono.isEmpty) {
    return 'Captura el WhatsApp del titular para notificar el descuento.';
  }
  if (!RegExp(r'^\d{10}$').hasMatch(telefono)) {
    return 'El WhatsApp debe tener 10 dígitos, sin 521.';
  }
  return null;
}
