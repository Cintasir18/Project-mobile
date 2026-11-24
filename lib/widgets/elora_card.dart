import 'package:flutter/material.dart';
import 'package:elora_school/theme/colors.dart';

/// Shared surface used by screens that need a consistent ELORA card style.
/// Keep business state and callbacks in the screen; this widget only paints UI.
class EloraCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BorderRadius borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  final double elevation;

  const EloraCard({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.border,
    this.onTap,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = color ?? eloraCard;
    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: eloraInput.withValues(alpha: 0.55)),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: eloraDark.withValues(alpha: 0.06),
                  blurRadius: elevation * 5,
                  offset: Offset(0, elevation * 2),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
