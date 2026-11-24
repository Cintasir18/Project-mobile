import 'package:flutter/material.dart';
import 'package:elora_school/theme/colors.dart';

class EloraQuickAccessItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color accentColor;

  const EloraQuickAccessItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.backgroundColor = Colors.white,
    this.accentColor = eloraPrimary,
  });
}

class EloraQuickAccessGrid extends StatelessWidget {
  final List<EloraQuickAccessItem> items;

  const EloraQuickAccessGrid({
    super.key,
    required this.items,
  }) : assert(items.length == 5);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 292,
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: _MainQuickAccessCard(item: items[0]),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 10,
            child: Column(
              children: [
                for (int i = 1; i < items.length; i++) ...[
                  Expanded(
                    child: _SmallQuickAccessCard(item: items[i]),
                  ),

                  if (i != items.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainQuickAccessCard extends StatelessWidget {
  final EloraQuickAccessItem item;

  const _MainQuickAccessCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    const barHeights = [
      24.0,
      40.0,
      30.0,
      55.0,
      37.0,
    ];

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F6F4),
              Color(0xFFDCEFEB),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: eloraPrimary.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: eloraPrimary.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: eloraPrimary.withValues(alpha: 0.08),
          highlightColor: eloraPrimary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.icon,
                        color: eloraPrimary,
                        size: 23,
                      ),
                    ),

                    const Spacer(),

                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        color: eloraPrimary.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                SizedBox(
                  height: 66,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (int i = 0; i < barHeights.length; i++)
                        Container(
                          width: 13,
                          height: barHeights[i],
                          decoration: BoxDecoration(
                            color: eloraPrimary.withValues(
                              alpha: 0.14 + (i * 0.035),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: eloraDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: eloraDark.withValues(alpha: 0.58),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallQuickAccessCard extends StatelessWidget {
  final EloraQuickAccessItem item;

  const _SmallQuickAccessCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: item.backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: eloraDark.withValues(alpha: 0.055),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: item.accentColor.withValues(alpha: 0.08),
          highlightColor: item.accentColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: item.accentColor,
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: eloraDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: eloraDark.withValues(alpha: 0.55),
                          fontSize: 9.5,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: item.accentColor.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}