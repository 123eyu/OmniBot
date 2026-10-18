# ChatGPT OAuth Provider

OmniBot supports OpenAI's official open-source **Sign in with ChatGPT** flow.
Eligible accounts can authorize their ChatGPT plan for Responses API requests.
This integration does not read ChatGPT conversations or import an OpenAI API key.

## Connect an account

1. Open model provider settings and add/select a provider.
2. Choose **ChatGPT** and select **Continue with ChatGPT**.
3. Complete authorization in the system browser, then return to OmniBot.
4. Refresh the account's model list and select a model for the desired scene.

Each provider profile holds one account/workspace registration. Add another
profile to connect a different account or workspace. Re-authorizing an existing
profile reuses its issued client ID and verifies the same account identity.
The provider name is an editable label; email alone does not identify a
workspace registration.

The browser callback uses a temporary listener bound only to `127.0.0.1`, with
the fixed path `/auth/callback`. Attempts expire after five minutes. Cancelling,
switching the selected profile, deleting the profile, or leaving the settings
page cancels the pending attempt. If Android terminates the process while the
browser is open, reopen settings and start authorization again.

## Ownership and storage

- `ChatGptOAuthManager` and its coordinator own PKCE, callback validation,
  OpenID identity verification, token refresh, cancellation and sign-out.
- Credentials and the installation's stable host ID live in
  Keystore-backed encrypted preferences, excluded from backup/device transfer.
  There is no plaintext fallback. Flutter receives account metadata only.
- Provider profiles store `sourceType=chatgpt_oauth`, the fixed official API
  endpoint and Responses protocol. Their API key/custom header fields stay empty.
- `HttpController` resolves the selected provider identity and obtains a token
  immediately before each request. Refreshes are serialized per profile and
  rotating credentials are replaced together. Cancellation/generation checks
  prevent late callbacks or refreshes from restoring removed credentials.
- Account changes invalidate the provider model catalog through its revision.
  Model choices come from the selected account's `/v1/models` catalog, preserving
  server order and only entries with `visibility=list`.
- Conversation, ACP session, turn and item ownership remain with the existing
  runtime/reducer. OAuth adds no prompt replay or transport retry path.

Signing out immediately stops new local requests with those credentials and
attempts remote session revocation. The account/client mapping and host ID are
retained for later sign-in. If revocation cannot be confirmed, the settings UI
reports that and directs the user to ChatGPT settings. Deleting or converting
the provider removes its local registration as well.

## Supported scope

This provider supports Xiaowan conversations and native text/image-understanding
requests through `HttpController`, including tool calls and context compaction.
Requests use the public `https://api.openai.com/v1/responses` endpoint with
`store=false`, `stream=true`, explicit context, and client-executed function tools.
Only the official `response.completed` event is successful. Errors, incomplete
responses and interrupted streams use the existing error path.

External CLI Harnesses still manage their own ChatGPT authentication, or use an
API-key provider. OmniBot does not copy OAuth tokens into their static launch
configuration. This flow does not provide image generation, speech APIs,
embeddings, or the unsupported hosted Responses tools. Existing providers remain
available for those capabilities. Model/plan availability is determined by
OpenAI and the selected account's granted permissions.

## Verification

Use Java 21 for the Android tests: the embedded terminal contains Java 21 classes.

```sh
./gradlew --no-daemon :baselib:testDebugUnitTest :app:testDevelopStandardDebugUnitTest
./gradlew --no-daemon :app:assembleDevelopStandardDebug -Ptarget=lib/main_standard.dart
cd ui
flutter test test/services/chatgpt_oauth_service_test.dart \
  test/features/home/pages/model_provider_setting/chatgpt_account_section_test.dart \
  test/features/home/pages/model_provider_setting/model_provider_setting_page_test.dart
```

The automated tests cover request shape, account model discovery, terminal SSE
events, PKCE, signed ID tokens, token rotation, cancellation, stale completions,
account isolation and the settings flow. Live account validation additionally
requires a user to complete browser authorization on Android, send a message,
execute a tool, reauthorize, and sign out. Automated tests do not establish live
account eligibility or server acceptance.

### Release credential regression (2026-10-17)

The original minified `developStandardRelease` 0.6.3.3 / versionCode 18 renamed
`ChatGptRegistration` fields to `a` through `k`. Its Gson writer therefore stored
`j` for `scopes`, while the reader required the literal `scopes` key. A successful
browser authorization could save a partial client registration, then fail when
reading it back after token exchange. That failure disabled local credential
access for the process, so subsequent sign-in attempts could not start. Debug
and JVM tests did not exercise R8 and missed this defect.

The credential model now declares all serialized field names explicitly. A
validated codec also reads the exact known legacy mapping and rewrites it in a
single encrypted commit. It retains the account/client mapping, tokens when
present, and the installation host ID. Unknown or conflicting records are
preserved and reported as `secure_storage_invalid_format`; Keystore/read/write
failures use `secure_storage_unavailable`. The UI presents safe stage/error
codes without showing raw exception messages, authorization URLs or tokens.
An affected user should update the app, reopen it, and authorize the same
provider again. Clearing all app data is not required for this known migration.

The verified old mapping SHA-256 is
`ac884c7520d572e4d15fbb2a9c9dcc1af7165c7a78dac1d43d6361bf788d906f`.
Its APK SHA-256 is
`eb9a0f44e1eb4e2bef25af4d629daad60b40454bf396aabbbf1e3c0d83ba29cd`.

The regression checks include Android instrumentation with actual encrypted
preferences and a local callback, plus inspection of the final minified APK:

```sh
./gradlew --no-daemon :baselib:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=cn.com.omnimind.baselib.llm.chatgpt.EncryptedChatGptCredentialStoreTest
./gradlew --no-daemon :app:assembleDevelopStandardRelease -Ptarget=lib/main_standard.dart
python3 scripts/verify-chatgpt-oauth-release-schema.py \
  --apk app/build/outputs/apk/developStandard/release/app-develop-standard-release.apk \
  --mapping app/build/outputs/mapping/developStandardRelease/mapping.txt \
  --dexdump /path/to/android-sdk/build-tools/36.0.0/dexdump
```

The artifact check fails on the affected APK and requires all eleven runtime
`SerializedName` annotations in the new APK, even if R8 renames the class and
fields. It reads compiled metadata only, never account files.

When signing credentials are unavailable, run
`:app:minifyDevelopStandardReleaseWithR8` and pass
`--dex-dir app/build/intermediates/dex/developStandardRelease/minifyDevelopStandardReleaseWithR8`
instead of `--apk`, with
`--mapping app/build/intermediates/mapping/developStandardRelease/minifyDevelopStandardReleaseWithR8/mapping.txt`.
The published `outputs/mapping` copy may still belong to the previous APK until
packaging completes. This verifies the actual R8 output without changing release
signing configuration; it does not produce an installable signed APK.

Current primary-source comparisons also confirm the chosen authentication
contract: [OpenCode's ChatGPT provider](https://github.com/anomalyco/opencode/blob/8c173a8f3805d8e749d44311054b07e37a1b2ce1/packages/core/src/plugin/provider/chatgpt.ts)
and [Pi's ChatGPT OAuth implementation](https://github.com/earendil-works/pi/blob/8efd314fa3d3232ce197d8d7a6a5660530b9d83e/packages/ai/src/auth/oauth/openai-chatgpt.ts)
use the new dynamic-client flow. Pi's separate legacy Codex provider uses a
different client/endpoints; those must not be mixed with the official direct
ChatGPT plan flow used here.

Official contracts:

- [Registration and sign-in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [Accounts and sessions](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [Models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Errors and recovery](https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
