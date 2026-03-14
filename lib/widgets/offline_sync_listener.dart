import 'package:flutter/material.dart';

import '../services/offline_sync_service.dart';

class OfflineSyncListener extends StatefulWidget {
  const OfflineSyncListener({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineSyncListener> createState() => _OfflineSyncListenerState();
}

class _OfflineSyncListenerState extends State<OfflineSyncListener> {
  @override
  void initState() {
    super.initState();
    OfflineSyncService.announcements.addListener(_onAnnouncement);
    OfflineSyncService.initialize();
  }

  @override
  void dispose() {
    OfflineSyncService.announcements.removeListener(_onAnnouncement);
    super.dispose();
  }

  void _onAnnouncement() {
    final message = OfflineSyncService.announcements.value;
    if (message == null || message.trim().isEmpty || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

      OfflineSyncService.dismissAnnouncement();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
