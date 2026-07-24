import 'package:flutter/material.dart';

import 'glass.dart';
import 'safe_network_image.dart';

EdgeInsets drawerScrollablePadding(BuildContext context) {
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(14, 0, 14, bottomInset + 72);
}

class DrawerHeaderPanel extends StatelessWidget {
  final IconData? icon;
  final String? avatarText;
  final String? photoUrl;
  final VoidCallback? onPhotoTap;
  final String? backgroundAssetPath;
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
    this.photoUrl,
    this.onPhotoTap,
    this.backgroundAssetPath,
    this.helper,
    this.chips = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      clipBehavior: Clip.antiAlias,
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
        border: Border.all(color: Colors.white.withValues(alpha: .38)),
      ),
      child: Stack(
        children: [
          if ((backgroundAssetPath ?? '').trim().isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: .18,
                    child: Image.asset(
                      backgroundAssetPath!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((photoUrl ?? '').trim().isNotEmpty ||
                  (avatarText ?? '').trim().isNotEmpty ||
                  icon != null) ...[
                _HeaderBadge(
                  icon: icon,
                  avatarText: avatarText,
                  photoUrl: photoUrl,
                  onTap: onPhotoTap,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .92),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
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
    return LiquidGlassSurface(
      opacity: .94,
      blur: 9,
      showShadow: true,
      padding: EdgeInsets.zero,
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
  final String? photoUrl;
  final VoidCallback? onTap;

  const _HeaderBadge({this.icon, this.avatarText, this.photoUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final photo = (photoUrl ?? '').trim();
    if (photo.isNotEmpty) {
      return Semantics(
        button: onTap != null,
        label: 'Ver foto de perfil',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .72),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: SafeNetworkImage(
                  photo,
                  width: 60,
                  height: 60,
                  cacheWidth: 180,
                  cacheHeight: 180,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) =>
                      _InitialsBadge(text: avatarText),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if ((avatarText ?? '').trim().isNotEmpty) {
      return _InitialsBadge(text: avatarText);
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

class _InitialsBadge extends StatelessWidget {
  final String? text;

  const _InitialsBadge({this.text});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white.withValues(alpha: .16),
      child: Text(
        (text ?? '').trim().isEmpty ? 'SV' : text!.trim(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
