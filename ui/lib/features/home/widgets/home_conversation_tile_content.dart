import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:ui/models/conversation_model.dart';
import 'package:ui/theme/theme_context.dart';
import 'package:ui/widgets/agent_brand_icon.dart';

/// Shared content for a home conversation row and its context-menu preview.
/// Gesture, selection, editing and runtime ownership remain with the caller.
class HomeConversationTileContent extends StatelessWidget {
  const HomeConversationTileContent({
    super.key,
    required this.conversation,
    required this.title,
    this.titleWidget,
    this.previewOverride,
    this.leading,
    this.badge,
    this.isExecuting = false,
  });

  final ConversationModel conversation;
  final String title;
  final Widget? titleWidget;
  final String? previewOverride;
  final Widget? leading;
  final Widget? badge;
  final bool isExecuting;

  static final _whitespace = RegExp(r'\s+');

  String _preview(bool english) {
    for (final candidate in [previewOverride, conversation.lastMessage]) {
      final text = candidate?.replaceAll(_whitespace, ' ').trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    // summary is a short conversation title; contextSummary is internal model
    // context. Neither represents the latest message shown in this row.
    if (conversation.messageCount > 0) {
      return english ? 'No preview available' : '暂无预览';
    }
    return english ? 'No messages yet' : '暂无消息';
  }

  String _date(Locale locale) {
    final updated = conversation.updatedDate;
    if (updated.year != DateTime.now().year) {
      // Keep the year first even when a large text scale truncates this compact
      // metadata column. The Text semantics still expose the complete date.
      return DateFormat('yyyy/M/d', locale.toLanguageTag()).format(updated);
    }
    return locale.languageCode == 'zh'
        ? DateFormat('M月d日', 'zh').format(updated)
        : DateFormat.MMMd(locale.toLanguageTag()).format(updated);
  }

  Widget _avatar(BuildContext context) {
    final agentId = conversation.agentId?.trim() ?? '';
    if (agentId.isNotEmpty && agentId.toLowerCase() != 'openclaw') {
      return AgentBrandIcon(agentId: agentId, size: 40);
    }
    if (agentId.toLowerCase() == 'openclaw' ||
        conversation.mode == ConversationMode.openclaw) {
      return SvgPicture.asset(
        'assets/home/openclaw.svg',
        width: 40,
        height: 40,
      );
    }
    if (conversation.mode == ConversationMode.chatOnly) {
      return SvgPicture.asset(
        'assets/home/chat/pure_chat.svg',
        width: 40,
        height: 40,
        colorFilter: ColorFilter.mode(
          context.omniPalette.textPrimary,
          BlendMode.srcIn,
        ),
      );
    }
    return const AgentBrandIcon(agentId: 'xiaowan-acp', size: 40);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.omniPalette;
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final titleStyle = TextStyle(
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: palette.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 46,
              child:
                  leading ??
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _avatar(context),
                      if (isExecuting)
                        PositionedDirectional(
                          end: 1,
                          bottom: 1,
                          child: Semantics(
                            label: english ? 'Running' : '进行中',
                            child: Container(
                              key: const ValueKey(
                                'home-conversation-executing-dot',
                              ),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: palette.brandPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.pageBackground,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: titleWidget ?? Text(title, maxLines: 1),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview(english),
                          key: const ValueKey('home-conversation-preview'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 80,
                            maxHeight: 24,
                          ),
                          child: FittedBox(fit: BoxFit.scaleDown, child: badge),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                _date(locale),
                key: const ValueKey('home-conversation-date'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
