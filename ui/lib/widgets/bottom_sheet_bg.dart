import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

class BottomSheetBg extends StatelessWidget {
  const BottomSheetBg({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: context.omniPalette.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
