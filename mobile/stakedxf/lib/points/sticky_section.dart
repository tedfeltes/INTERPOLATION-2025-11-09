import 'package:flutter/material.dart';

/// Sticky section header height used by [StickySectionSliver].
const double kStickySectionHeaderHeight = 40;

/// One collapsible section with a pinned header that stays visible while its
/// content is on screen (Civil / CAD layer-manager style navigation).
class StickySectionSliver extends StatelessWidget {
  const StickySectionSliver({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.trailing,
    this.accent,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = accent ?? cs.primary;
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            height: kStickySectionHeaderHeight,
            child: Material(
              color: cs.surface,
              child: InkWell(
                onTap: onToggle,
                child: Container(
                  height: kStickySectionHeaderHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: cs.outline),
                      left: BorderSide(color: accentColor, width: 3),
                    ),
                    color: cs.surfaceContainerHighest,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 18,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                            color: accentColor,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            sliver: SliverList.list(children: children),
          ),
      ],
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
