import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/flclash/elastic_press.dart';
import 'package:ui/widgets/flclash/liquid_glass.dart';
import 'package:ui/widgets/flclash/navigation_dock.dart';
import 'package:ui/widgets/omni_glass.dart';

/// The same root destinations as the phone dock, within reach of a tablet's
/// leading edge. The host owns selection and keeps the page tree in place.
class OmniNavigationRail extends StatelessWidget {
  const OmniNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const width = 104.0;

  final List<FlClashNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Align(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: OmniGlassPanel(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(6),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var index = 0;
                      index < destinations.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(height: 6),
                      _destination(context, index),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _destination(BuildContext context, int index) {
    final destination = destinations[index];
    final selected = index == selectedIndex;
    final palette = context.omniPalette;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: '${destination.label} (Ctrl+${index + 1})',
        excludeFromSemantics: true,
        child: FlClashElasticPress(
          enabled: LiquidGlassScope.of(context),
          child: TextButton(
            key: ValueKey('main-navigation-rail-$index'),
            onPressed: () => onDestinationSelected(index),
            style: TextButton.styleFrom(
              foregroundColor: selected
                  ? palette.accentPrimary
                  : palette.textSecondary,
              backgroundColor: selected
                  ? palette.accentPrimary.withValues(alpha: 0.12)
                  : Colors.transparent,
              minimumSize: const Size(double.infinity, 72),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(destination.icon, size: 24),
                const SizedBox(height: 6),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
