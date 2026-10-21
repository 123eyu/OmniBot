package cn.com.omnimind.bot.plugin.official.agentweb

import cn.com.omnimind.bot.agent.runtime.normalizeAnthropicServiceRoot

import cn.com.omnimind.baselib.llm.DeepSeekProvider
import cn.com.omnimind.baselib.llm.OpenAiWireApi
import cn.com.omnimind.baselib.llm.ProviderCustomHeaderUtils
import cn.com.omnimind.baselib.llm.ProviderModelOption
import cn.com.omnimind.bot.agent.runtime.AgentProviderCredentials
import cn.com.omnimind.bot.agent.runtime.AcpHarnessAdapters
import cn.com.omnimind.bot.agent.runtime.AgentConfigAdapterRegistry
import cn.com.omnimind.bot.agent.runtime.AgentProviderMappingInput
import cn.com.omnimind.bot.agent.runtime.KIMI_CODE_NATIVE_HEALTH_COMMAND
import cn.com.omnimind.bot.agent.runtime.KIMI_CODE_NPM_INSTALL_COMMAND
import cn.com.omnimind.bot.agent.runtime.buildKimiCodeEnvironment
import cn.com.omnimind.bot.agent.runtime.buildKimiCodeManagedFiles
import java.net.URI
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

private const val DEEPSEEK_HARNESS_NODE_ENTRYPOINT =
    "/root/.npm-global/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"

internal const val DEEPSEEK_HARNESS_WEB_HOME = "/root/.dsh/omnibot-web"
internal const val DEEPSEEK_HARNESS_WEB_PATCH_PATH =
    "$DEEPSEEK_HARNESS_WEB_HOME/omnibot-dispatch.patch.yml"
internal const val DEEPSEEK_HARNESS_API_KEY_ENV = "OMNIBOT_DSH_API_KEY"
internal const val OPENCODE_WEB_CONFIG_PATH = "/root/.config/opencode/omnibot-web.json"
private const val DEEPSEEK_HARNESS_FALLBACK_ROUTE = "omnibot-dispatch"

internal enum class AgentWebUrlKind {
    KIMI,
    DEEPSEEK_HARNESS,
    OPENCODE,
}

internal enum class AgentWebService(
    val id: String,
    val displayName: String,
    val packageId: String,
    val commandName: String,
    val command: String,
    val sessionId: String,
    val urlKind: AgentWebUrlKind,
    val readinessTimeoutMs: Long,
    val minimumMajorVersion: Int? = null,
) {
    KIMI(
        id = "kimi",
        displayName = "Kimi Code Web",
        packageId = "kimi",
        commandName = "kimi",
        command = "kimi web --no-open --host 127.0.0.1",
        // Retain the historical managed id so an app update can take
        // ownership of, validate, and restart an older Web process.
        sessionId = "omnibot-web-kimi",
        urlKind = AgentWebUrlKind.KIMI,
        readinessTimeoutMs = 60_000L,
    ),
    DEEPSEEK_HARNESS(
        id = "deepseek_harness",
        displayName = "DeepSeek Harness Web",
        packageId = "deepseek_harness",
        commandName = "dsh",
        // Cordis HMR reads Node internals under Android proot. Invoke the
        // vendor's published bin directly with the same narrow compatibility
        // flag used by the managed ACP launcher.
        command = "node --expose-internals $DEEPSEEK_HARNESS_NODE_ENTRYPOINT " +
            "web --patch $DEEPSEEK_HARNESS_WEB_PATCH_PATH " +
            "--no-open --host 127.0.0.1 --port 0",
        sessionId = "omnibot-web-dsh",
        urlKind = AgentWebUrlKind.DEEPSEEK_HARNESS,
        readinessTimeoutMs = 90_000L,
    ),
    OPENCODE(
        id = "opencode",
        displayName = "OpenCode Web",
        packageId = "opencode",
        commandName = "opencode",
        // A dedicated foreground server stays under the existing ReTerminal
        // owner. Do not mutate or start OpenCode's shared background service.
        // Unset inherited passwords so the official startup output supplies
        // this process's fresh credentials for /api/pair.
        command = "env -u OPENCODE_PASSWORD -u OPENCODE_SERVER_PASSWORD " +
            "opencode serve --hostname 127.0.0.1 --port 0",
        sessionId = "omnibot-web-opencode",
        urlKind = AgentWebUrlKind.OPENCODE,
        readinessTimeoutMs = 90_000L,
        minimumMajorVersion = 2,
    );
}

