import 'package:ui/widgets/omni_menu.dart';

/// Compatibility name for legacy callers of the shared popup-menu entry.
class BlurredMenuItem<T> extends OmniPopupMenuItem<T> {
  const BlurredMenuItem({
    super.key,
    required super.value,
    required super.child,
  });
}
