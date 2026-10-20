import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ui/services/chatgpt_oauth_service.dart';
import 'package:ui/services/model_provider_config_service.dart';

/// Shared state across the onboarding flow.
///
/// Tracks whether the user has completed cloud AI configuration.
class OnboardingState extends ChangeNotifier {
  bool _cloudConfigured = false;
  String? _configuredProfileId;
  bool _initialized = false;

  bool get cloudConfigured => _cloudConfigured;
  String? get configuredProfileId => _configuredProfileId;
  bool get initialized => _initialized;

  void markCloudConfigured(String profileId) {
    _cloudConfigured = true;
    _configuredProfileId = profileId;
    notifyListeners();
  }

  /// Check persisted state to recover from app restart mid-onboarding.
  Future<void> checkExistingState() async {
    try {
      final profiles = await ModelProviderConfigService.listProfiles();
      final configured = profiles.profiles.where((profile) {
        if (profile.readOnly) return false;
        if (profile.sourceType == ChatGptOAuthService.sourceType) {
          // OAuth profiles intentionally have no API key. The native owner
          // projects readiness only after account and plan authorization.
          return profile.configured && profile.ready;
        }
        return profile.apiKey.isNotEmpty;
      }).toList();
      final selected =
          configured
              .where((profile) => profile.id == profiles.editingProfileId)
              .firstOrNull ??
          configured.firstOrNull;
      _cloudConfigured = selected != null;
      _configuredProfileId = selected?.id;
    } catch (e) {
      debugPrint('OnboardingState.checkExistingState error: $e');
    }
    _initialized = true;
    notifyListeners();
  }
}

/// Auto-disposed provider scoped to the onboarding flow lifetime.
final onboardingStateProvider =
    ChangeNotifierProvider.autoDispose<OnboardingState>(
      (ref) => OnboardingState(),
    );
