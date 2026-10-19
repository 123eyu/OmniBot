# Na in the shared Agent mode

Na is a built-in Agent profile (`na-cloud`) in the native catalog. Select **Na** from the existing chat mode menu. It uses the existing `ChatPage`, composer, message/tool cards, conversation drawer, cancellation, and `ChatConversationRuntimeCoordinator` / `AgentEventReducer`. There is no `/home/na` route or separate Na chat/configuration page.

Sign in to the App account and select Na. Managed mode uses the current account credentials to claim the account's authorized workspace and refresh access tokens automatically. `OMNIBOT_CLOUD_URL` defaults to `https://na.omnimind.com.cn`; users do not enter a container address or token. The separate `cloud.omnimind.com.cn` New API/image service keeps its existing address. The App never receives the model-provider API key. Na's model, reasoning, tools and execution permissions remain server-owned; device Provider/model selectors and permission controls are hidden for Na.

Debug builds additionally expose an explicit development connection mode in **Settings → Agent mode → Na → Configure**. Its standalone default is `http://127.0.0.1:8787`, suitable for a physical test device with `adb reverse tcp:8787 tcp:8787`. The development URL is saved locally, while its manually entered token stays only in the App process. Managed mode instead uses encrypted account credentials, including after restart. Account and endpoint ownership checks isolate Na history across logout, account switches and service changes. See [account integration](account-client.zh-CN.md) for the managed connection contract.

## Runtime boundary

`NaCloudRuntime.kt` adapts Na HTTP to the App's existing internal session API; Na does not run an ACP server or use ACP on the network. A namespaced cloud conversation UUID is bound through `AgentSessionBindingRepository` to the existing local Conversation. The App prompt reservation is Na's `clientMessageId`; the submitted user item is retained separately as `clientUserMessageId`, including when a retry retains an older user id. Model/permission parameters from the device are never forwarded to Na.

The native adapter reads durable run snapshots every 600 ms, emits normalized session updates to the shared reducer, and resolves the existing prompt response when Na reports completed/cancelled/failed. One HTTP transport boundary retries failed GET reads at most three times; POST/PUT writes are never automatically replayed. Idle cancellation is harmless, active cancellation calls the owning Na run, and changing the service address is blocked while an App prompt is active. Instance namespacing prevents an old conversation from being sent to a different service.

Session loading returns cloud history using the same prompt/item identities as live updates. The existing snapshot mapper and coordinator merge it with committed App history, preserving live turns and user queries. Listing cloud sessions creates the ordinary local conversation bindings; opening them hydrates the shared chat.

Na files use the existing remote workspace browser and file preview/save/share components. The native HTTP adapter maps `/workspace` to Na's files API. Text editing uses the existing editor and `PUT /api/files/content`; unsupported rename/delete actions are hidden. Download and upload limits remain 20 MiB and 10 MiB.

App chat attachments use the same authenticated binary upload endpoint. Each file is limited to 10 MiB (10,485,760 bytes), including providers with unknown or inaccurate size metadata. The existing prompt reservation stages all selected sources in private cache, uploads them sequentially to collision-resistant `attachment-<uuid>-<name>` paths, then submits one message with Na's existing `[附件]` references. Android paths and document URIs stay on the phone. Temporary copies are removed on success, failure or cancellation; account generation checks fence uploads and message admission after logout or account switching. PUT and message POST are never automatically replayed.

If an upload fails, the message is not submitted. Files already uploaded before a later failure remain in the user's workspace and count toward its storage quota; the files API has no delete/rollback endpoint. A manual retry creates a new prompt reservation. Reopening the same local conversation preserves attachment cards under the original user-message ID; a device without local metadata sees the cloud file references.

## Checks

Use the configured Flutter SDK `/Users/ocean/.local/share/flutter/3.47.2/bin/flutter`. The final focused suite includes Agent configuration, menu selection, shared reducer/coordinator, Harness switching, remote workspace and runtime-service tests. Native `NaItemProjectionTest` covers repeated snapshots, whitespace, tool completion, reasoning identity, inconsistent visible text and restored prompt/item ids.

Build the authorized developer APK with:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
PATH=/Users/ocean/.local/share/flutter/3.47.2/bin:$PATH \
./gradlew --no-daemon :app:assembleDevelopStandardDebug \
  -Ptarget=lib/main_standard.dart -Ptarget-platform=android-arm64
```

Artifact: `app/build/outputs/apk/developStandard/debug/app-develop-standard-debug.apk`.

Earlier independent Na-page acceptance is historical and does not establish acceptance of this shared integration. Current build/test/device evidence is recorded in the sibling [Na App integration](../../codex/na/docs/app-integration.md). No repository commit or production rollout is implied.

## Current delivery evidence (2026-10-09)

The shared integration passed 433 focused Flutter tests, then all four workspace tests including the added owner-switch regression; seven native adapter tests and 52 Na service tests passed. The APK builds successfully. Static analysis reports no errors; existing warnings and style infos remain. PJD110 fixture acceptance verified the original composer, tool cards, cancellation, unique history after reopening, workspace listing, Markdown preview and server-confirmed edited file content. This fixture uses public test credentials and a deterministic runner; the user subsequently authorized account-token entry, and real-model device acceptance also passed (see below).

Final APK SHA-256: `dfcd71b2acc34f8c78b1a7a21227fa3c83af73f3f726f635f5b46f37ab8483f9`. The device configuration is restored to `http://127.0.0.1:8787`; no fixture token is retained. Na remains managed by `dev.omnimind.na.local`. Detailed device evidence lives in the sibling Na documentation.

## Authorized real-model device acceptance (2026-10-09)

PJD110 used the same delivered APK and existing chat/configuration/workspace pages against the live Na service. DeepSeek `deepseek-flash` at `https://api.deepseek.com` completed three runs; the original Stop button cancelled one real running shell tool. The same conversation continued successfully after cancellation. Actual command execution exited with code 0 and generated `na-app-live-20261009-2237.txt`; its contents were verified at the server and in the existing App file preview. Latest replies survived reopening the original history once each. No runs remain active. The account token stays in this App process; no provider key was transferred to the phone. Evidence: sibling `codex/na/test-results/shared-app-live.json`.
