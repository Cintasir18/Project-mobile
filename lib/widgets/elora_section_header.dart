import 'package:flutter/material.dart';
import 'package:elora_school/theme/colors.dart';

/// Consistent title/subtitle row for sections across screens.
class EloraSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final CrossAxisAlignment crossAxisAlignment;

  const EloraSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: eloraDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    if (trailing == null) return heading;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: heading), trailing!],
    );
  }
}
