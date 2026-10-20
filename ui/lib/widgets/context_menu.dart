import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ui/theme/app_colors.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/utils/popup_menu_anchor_position.dart';

enum RecordMenuAction { edit, delete }

Future<RecordMenuAction?> showRecordContextMenu({
  required BuildContext context,
  required Offset position,
  double maxWidth = 144,
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
  }) => PopupMenuItem<RecordMenuAction>(
    value: action,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SvgPicture.asset(
          asset,
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          errorBuilder: (_, _, _) => Icon(fallback, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(color: color, fontSize: 14)),
        ),
      ],
    ),
  );
  return showMenu<RecordMenuAction>(
    context: context,
    position: PopupMenuAnchorPosition.fromGlobalOffset(
      context: context,
      globalOffset: position,
      estimatedMenuHeight: showEdit && showDelete ? 112 : 64,
    ),
    color: palette.surfacePrimary,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 6,
    shadowColor: palette.shadowColor,
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
      if (showEdit && showDelete)
        PopupMenuDivider(height: 1, color: palette.borderSubtle),
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
