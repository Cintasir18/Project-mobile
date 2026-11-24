
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
      height: 280,
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: _MainQuickAccessCard(item: items[0]),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 10,
            child: Column(
              children: [
                for (int i = 1; i < items.length; i++) ...[
                  Expanded(
                    child: _SmallQuickAccessCard(item: items[i]),
                  ),
                  if (i != items.length - 1)
                    const SizedBox(height: 8),
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
    const barHeights = [25.0, 42.0, 32.0, 57.0, 39.0];

    return Material(
      color: const Color(0xFFE5F3F1),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: eloraPrimary,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: eloraPrimary.withValues(alpha: 0.7),
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                height: 65,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 0; i < barHeights.length; i++)
                      Container(
                        width: 12,
                        height: barHeights[i],
                        decoration: BoxDecoration(
                          color: eloraPrimary.withValues(
                            alpha: 0.18 + (i * 0.035),
                          ),
                          borderRadius: BorderRadius.circular(8),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
            ],
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
      color: item.backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: eloraDark.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: item.accentColor,
                ),
              ),

              const SizedBox(width: 8),

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
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
