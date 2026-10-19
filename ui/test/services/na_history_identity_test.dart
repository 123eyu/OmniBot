import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/home/pages/chat/chat_page.dart';
import 'package:ui/features/home/pages/chat/services/chat_conversation_runtime_coordinator.dart';
import 'package:ui/services/agent_event_reducer.dart';
import 'package:ui/models/chat_message_model.dart';
import 'package:ui/features/home/pages/chat/utils/agent_run_timeline.dart';

void main() {
  for (final reason in [null, 'end_turn', 'cancelled']) {
    test(
      'Na terminal history reconciles transport failure, outcome=$reason',
      () {
        final runtime = ChatConversationRuntimeState(
          conversationId: 42,
          mode: kChatRuntimeModeAgent,
        );
        addTearDown(runtime.dispose);
        runtime.currentDispatchTurnId = 'prompt';
        runtime.activeAcpTurnId = 'prompt';
        runtime.activeAcpSessionId = 'na:session';
        const AgentEventReducer().reducePromptResponse(
          runtime: runtime,
          sessionId: 'na:session',
          turnId: 'prompt',
          stopReason: 'error',
          error: 'Network unavailable',
        );
        expect(runtime.messages.any(isAgentTurnFailureMessage), true);
        final snapshot = remoteCodexMessagesFromThreadResponseForTesting({
          'id': 'na:session',
          'agentId': 'na-cloud',
          'turns': [
            {
              'id': 'prompt',
              'status': reason == null ? 'running' : 'completed',
              'stopReason': reason,
              'items': [
                {
                  'id': 'prompt-reply',
                  'type': 'agentMessage',
                  'text': 'remote result',
                },
              ],
            },
          ],
        });
        final merged = mergeRemoteCodexSnapshotMessagesForTesting(
          snapshotMessages: snapshot,
          existingMessages: runtime.messages,
          activeTaskId: null,
          isAiResponding: false,
        );
        expect(merged.any(isAgentTurnFailureMessage), reason == null);
        expect(merged.where((m) => m.text == 'remote result'), hasLength(1));
        if (reason != null)
          expect(merged.single.streamMeta?['stopReason'], reason);
      },
    );
  }
  test(
    'Na reload preserves local attachment cards on the same user message',
    () {
      final local = ChatMessageModel(
        id: 'user-attachment',
        type: 1,
        user: 1,
        content: {
          'text': 'Read the file',
          'attachments': [
            {
              'id': 'file',
              'name': 'report.txt',
              'path': 'content://files/1',
              'size': 17,
            },
          ],
        },
      );
      final snapshot = ChatMessageModel(
        id: local.id,
        type: 1,
        user: 1,
        content: {
          'text': 'Read the file\n\n[附件] attachment-uuid-report.txt',
          'attachments': [],
        },
        streamMeta: {'sessionId': 'na:session', 'turnId': 'turn'},
      );
      final merged = mergeRemoteCodexSnapshotMessagesForTesting(
        snapshotMessages: [snapshot],
        existingMessages: [local],
        activeTaskId: null,
        isAiResponding: false,
      );
      expect(merged, hasLength(1));
      expect(merged.single.text, local.text);
      expect(
        merged.single.content!['attachments'],
        local.content!['attachments'],
      );
      expect(merged.single.sessionId, 'na:session');
      final remote = snapshot.copyWith(
        content: {
          'text': 'remote',
          'attachments': [
            {'name': 'remote.txt'},
          ],
        },
      );
      expect(
        mergeRemoteCodexSnapshotMessagesForTesting(
          snapshotMessages: [remote],
          existingMessages: [local],
          activeTaskId: null,
          isAiResponding: false,
        ).single.content!['attachments'],
        remote.content!['attachments'],
      );
    },
  );

  test('Na history merges live tools once across repeated runner item ids', () {
    const session = 'na:instance:conversation';
    final runtime = ChatConversationRuntimeState(
      conversationId: 42,
      mode: kChatRuntimeModeAgent,
    );
    addTearDown(runtime.dispose);
    const reducer = AgentEventReducer();
    final turns = <Map<String, dynamic>>[];
    for (final turn in ['first-prompt', 'second-prompt']) {
      final callId = '$turn-file';
      runtime.currentDispatchTurnId = turn;
      runtime.activeAcpTurnId = turn;
      for (final status in ['in_progress', 'completed']) {
        reducer.reduce(
          runtime: runtime,
          event: {
            'message': {
              'method': 'session/update',
              'turnId': turn,
              'params': {
                'sessionId': session,
                'update': {
                  'sessionUpdate': status == 'completed'
                      ? 'tool_call_update'
                      : 'tool_call',
                  'toolCallId': callId,
                  'title': 'fixture write phone-result.md',
                  'kind': 'execute',
                  'status': status,
                },
              },
            },
          },
        );
      }
      turns.add({
        'id': turn,
        'status': 'completed',
        'items': [
          {
            'id': callId,
            'type': 'command_execution',
            'command': 'fixture write phone-result.md',
            'status': 'completed',
            'sessionId': session,
            'turnId': turn,
            'toolCallId': callId,
          },
        ],
      });
    }
    final snapshot = remoteCodexMessagesFromThreadResponseForTesting({
      'id': session,
      'agentId': 'na',
      'turns': turns,
    });
    expect(runtime.messages, hasLength(2));
    expect(
      snapshot.map((m) => m.id).toSet(),
      runtime.messages.map((m) => m.id).toSet(),
    );
    final merged = mergeRemoteCodexSnapshotMessagesForTesting(
      snapshotMessages: snapshot,
      existingMessages: runtime.messages,
      activeTaskId: null,
      isAiResponding: false,
    );
    expect(merged, hasLength(2));
    expect(merged.map((m) => m.cardData!['toolCallId']).toSet(), {
      'first-prompt-file',
      'second-prompt-file',
    });
  });
}
