import 'package:flutter/material.dart';
import 'package:ui/theme/theme_context.dart';

/// 按钮类型枚举
enum PrimaryButtonType {
  /// 填充类型：主题强调色背景。
  filled,

  /// 轮廓类型：实色表面与细边框。
  outlined,
}

/// 通用主要按钮组件
///
/// 基于 ElevatedButton 封装的可定制按钮组件
class PrimaryButton extends StatelessWidget {
  /// 按钮文字
  final String text;

  /// 点击事件回调
  final VoidCallback? onPressed;

  /// 按钮类型（预设样式）
  final PrimaryButtonType? type;

  /// 按钮宽度，如果不设置则自适应
  final double? width;

  /// 按钮高度，如果不设置则使用默认padding
  final double? height;

  /// 按钮背景颜色（会覆盖 type 预设）
  final Color? backgroundColor;

  /// 按钮禁用时的背景颜色
  final Color? disabledBackgroundColor;

  /// 文字样式，如果不提供则使用默认样式
  final TextStyle? textStyle;

  /// 文字颜色（会覆盖 type 预设）
  final Color? textColor;

  /// 圆角半径
  final double? borderRadius;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 阴影高度
  final double? elevation;

  /// 文字对齐方式
  final TextAlign? textAlign;

  /// 边框颜色（会覆盖 type 预设）
  final Color? borderColor;

  /// 边框宽度（会覆盖 type 预设）
  final double? borderWidth;

  /// 字体大小（会覆盖 type 预设）
  final double? fontSize;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type,
    this.width,
    this.height,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.textStyle,
    this.textColor,
    this.borderRadius,
    this.padding,
    this.elevation,
    this.textAlign,
    this.borderColor,
    this.borderWidth,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    // 根据 type 设置默认值
    Color effectiveBackgroundColor;
    Color effectiveTextColor;
    Color? effectiveBorderColor;
    double effectiveBorderWidth;
    double effectiveFontSize;
    double effectiveBorderRadius;
    EdgeInsetsGeometry effectivePadding;
    double effectiveElevation;
    TextAlign effectiveTextAlign;

    if (type == PrimaryButtonType.filled) {
      effectiveBackgroundColor = palette.accentPrimary;
      effectiveTextColor = Theme.of(context).colorScheme.onPrimary;
      effectiveBorderColor = null;
      effectiveBorderWidth = 0;
      effectiveFontSize = 10;
      effectiveBorderRadius = 60;
      effectivePadding = const EdgeInsets.symmetric(horizontal: 0, vertical: 0);
      effectiveElevation = 0;
      effectiveTextAlign = TextAlign.center;
    } else if (type == PrimaryButtonType.outlined) {
      effectiveBackgroundColor = palette.surfacePrimary;
      effectiveTextColor = palette.textPrimary;
      effectiveBorderColor = palette.borderStrong;
      effectiveBorderWidth = 1;
      effectiveFontSize = 10;
      effectiveBorderRadius = 60;
      effectivePadding = const EdgeInsets.symmetric(horizontal: 0, vertical: 0);
      effectiveElevation = 0;
      effectiveTextAlign = TextAlign.center;
    } else {
      // 默认样式
      effectiveBackgroundColor = palette.accentPrimary;
      effectiveTextColor = Theme.of(context).colorScheme.onPrimary;
      effectiveBorderColor = null;
      effectiveBorderWidth = 0;
      effectiveFontSize = 15;
      effectiveBorderRadius = 14;
      effectivePadding = const EdgeInsets.symmetric(horizontal: 0, vertical: 0);
      effectiveElevation = 0;
      effectiveTextAlign = TextAlign.center;
    }

    // 用户传入的参数覆盖预设值
    effectiveBackgroundColor = backgroundColor ?? effectiveBackgroundColor;
    effectiveTextColor = textColor ?? effectiveTextColor;
    effectiveBorderColor = borderColor ?? effectiveBorderColor;
    effectiveBorderWidth = borderWidth ?? effectiveBorderWidth;
    effectiveFontSize = fontSize ?? effectiveFontSize;
    effectiveBorderRadius = borderRadius ?? effectiveBorderRadius;
    effectivePadding = padding ?? effectivePadding;
    effectiveElevation = elevation ?? effectiveElevation;
    effectiveTextAlign = textAlign ?? effectiveTextAlign;

    Widget button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveBackgroundColor,
        foregroundColor: effectiveTextColor,
        disabledBackgroundColor:
            disabledBackgroundColor ?? palette.surfaceElevated,
        disabledForegroundColor: palette.textTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          side: effectiveBorderColor != null && effectiveBorderWidth > 0
              ? BorderSide(
                  color: effectiveBorderColor,
                  width: effectiveBorderWidth,
                )
              : BorderSide.none,
        ),
        padding: effectivePadding,
        elevation: effectiveElevation,
      ),
      onPressed: onPressed,
      child: Text(
        text,
        textAlign: effectiveTextAlign,
        style:
            textStyle ??
            TextStyle(
              color: onPressed == null
                  ? palette.textTertiary
                  : effectiveTextColor,
              fontSize: effectiveFontSize,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1,
              letterSpacing: 0.50,
            ),
      ),
    );

    // 如果设置了宽高，则使用 SizedBox 包裹
    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: button);
    }

    return button;
  }
}
