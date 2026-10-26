import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/theme/theme_context.dart';

@immutable
class OmniSegmentedOption<T> {
  const OmniSegmentedOption({
    required this.value,
    required this.label,
    this.icon,
    this.id,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? id;
}

class OmniSegmentedSlider<T> extends StatelessWidget {
  const OmniSegmentedSlider({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.position,
    this.keyPrefix = 'omni-segment-option',
    this.height = 38,
  });

  final T value;
  final List<OmniSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;
  final double? position;
  final String keyPrefix;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final isDark = context.isDarkTheme;
    const outerPadding = 3.0;
    const trackRadius = 12.0;
    const thumbRadius = 9.5;
    final selectedIndex = options.indexWhere((option) => option.value == value);
    final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final visualPosition = (position ?? safeIndex.toDouble()).clamp(
      0.0,
      options.length - 1.0,
    );
    final highlightedIndex = visualPosition.round();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.segmentTrack,
        borderRadius: BorderRadius.circular(trackRadius),
        border: Border.all(
          color: palette.borderSubtle.withValues(alpha: isDark ? 0.55 : 0.7),
          width: 0.65,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thumbWidth =
                (constraints.maxWidth - outerPadding * 2) / options.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: position != null
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: outerPadding + thumbWidth * visualPosition,
                  top: outerPadding,
                  bottom: outerPadding,
                  width: thumbWidth,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.segmentThumb,
                        borderRadius: BorderRadius.circular(thumbRadius),
                        border: Border.all(
                          color: palette.borderSubtle.withValues(
                            alpha: isDark ? 0.45 : 0.55,
                          ),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.shadowColor.withValues(
                              alpha: isDark ? 0.16 : 0.04,
                            ),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: options
                      .map((option) {
                        final selected =
                            options.indexOf(option) == highlightedIndex;
                        final foreground = selected
                            ? palette.textPrimary
                            : palette.textSecondary;
                        final label = option.icon == null
                            ? Text(option.label)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    option.icon,
                                    size: 14,
                                    color: selected
                                        ? palette.accentPrimary
                                        : palette.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(option.label),
                                ],
                              );

                        return Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                '$keyPrefix-${option.id ?? option.value.toString()}',
                              ),
                              borderRadius: BorderRadius.circular(thumbRadius),
                              splashFactory: NoSplash.splashFactory,
                              highlightColor: Colors.transparent,
                              onTap: () {
                                if (option.value != value) {
                                  HapticFeedback.selectionClick();
                                }
                                onChanged(option.value);
                              },
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: foreground,
                                  ),
                                  child: label,
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
