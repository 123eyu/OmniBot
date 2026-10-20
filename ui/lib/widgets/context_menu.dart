import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/popup_menu_anchor_position.dart';
import 'package:ui/widgets/omni_menu.dart';

enum RecordMenuAction { edit, delete }

Future<RecordMenuAction?> showRecordContextMenu({
  required BuildContext context,
  required Offset position,
  double maxWidth = 224,
  String? editLabel,
  String? deleteLabel,
  String editIconAsset = 'assets/common/edit.svg',
  String deleteIconAsset = 'assets/common/close.svg',
  Color deleteColor = AppColors.alertRed,
  bool showEdit = true,
  bool showDelete = true,
}) {
  final palette = context.omniPalette;
  final english = Localizations.localeOf(context).languageCode == 'en';
  PopupMenuItem<RecordMenuAction> item({
    required RecordMenuAction action,
    required String label,
    required String asset,
    required IconData fallback,
    required Color color,
  }) => OmniPopupMenuItem<RecordMenuAction>(
    value: action,
    destructive: action == RecordMenuAction.delete,
    child: Row(
      children: [
        SvgPicture.asset(
          asset,
          width: OmniMenuStyle.iconSize,
          height: OmniMenuStyle.iconSize,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          errorBuilder: (_, _, _) =>
              Icon(fallback, size: OmniMenuStyle.iconSize, color: color),
        ),
        const SizedBox(width: OmniMenuStyle.iconGap),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    ),
  );
  return showMenu<RecordMenuAction>(
    context: context,
    position: PopupMenuAnchorPosition.fromGlobalOffset(
      context: context,
      globalOffset: position,
      estimatedMenuHeight:
          ((showEdit ? 1 : 0) + (showDelete ? 1 : 0)) *
              OmniMenuStyle.minHeight +
          OmniMenuStyle.panelPadding.vertical,
    ),
    constraints: BoxConstraints(maxWidth: maxWidth),
    items: [
      if (showEdit)
        item(
          action: RecordMenuAction.edit,
          label: editLabel ?? (english ? 'Edit' : '编辑'),
          asset: editIconAsset,
          fallback: Icons.edit_outlined,
          color: palette.textPrimary,
        ),
      if (showDelete)
        item(
          action: RecordMenuAction.delete,
          label: deleteLabel ?? (english ? 'Delete record' : '删除记录'),
          asset: deleteIconAsset,
          fallback: Icons.close,
          color: deleteColor,
        ),
    ],
  );
}
