import 'package:flutter/foundation.dart';

enum AuthSessionEventType { organizationalContextChanged, signedOut }

class AuthSessionEvent {
  final AuthSessionEventType type;
  final int sequence;

  const AuthSessionEvent({required this.type, required this.sequence});
}

class AuthSessionEvents {
  AuthSessionEvents._();

  static final ValueNotifier<AuthSessionEvent?> notifier =
      ValueNotifier<AuthSessionEvent?>(null);
  static int _sequence = 0;

  static void organizationalContextChanged() {
    notifier.value = AuthSessionEvent(
      type: AuthSessionEventType.organizationalContextChanged,
      sequence: ++_sequence,
    );
  }

  static void signedOut() {
    notifier.value = AuthSessionEvent(
      type: AuthSessionEventType.signedOut,
      sequence: ++_sequence,
    );
  }

  @visibleForTesting
  static void reset() {
    notifier.value = null;
    _sequence = 0;
  }
}
