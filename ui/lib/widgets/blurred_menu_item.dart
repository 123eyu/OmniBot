import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

/// Legacy menu entry using the same opaque surface as other app menus.
class BlurredMenuItem<T> extends PopupMenuEntry<T> {
  final T value;
  final Widget child;

  const BlurredMenuItem({required this.value, required this.child});

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(T? value) => value == this.value;

  @override
  State<BlurredMenuItem<T>> createState() => _BlurredMenuItemState<T>();
}

class _BlurredMenuItemState<T> extends State<BlurredMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: context.omniPalette.surfacePrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(widget.value),
          child: widget.child,
        ),
      ),
    );
  }
}
