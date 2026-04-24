import 'package:flutter/material.dart';

class DrawerHeaderPanel extends StatelessWidget {
  final IconData? icon;
  final String? avatarText;
  final String title;
  final String subtitle;
  final String? helper;
  final List<String> chips;

  const DrawerHeaderPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.avatarText,
    this.helper,
    this.chips = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: .12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderBadge(icon: icon, avatarText: avatarText),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .92),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map((chip) => DrawerHeaderChip(label: chip))
                  .toList(),
            ),
          ],
          if ((helper ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              helper!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DrawerHeaderChip extends StatelessWidget {
  final String label;

  const DrawerHeaderChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DrawerSurface extends StatelessWidget {
  final Widget child;

  const DrawerSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: .04),
          ),
        ],
      ),
      child: child,
    );
  }
}

class DrawerActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool compact;
  final bool danger;
  final bool showChevron;

  const DrawerActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.danger = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 34 : 40,
                height: compact ? 34 : 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: compact ? 18 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: danger ? accent : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawerSectionLabel extends StatelessWidget {
  final String label;

  const DrawerSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData? icon;
  final String? avatarText;

  const _HeaderBadge({this.icon, this.avatarText});

  @override
  Widget build(BuildContext context) {
    if ((avatarText ?? '').trim().isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white.withValues(alpha: .16),
        child: Text(
          avatarText!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon ?? Icons.shield_outlined, color: Colors.white, size: 30),
    );
  }
}
