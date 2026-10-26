import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/omni_circle_button.dart';

/// Home's two actions and search editor share one fixed-height surface.
/// Search state, query and focus remain owned by HomeDrawerState.
class HomeSearchHeader extends StatefulWidget {
  const HomeSearchHeader({
    super.key,
    required this.searching,
    required this.title,
    required this.updateIndicator,
    required this.searchField,
    required this.onSearch,
    required this.onClose,
    required this.onMenu,
  });

  final bool searching;
  final Widget title;
  final Widget updateIndicator;
  final Widget searchField;
  final VoidCallback onSearch;
  final VoidCallback onClose;
  final ValueChanged<BuildContext> onMenu;

  @override
  State<HomeSearchHeader> createState() => _HomeSearchHeaderState();
}

class _HomeSearchHeaderState extends State<HomeSearchHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.searching ? 1 : 0,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 380),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _controller.value = widget.searching ? 1 : 0;
  }

  @override
  void didUpdateWidget(HomeSearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searching == widget.searching) return;
    if (_reduceMotion) {
      _controller.value = widget.searching ? 1 : 0;
    } else if (widget.searching) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final textScaler = MediaQuery.textScalerOf(context);
    // A narrow Agent selector can place its name and switch badge on two lines.
    // Reserve the same accessible height in both modes so history never jumps.
    final headerHeight = math.max(
      48.0,
      textScaler.scale(22) * 1.2 + textScaler.scale(11) * 1.2 + 6,
    );
    final actionTop = (headerHeight - 48) / 2;
    final fieldTop = (headerHeight - 38) / 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      child: SizedBox(
        height: headerHeight,
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final motion = _SearchHeaderMotion(
                  constraints.maxWidth,
                  headerHeight,
                  _controller.value,
                );
                final showEditor = widget.searching || !_controller.isDismissed;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      key: const ValueKey('home-search-surfaces'),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SearchHeaderSurfacePainter(
                            motion: motion,
                            color: palette.surfacePrimary,
                            shadowColor: palette.shadowColor,
                          ),
                        ),
                      ),
                    ),
                    if (!_controller.isCompleted)
                      Positioned(
                        key: const ValueKey('home-search-title-layer'),
                        left: 0,
                        right: 104,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: widget.searching,
                          child: ExcludeFocus(
                            excluding: widget.searching,
                            child: ExcludeSemantics(
                              excluding: widget.searching,
                              child: Opacity(
                                opacity: motion.titleOpacity,
                                child: Transform.translate(
                                  offset: Offset(
                                    -8 * (1 - motion.titleOpacity),
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: widget.title,
                                        ),
                                      ),
                                      // Never mount the update action in search
                                      // mode, including its opening frames.
                                      if (!widget.searching)
                                        widget.updateIndicator,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showEditor)
                      Positioned(
                        key: const ValueKey('home-search-editor-layer'),
                        left: 0,
                        right: 56,
                        top: fieldTop,
                        height: 38,
                        child: IgnorePointer(
                          ignoring: !widget.searching,
                          child: ExcludeFocus(
                            excluding: !widget.searching,
                            child: ExcludeSemantics(
                              excluding: !widget.searching,
                              child: ClipRRect(
                                clipper: _SearchEditorClipper(
                                  motion.field.shift(Offset(0, -fieldTop)),
                                ),
                                child: Opacity(
                                  opacity: motion.fieldOpacity,
                                  // Layout the editor at its final width from
                                  // the first frame; reveal without squeezing
                                  // text, replacing its element or losing IME.
                                  child: widget.searchField,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_controller.isCompleted)
                      Positioned(
                        key: const ValueKey('home-search-moving-layer'),
                        left: motion.searchCenter.dx - 24,
                        top: actionTop,
                        width: 48,
                        height: 48,
                        child: IgnorePointer(
                          ignoring:
                              widget.searching || motion.searchOpacity < 0.05,
                          child: ExcludeFocus(
                            excluding:
                                widget.searching || motion.searchOpacity < 0.05,
                            child: ExcludeSemantics(
                              excluding:
                                  widget.searching ||
                                  motion.searchOpacity < 0.05,
                              child: Opacity(
                                opacity: motion.searchOpacity,
                                // The animation slot is a tight 48dp hit area.
                                // Loosen its constraints so the shared button's
                                // visible 40dp surface is not stretched to 48dp.
                                child: Center(
                                  child: OmniCircleButton(
                                    key: const ValueKey('home-search-button'),
                                    size: 40,
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                    surfaceOpacity: 1 - motion.surfaceBlend,
                                    icon: LucideIcons.search,
                                    tooltip: english
                                        ? 'Search conversations'
                                        : '搜索对话',
                                    onPressed: widget.onSearch,
                                    iconWidget: Icon(
                                      LucideIcons.search,
                                      key: const ValueKey(
                                        'home-search-moving-icon',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      key: const ValueKey('home-search-menu-layer'),
                      right: 0,
                      top: actionTop,
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Builder(
                          builder: (anchorContext) => OmniCircleButton(
                            key: ValueKey(
                              widget.searching
                                  ? 'home-close-search'
                                  : 'home-menu-button',
                            ),
                            size: 40,
                            tapTargetSize: MaterialTapTargetSize.padded,
                            surfaceOpacity: 1 - motion.surfaceBlend,
                            icon: widget.searching
                                ? LucideIcons.x
                                : LucideIcons.ellipsis,
                            tooltip: widget.searching
                                ? MaterialLocalizations.of(context)
                                      .closeButtonTooltip
                                : MaterialLocalizations.of(context)
                                      .showMenuTooltip,
                            onPressed: widget.searching
                                ? widget.onClose
                                : _controller.isDismissed
                                ? () => widget.onMenu(anchorContext)
                                : null,
                            iconWidget: SizedBox.square(
                              dimension: OmniCircleButton.defaultIconSize,
                              child: Stack(
                                children: [
                                  Opacity(
                                    opacity: 1 - motion.closeProgress,
                                    child: const Icon(LucideIcons.ellipsis),
                                  ),
                                  Opacity(
                                    opacity: motion.closeProgress,
                                    child: Transform.rotate(
                                      angle:
                                          (1 - motion.closeProgress) *
                                          math.pi /
                                          4,
                                      child: const Icon(LucideIcons.x),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHeaderMotion {
  _SearchHeaderMotion(this.width, this.height, this.progress);

  final double width;
  final double height;
  final double progress;

  double phase(
    double begin,
    double end, [
    Curve curve = Curves.easeInOutCubic,
  ]) => Interval(begin, end, curve: curve).transform(progress);

  Offset get menuCenter => Offset(width - 24, height / 2);
  Offset get searchCenter => Offset(
    lerpDouble(width - 76, menuCenter.dx, phase(0, 0.48))!,
    height / 2,
  );
  double get searchRadius => 20 * (1 - phase(0.32, 0.62));
  double get neck => phase(0, 0.16) * (1 - phase(0.48, 0.65));
  double get titleOpacity => 1 - phase(0, 0.28, Curves.easeOutCubic);
  double get searchOpacity => 1 - phase(0.18, 0.42);
  double get closeProgress => phase(0.22, 0.62);
  double get fieldProgress => phase(0.32, 1, Curves.easeOutCubic);
  double get fieldOpacity => phase(0.68, 0.96, Curves.easeOutCubic);
  // At both endpoints only OmniCircleButton paints the buttons. The liquid
  // surface takes over briefly while they join, then yields to the same shared
  // fill and shadow without swapping out the controls or snapping styles.
  double get surfaceBlend => phase(0, 0.12) * (1 - phase(0.62, 0.82));

  RRect get field => RRect.fromRectAndRadius(
    Rect.lerp(
      Rect.fromCircle(center: menuCenter, radius: 20),
      Rect.fromLTWH(0, (height - 38) / 2, math.max(0, width - 56), 38),
      fieldProgress,
    )!,
    Radius.circular(lerpDouble(20, 12, fieldProgress)!),
  );
}

class _SearchEditorClipper extends CustomClipper<RRect> {
  const _SearchEditorClipper(this.rect);

  final RRect rect;

  @override
  RRect getClip(Size size) => rect;

  @override
  bool shouldReclip(_SearchEditorClipper oldClipper) => rect != oldClipper.rect;
}

/// Two round surfaces share a tangent bridge as they approach. The small
/// vector path needs no screen-wide blur/filter layer or animated relayout.
class _SearchHeaderSurfacePainter extends CustomPainter {
  const _SearchHeaderSurfacePainter({
    required this.motion,
    required this.color,
    required this.shadowColor,
  });

  final _SearchHeaderMotion motion;
  final Color color;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final left = motion.searchCenter;
    final right = motion.menuCenter;
    final radius = motion.searchRadius;
    var buttons = Path()..addOval(Rect.fromCircle(center: right, radius: 20));
    if (radius > 0) {
      buttons = Path.combine(
        PathOperation.union,
        buttons,
        Path()..addOval(Rect.fromCircle(center: left, radius: radius)),
      );
      final distance = right.dx - left.dx;
      if (motion.neck > 0 && distance > 1) {
        final angle = motion.neck * math.pi / 3;
        final cosine = math.cos(angle);
        final sine = math.sin(angle);
        final a = left + Offset(radius * cosine, -radius * sine);
        final b = right + Offset(-20 * cosine, -20 * sine);
        final c = right + Offset(-20 * cosine, 20 * sine);
        final d = left + Offset(radius * cosine, radius * sine);
        final handle = math.min(distance * 0.5, 24.0) * motion.neck;
        final bridge = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(
            a.dx + handle * sine,
            a.dy + handle * cosine,
            b.dx - handle * sine,
            b.dy + handle * cosine,
            b.dx,
            b.dy,
          )
          ..lineTo(c.dx, c.dy)
          ..cubicTo(
            c.dx - handle * sine,
            c.dy - handle * cosine,
            d.dx + handle * sine,
            d.dy - handle * cosine,
            d.dx,
            d.dy,
          )
          ..close();
        buttons = Path.combine(PathOperation.union, buttons, bridge);
      }
    }
    if (motion.surfaceBlend > 0) {
      canvas.drawShadow(
        buttons,
        shadowColor.withValues(alpha: shadowColor.a * motion.surfaceBlend),
        6,
        false,
      );
      canvas.drawPath(
        buttons,
        Paint()..color = color.withValues(alpha: color.a * motion.surfaceBlend),
      );
    }
    if (motion.fieldProgress > 0) {
      canvas.drawRRect(motion.field, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SearchHeaderSurfacePainter oldDelegate) =>
      motion.progress != oldDelegate.motion.progress ||
      motion.width != oldDelegate.motion.width ||
      motion.height != oldDelegate.motion.height ||
      color != oldDelegate.color ||
      shadowColor != oldDelegate.shadowColor;
}
