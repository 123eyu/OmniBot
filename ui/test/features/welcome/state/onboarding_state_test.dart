import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/welcome/state/onboarding_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.com.omnimind.bot/AssistCoreEvent');
  final calls = <String>[];
  var profiles = <Map<String, dynamic>>[];
  var editingId = 'chatgpt-1';

  Map<String, dynamic> oauthProfile({
    String id = 'chatgpt-1',
    bool ready = true,
    bool configured = true,
    bool readOnly = false,
  }) => {
    'id': id,
    'name': 'ChatGPT',
    'baseUrl': 'https://api.openai.com/v1',
    'sourceType': 'chatgpt_oauth',
    'apiKey': '',
    'hasApiKey': false,
    'ready': ready,
    'configured': configured,
    'readOnly': readOnly,
  };

  setUp(() {
    calls.clear();
    profiles = [oauthProfile()];
    editingId = 'chatgpt-1';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          expect(call.method, 'listModelProviderProfiles');
          return {'profiles': profiles, 'editingProfileId': editingId};
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('restores a ready OAuth account without reading credentials', () async {
    final state = OnboardingState();
    addTearDown(state.dispose);
    await state.checkExistingState();
    expect(state.cloudConfigured, isTrue);
    expect(state.configuredProfileId, 'chatgpt-1');
    expect(state.initialized, isTrue);
    expect(calls, ['listModelProviderProfiles']);
  });

  test('does not restore a logged-out or unauthorized OAuth account', () async {
    profiles = [oauthProfile(ready: false)];
    final state = OnboardingState();
    addTearDown(state.dispose);
    await state.checkExistingState();
    expect(state.cloudConfigured, isFalse);
    expect(state.configuredProfileId, isNull);
  });

  test(
    'only selects a usable profile when the editor points elsewhere',
    () async {
      profiles = [oauthProfile(ready: false), oauthProfile(id: 'chatgpt-2')];
      final state = OnboardingState();
      addTearDown(state.dispose);
      await state.checkExistingState();
      expect(state.cloudConfigured, isTrue);
      expect(state.configuredProfileId, 'chatgpt-2');
    },
  );

  test(
    'rechecking after sign-out clears the previous configured state',
    () async {
      final state = OnboardingState();
      addTearDown(state.dispose);
      await state.checkExistingState();
      expect(state.cloudConfigured, isTrue);
      profiles = [oauthProfile(ready: false)];
      await state.checkExistingState();
      expect(state.cloudConfigured, isFalse);
      expect(state.configuredProfileId, isNull);
    },
  );

  test(
    'unconfigured and read-only profiles do not complete onboarding',
    () async {
      profiles = [
        oauthProfile(configured: false),
        oauthProfile(id: 'readonly', readOnly: true),
      ];
      final state = OnboardingState();
      addTearDown(state.dispose);
      await state.checkExistingState();
      expect(state.cloudConfigured, isFalse);
    },
  );

  test('existing API-key provider recovery remains available', () async {
    profiles = [
      {
        'id': 'api-key-provider',
        'name': 'API Provider',
        'baseUrl': 'https://example.test/v1',
        'sourceType': 'custom',
        'apiKey': 'fixture-key',
        'configured': true,
      },
    ];
    editingId = 'api-key-provider';
    final state = OnboardingState();
    addTearDown(state.dispose);
    await state.checkExistingState();
    expect(state.cloudConfigured, isTrue);
    expect(state.configuredProfileId, 'api-key-provider');
  });
}
