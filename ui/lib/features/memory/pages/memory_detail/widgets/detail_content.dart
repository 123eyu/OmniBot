import 'package:flutter/material.dart';
import 'package:ui/utils/ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:ui/features/memory/pages/memory_center/widgets/tag_chip.dart';
import 'package:ui/features/memory/pages/memory_center/widgets/tag_section.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/ai_generated_badge.dart';

/// 详情内容区域
class DetailContent extends StatelessWidget {
  final String title;
  final int timestamp;
  final String content;
  final String? appName;
  final ImageProvider? appIconProvider;
  final String? appSvgPath;
  final List<AppTag>? tags;

  const DetailContent({
    Key? key,
    required this.title,
    required this.timestamp,
    required this.content,
    this.appName,
    this.appIconProvider,
    this.appSvgPath,
    this.tags,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.55,
      color: palette.textPrimary,
    );
    final headingStyle = bodyStyle.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    );
    return SingleChildScrollView(
      padding: edgeToEdgeScrollPadding(
        context,
        const EdgeInsets.fromLTRB(22, 16, 22, 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headingStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (tags != null && tags!.isNotEmpty)
                for (final tag in tags!)
                  TagChip(
                    title: tag.label,
                    iconPath: tag.icon ?? Icons.label,
                    svgPath: tag.svgPath,
                    appIconProvider: tag.appIconProvider,
                  )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appSvgPath != null)
                      SvgPicture.asset(appSvgPath!, width: 14, height: 14)
                    else if (appIconProvider != null)
                      Image(image: appIconProvider!, width: 14, height: 14)
                    else
                      Icon(Icons.apps, size: 14, color: palette.textTertiary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        appName?.isNotEmpty == true ? appName! : '未知应用',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              Text(
                timestamp > 0
                    ? DateFormat('M月 dd日 HH:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(timestamp)
                            .toLocal(),
                      )
                    : '未知时间',
                style: TextStyle(fontSize: 12, color: palette.textTertiary),
              ),
              AiGeneratedBadge(color: palette.textTertiary),
            ],
          ),
          const SizedBox(height: 20),
          MarkdownBody(
            data: content,
            styleSheet: MarkdownStyleSheet(
              p: bodyStyle,
              h1: headingStyle,
              h2: headingStyle,
              h3: headingStyle.copyWith(fontSize: 15),
              strong: bodyStyle.copyWith(fontWeight: FontWeight.w600),
              em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
              code: bodyStyle.copyWith(
                fontSize: 13,
                fontFamily: 'monospace',
                backgroundColor: palette.surfaceSecondary,
              ),
              codeblockDecoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              blockquote: bodyStyle.copyWith(color: palette.textSecondary),
              blockquoteDecoration: BoxDecoration(
                color: palette.surfaceSecondary,
                border: Border(
                  left: BorderSide(color: palette.borderStrong, width: 2),
                ),
              ),
              listBullet: bodyStyle,
              listBulletPadding: const EdgeInsets.only(right: 8),
            ),
          ),
        ],
      ),
    );
  }
}