internal enum class AgentWebResultCode {
    OPENED,
    RUNNING,
    STARTING,
    STOPPED,
    NOT_RUNNING,
    RUNTIME_MISSING,
    PROVIDER_REQUIRED,
    MODEL_REQUIRED,
    UNSUPPORTED_PROVIDER,
    START_FAILED,
    STOP_FAILED,
    URL_TIMEOUT,
    BROWSER_UNAVAILABLE,
    PAIRING_FAILED,
}

internal data class AgentWebOperationResult(
    val success: Boolean,
    val code: AgentWebResultCode,
    val service: AgentWebService,
    val running: Boolean,
    val reused: Boolean = false,
    val error: String? = null,
) {
    /** The browser URL and its credentials must never cross this boundary. */
    fun toJson(): JsonObject = buildJsonObject {
        put("success", success)
        put("code", code.name)
        put("serviceId", service.id)
        put("packageId", service.packageId)
        put("running", running)
        put("reused", reused)
        error?.takeIf(String::isNotBlank)?.let { put("error", it) }
    }
}

internal data class AgentWebRuntimeSnapshot(
    val running: Boolean,
    val transcript: String,
)

internal data class AgentWebRuntimeLaunch(
    val started: Boolean,
    val alreadyRunning: Boolean,
)

internal interface AgentWebRuntimeGateway {
    suspend fun isRuntimeAvailable(service: AgentWebService): Boolean

    suspend fun snapshot(sessionId: String): AgentWebRuntimeSnapshot?

    suspend fun launch(
        sessionId: String,
        command: String,
        environment: Map<String, String>,
    ): AgentWebRuntimeLaunch

    suspend fun stop(sessionId: String): Boolean

    suspend fun openBrowser(url: String): Boolean

    /** May mint a single-use login link; never cache it as process readiness. */
    suspend fun prepareBrowserUrl(service: AgentWebService, snapshot: AgentWebRuntimeSnapshot): String?
}

internal interface AgentWebConfigurationProvider {
    fun providerCredentials(): AgentProviderCredentials?

    fun modelId(): String?

    fun providerModels(): List<ProviderModelOption> = emptyList()
}

internal data class AgentWebLaunchConfiguration(
    val environment: Map<String, String>,
    val managedFiles: Map<String, String> = emptyMap(),
    val fingerprintSource: String,
)

internal fun buildAgentWebLaunchConfiguration(
    service: AgentWebService,
    provider: AgentProviderCredentials,
    model: String,
    reasoningEffort: String? = null,
    providerModels: List<ProviderModelOption> = emptyList(),
): AgentWebLaunchConfiguration {
    val credentials = provider.normalizedForAgentWeb()
    val modelId = model.trim().also {
        require(it.isNotEmpty()) { "Dispatch Model is required." }
        require(it.none(Char::isISOControl)) { "Dispatch Model contains control characters." }
    }
    val environment: Map<String, String>
    val managedFiles: Map<String, String>
    when (service) {
        AgentWebService.KIMI -> {
            environment = buildKimiCodeEnvironment(
                provider = credentials,
                model = modelId,
                reasoningEffort = reasoningEffort,
            )
            managedFiles = buildKimiCodeManagedFiles(credentials, modelId, reasoningEffort)
        }
        AgentWebService.DEEPSEEK_HARNESS -> {
            environment = buildDeepSeekEnvironment(credentials)
            managedFiles = mapOf(
                DEEPSEEK_HARNESS_WEB_PATCH_PATH to buildDeepSeekProviderPatch(
                    provider = credentials,
                    model = modelId,
                    reasoningEffort = reasoningEffort,
                ),
            )
        }
        AgentWebService.OPENCODE -> {
            require(reasoningEffort.isNullOrBlank()) {
                "Choose OpenCode reasoning options in its Web interface."
            }
            // Use the same configuration owner as ACP, with a dedicated Web
            // overlay instead of overwriting the user's/ACP global config.
            val input = AgentProviderMappingInput(
                agentId = "opencode-acp",
                provider = credentials,
                model = modelId,
                harnessAdapter = AcpHarnessAdapters.openCode,
            )
            val mapping = AgentConfigAdapterRegistry.map(input)
            val write = AgentConfigAdapterRegistry.launchConfigWrites(
                input, mapping, providerModels, "",
            ).single()
            environment = mapping.environment + mapOf("OPENCODE_CONFIG" to OPENCODE_WEB_CONFIG_PATH)
            managedFiles = mapOf(OPENCODE_WEB_CONFIG_PATH to write.content)
        }
    }
    val fingerprintSource = buildString {
        environment.entries
            .sortedBy { it.key }
            .forEach { (key, value) -> appendLine("env:$key=$value") }
        managedFiles.entries
            .sortedBy { it.key }
            .forEach { (path, content) -> appendLine("file:$path=$content") }
    }
    return AgentWebLaunchConfiguration(
        environment = environment,
        managedFiles = managedFiles,
        fingerprintSource = fingerprintSource,
    )
}

