import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/feed_item.dart';
import '../../services/auth_service.dart';
import '../../services/feed_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/feed/feed_item_card.dart';

enum _CaptureRangePreset { today, week, month, custom }

class MisCapturasScreen extends StatefulWidget {
  const MisCapturasScreen({super.key});

  @override
  State<MisCapturasScreen> createState() => _MisCapturasScreenState();
}

class _MisCapturasScreenState extends State<MisCapturasScreen> {
  _CaptureRangePreset _preset = _CaptureRangePreset.today;
  DateTime _desde = _onlyDate(DateTime.now());
  DateTime _hasta = _onlyDate(DateTime.now());

  bool _loading = true;
  bool _loggingOut = false;
  String? _error;
  String _userLabel = 'Usuario actual';
  List<FeedItem> _items = const <FeedItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  static DateTime _onlyDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var userId = await AuthService.getUserId();
      if (userId == null || userId <= 0) {
        await AuthService.getCurrentUserPayload(refresh: true);
        userId = await AuthService.getUserId();
      }

      if (userId == null || userId <= 0) {
        throw Exception('No se pudo identificar tu usuario.');
      }

      final name = (await AuthService.getUserName())?.trim() ?? '';
      final email = (await AuthService.getUserEmail())?.trim() ?? '';
      final label = name.isNotEmpty
          ? name
          : email.isNotEmpty
          ? email
          : 'Usuario actual';

      final response = await FeedService.fetchFeed(
        limit: 200,
        desde: _desde,
        hasta: _hasta,
        userId: userId,
      );

      final items =
          response.items.where((item) => item.userId == userId).toList()
            ..sort((a, b) {
              final ad = a.createdAt;
              final bd = b.createdAt;
              if (ad == null && bd == null) return b.id.compareTo(a.id);
              if (ad == null) return 1;
              if (bd == null) return -1;
              return bd.compareTo(ad);
            });

      if (!mounted) return;
      setState(() {
        _userLabel = label;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _items = const <FeedItem>[];
        _loading = false;
      });
    }
  }

  Future<void> _setPreset(_CaptureRangePreset preset) async {
    if (preset == _CaptureRangePreset.custom) {
      await _pickCustomRange();
      return;
    }

    final today = _onlyDate(DateTime.now());
    final start = switch (preset) {
      _CaptureRangePreset.today => today,
      _CaptureRangePreset.week => today.subtract(const Duration(days: 6)),
      _CaptureRangePreset.month => today.subtract(const Duration(days: 29)),
      _CaptureRangePreset.custom => _desde,
    };

    setState(() {
      _preset = preset;
      _desde = start;
      _hasta = today;
    });
    await _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _onlyDate(DateTime.now()),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
    );

    if (picked == null) return;

    setState(() {
      _preset = _CaptureRangePreset.custom;
      _desde = _onlyDate(picked.start);
      _hasta = _onlyDate(picked.end);
    });
    await _load();
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _openItem(FeedItem item) async {
    if (item.type == FeedItemType.hecho) {
      await Navigator.pushNamed(
        context,
        AppRoutes.accidentesShow,
        arguments: {'hechoId': item.id},
      );
    } else if (item.type == FeedItemType.actividad) {
      await Navigator.pushNamed(
        context,
        AppRoutes.actividadesShow,
        arguments: {'actividad_id': item.id},
      );
    } else if (item.type == FeedItemType.carreteras) {
      await Navigator.pushNamed(
        context,
        AppRoutes.dispositivosShow,
        arguments: {'dispositivoId': item.id},
      );
    } else if (item.type == FeedItemType.vialidades) {
      await Navigator.pushNamed(
        context,
        AppRoutes.vialidadesUrbanasDispositivoShow,
        arguments: {'dispositivoId': item.id},
      );
    }

    if (!mounted) return;
    await _load();
  }

  String _fmtDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  int _count(FeedItemType type) {
    return _items.where((item) => item.type == type).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Mis capturas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HeaderCard(
                userLabel: _userLabel,
                desde: _desde,
                hasta: _hasta,
                formatDate: _fmtDate,
                total: _items.length,
                hechos: _count(FeedItemType.hecho),
                actividades: _count(FeedItemType.actividad),
                carreteras: _count(FeedItemType.carreteras),
                vialidades: _count(FeedItemType.vialidades),
              ),
              const SizedBox(height: 12),
              _RangeSelector(
                preset: _preset,
                onChanged: _setPreset,
                customLabel: _preset == _CaptureRangePreset.custom
                    ? '${_fmtDate(_desde)} - ${_fmtDate(_hasta)}'
                    : 'Personalizado',
              ),
              const SizedBox(height: 14),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final error = _error;
    if (error != null && _items.isEmpty) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar',
        message: error,
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar'),
        ),
      );
    }

    if (_items.isEmpty) {
      return const _MessageCard(
        icon: Icons.inbox_outlined,
        title: 'Sin capturas',
        message: 'No hay capturas tuyas en este rango.',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          FeedItemCard(item: _items[i], onTap: () => _openItem(_items[i])),
          if (i != _items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String userLabel;
  final DateTime desde;
  final DateTime hasta;
  final String Function(DateTime value) formatDate;
  final int total;
  final int hechos;
  final int actividades;
  final int carreteras;
  final int vialidades;

  const _HeaderCard({
    required this.userLabel,
    required this.desde,
    required this.hasta,
    required this.formatDate,
    required this.total,
    required this.hechos,
    required this.actividades,
    required this.carreteras,
    required this.vialidades,
  });

  @override
  Widget build(BuildContext context) {
    final range = desde == hasta
        ? formatDate(desde)
        : '${formatDate(desde)} - ${formatDate(hasta)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_search, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      range,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                total.toString(),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(label: 'Hechos', count: hechos),
              _CountChip(label: 'Actividades', count: actividades),
              _CountChip(label: 'Carreteras', count: carreteras),
              _CountChip(label: 'Vialidades', count: vialidades),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;

  const _CountChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final _CaptureRangePreset preset;
  final String customLabel;
  final Future<void> Function(_CaptureRangePreset preset) onChanged;

  const _RangeSelector({
    required this.preset,
    required this.customLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _RangeChip(
          label: 'Hoy',
          selected: preset == _CaptureRangePreset.today,
          onTap: () => onChanged(_CaptureRangePreset.today),
        ),
        _RangeChip(
          label: 'Semana',
          selected: preset == _CaptureRangePreset.week,
          onTap: () => onChanged(_CaptureRangePreset.week),
        ),
        _RangeChip(
          label: 'Mes',
          selected: preset == _CaptureRangePreset.month,
          onTap: () => onChanged(_CaptureRangePreset.month),
        ),
        _RangeChip(
          label: customLabel,
          selected: preset == _CaptureRangePreset.custom,
          onTap: () => onChanged(_CaptureRangePreset.custom),
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.w900,
      ),
      selectedColor: Colors.blue,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.blue.shade700),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
