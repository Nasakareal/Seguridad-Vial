import 'package:flutter/material.dart';

import '../services/auth_service.dart';

final UnitBrandingNavigatorObserver unitBrandingNavigatorObserver =
    UnitBrandingNavigatorObserver();

class UnitBrandingNavigatorObserver extends NavigatorObserver {
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _refresh() => revision.value++;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _refresh();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _refresh();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _refresh();
  }
}

class UnitBrandingBackdrop extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;
  final double opacity;
  final double widthFactor;
  final Alignment alignment;

  const UnitBrandingBackdrop({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFFF4F7FB),
    this.opacity = .03,
    this.widthFactor = .70,
    this.alignment = const Alignment(0, .05),
  });

  @override
  State<UnitBrandingBackdrop> createState() => _UnitBrandingBackdropState();
}

class _UnitBrandingBackdropState extends State<UnitBrandingBackdrop> {
  late Future<_UnitBranding?> _branding;
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    unitBrandingNavigatorObserver.revision.addListener(_scheduleReload);
    _branding = _resolveBranding();
  }

  @override
  void dispose() {
    unitBrandingNavigatorObserver.revision.removeListener(_scheduleReload);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UnitBrandingBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) {
      _branding = _resolveBranding();
    }
  }

  void _scheduleReload() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadScheduled = false;
      if (!mounted) return;
      setState(() => _branding = _resolveBranding());
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final logicalWidth = mediaQuery?.size.width ?? 400;
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1;
    final decodedWidth = (logicalWidth * widget.widthFactor * devicePixelRatio)
        .round()
        .clamp(1, 1080);

    return FutureBuilder<_UnitBranding?>(
      future: _branding,
      builder: (context, snapshot) {
        final branding = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: widget.backgroundColor),
            if (branding != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: widget.opacity,
                      child: Align(
                        alignment: widget.alignment,
                        child: FractionallySizedBox(
                          widthFactor: widget.widthFactor,
                          child: Image.asset(
                            branding.assetPath,
                            fit: BoxFit.contain,
                            cacheWidth: decodedWidth,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            widget.child,
          ],
        );
      },
    );
  }
}

Future<_UnitBranding?> _resolveBranding() async {
  final unidadId = await AuthService.getUnidadId();
  final assetPath = unitBrandingAssetForUnitId(unidadId);
  if (assetPath == null) return null;
  return _UnitBranding(assetPath: assetPath);
}

String? unitBrandingAssetForUnitId(int? unidadId) {
  return switch (unidadId) {
    1 => 'assets/images/pompella/siniestros.png',
    AuthService.unidadDelegacionesId =>
      'assets/images/pompella/delegaciones.png',
    AuthService.unidadVialidadesUrbanasId =>
      'assets/images/pompella/vialidades.png',
    AuthService.unidadCulturaVialId => 'assets/images/pompella/fomento.png',
    _ => null,
  };
}

class _UnitBranding {
  final String assetPath;

  const _UnitBranding({required this.assetPath});
}