private fun AgentProviderCredentials.normalizedForAgentWeb(): AgentProviderCredentials {
    val baseUrl = baseUrl.trim()
    val apiKey = apiKey.trim()
    require(baseUrl.isNotEmpty()) { "Dispatch Provider URL is required." }
    require(apiKey.isNotEmpty()) { "Dispatch Provider API key is required." }
    require(apiKey.none { it == '\r' || it == '\n' }) {
        "Dispatch Provider API key contains line breaks."
    }
    val uri = runCatching { URI(baseUrl) }.getOrNull()
    require(
        uri != null &&
            uri.scheme?.lowercase() in setOf("http", "https") &&
            !uri.host.isNullOrBlank() &&
            uri.rawUserInfo == null &&
            uri.rawQuery == null &&
            uri.rawFragment == null
    ) {
        "Dispatch Provider must use an HTTP(S) base URL without user info, query, or fragment."
    }
    return copy(
        baseUrl = baseUrl,
        apiKey = apiKey,
        wireApi = OpenAiWireApi.normalize(wireApi),
        protocolType = protocolType.trim().lowercase(),
        customHeaders = ProviderCustomHeaderUtils.sanitizeCustomHeaders(customHeaders)
            .mapValues { (_, value) -> value.trim() }
            .filter { (key, value) -> key.isNotEmpty() && value.isNotEmpty() },
    )
}

private fun buildDeepSeekEnvironment(provider: AgentProviderCredentials): Map<String, String> {
    return linkedMapOf(
        DEEPSEEK_HARNESS_API_KEY_ENV to provider.apiKey,
        "DSH_PERMISSION_MODE" to "workspace-write",
        "DSH_HOME" to DEEPSEEK_HARNESS_WEB_HOME,
        "DSH_TELEMETRY_DISABLED" to "1",
        "NODE_NO_WARNINGS" to "1",
    )
}

/**
 * Configure the current DSH Web profile through its official Cordis overlay
 * surface. Current DSH Web reads provider routes and its fresh-session model
 * from `llm-pi-ai` and `agent-default-model`; legacy DSH_MODEL/DSH_PROVIDER
 * variables are not Web configuration inputs.
 *
 * The API key remains an inherited credential reference and is deliberately
 * absent from this persisted patch.
 */
internal fun buildDeepSeekProviderPatch(
    provider: AgentProviderCredentials,
    model: String,
    reasoningEffort: String?,
    acp: Boolean = false,
    providerModelIds: List<String> = emptyList(),
): String {
    val effort = reasoningEffort?.trim()?.lowercase()?.takeIf(String::isNotEmpty)
    require(effort == null || effort in DEEPSEEK_REASONING_EFFORTS) {
        "DeepSeek Harness reasoning effort must be off, minimal, low, medium, high, xhigh, or max."
    }
    val route = resolveDeepSeekHarnessRoute(provider)
    val api = resolveDeepSeekHarnessApi(provider)
    val baseUrl = if (api == "anthropic-messages") {
        normalizeAnthropicServiceRoot(provider.baseUrl)
    } else {
        normalizeOpenAiApiBaseUrl(provider.baseUrl)
    }
    val modelProfiles = (providerModelIds + model).filter { it.isNotBlank() }.distinct().map { modelId ->
      val visionInputSupport = agentWebVisionInputSupport(provider, modelId)
      buildJsonObject {
        put("id", modelId)
        if (route == DEEPSEEK_HARNESS_FALLBACK_ROUTE || visionInputSupport != null) {
            put("input", buildJsonArray {
                add(JsonPrimitive("text"))
                if (visionInputSupport != false) add(JsonPrimitive("image"))
            })
        }
        if (route == DEEPSEEK_HARNESS_FALLBACK_ROUTE || effort != null) {
            put("reasoningEfforts", buildJsonObject {
                // A generic OpenAI route needs an explicit wire value. Null means
                // "omit", which leaves a thinking-by-default server enabled.
                // Known provider dialects keep Pi's own off serialization.
                if (route == DEEPSEEK_HARNESS_FALLBACK_ROUTE && api == "openai-completions") {
                    put("off", "none")
                } else {
                    put("off", JsonNull)
                }
                DEEPSEEK_REASONING_EFFORTS
                    .filterNot { it == "off" }
                    .forEach { level -> put(level, level) }
            })
        }
    }
    }
    val profile = buildJsonObject {
        put("apiKeyEnv", DEEPSEEK_HARNESS_API_KEY_ENV)
        put("displayName", "OmniBot Dispatch")
        put("api", api)
        put("baseURL", baseUrl)
        put("models", buildJsonArray {
            modelProfiles.forEach { add(it) }
        })
        if (provider.customHeaders.isNotEmpty()) {
            put("headers", buildJsonObject {
                provider.customHeaders.forEach { (name, value) -> put(name, value) }
            })
        }
        effort?.let { put("reasoning", it) }
    }
    val providerConfig = buildJsonObject {
        put("providers", buildJsonObject { put(route, profile) })
    }
    val defaultModelConfig = buildJsonObject {
        put("provider", route)
        put("model", model)
    }
    return buildString {
        appendLine("# Generated by OmniBot for the managed DSH process.")
        appendLine("- id: llm-pi-ai")
        appendLine("  config: $providerConfig")
        appendLine(if (acp) "- id: acp" else "- id: agent-default-model")
        appendLine("  config: $defaultModelConfig")
    }
}

/**
 * Preserve the app's tri-state Provider capability policy at the vendor Web
 * boundary. Only a route that explicitly declares text-only loses image
 * input; an unknown BYOK gateway stays permissive and lets the Provider make
 * the final decision.
 */
private fun agentWebVisionInputSupport(
    provider: AgentProviderCredentials,
    model: String,
): Boolean? = DeepSeekProvider.requestCapabilities(
    protocolType = provider.protocolType,
    apiBase = provider.baseUrl,
    model = model,
).supportsVisionInput

private fun resolveDeepSeekHarnessApi(provider: AgentProviderCredentials): String = when {
    provider.protocolType == "anthropic" -> "anthropic-messages"
    OpenAiWireApi.isResponses(provider.wireApi) -> "openai-responses"
    else -> "openai-completions"
}

/** Keep an upstream route identity only when the endpoint is unambiguous. */
private fun resolveDeepSeekHarnessRoute(provider: AgentProviderCredentials): String {
    val host = runCatching { URI(provider.baseUrl).host?.lowercase() }.getOrNull().orEmpty()
    return when {
        provider.protocolType == "anthropic" && host == "api.anthropic.com" -> "anthropic"
        host == "api.deepseek.com" -> "deepseek"
        host == "api.openai.com" -> "openai"
        else -> DEEPSEEK_HARNESS_FALLBACK_ROUTE
    }
}

private fun normalizeOpenAiApiBaseUrl(baseUrl: String): String {
    var normalized = baseUrl.trim().trimEnd('/')
    listOf(
        "/v1/chat/completions",
        "/chat/completions",
        "/v1/responses",
        "/responses",
    ).firstOrNull { normalized.endsWith(it, ignoreCase = true) }?.let { suffix ->
        normalized = normalized.dropLast(suffix.length).trimEnd('/')
    }
    if (normalized.isEmpty()) return normalized
    if (
        normalized.endsWith("/v1", ignoreCase = true) ||
        normalized.endsWith("/compatible-mode/v1", ignoreCase = true)
    ) {
        return normalized
    }
    return "$normalized/v1"
}

private val DEEPSEEK_REASONING_EFFORTS = listOf(
    "off",
    "minimal",
    "low",
    "medium",
    "high",
    "xhigh",
    "max",
)
