package cn.com.omnimind.bot.agent.runtime

import cn.com.omnimind.baselib.llm.OpenAiWireApi
import cn.com.omnimind.baselib.llm.ProviderModelOption
import com.google.gson.GsonBuilder

internal const val PI_AGENT_HOME = "/root/.pi/omnibot-acp"
internal const val PI_MODELS_PATH = "$PI_AGENT_HOME/models.json"
internal const val PI_RUNTIME_HEALTH_COMMAND =
    "PATH=/root/.npm-global/bin:\$PATH; export PATH; omnibot-pi-acp --health"

/** Translate shared Provider configuration; the Pi process owns SDK/MCP execution. */
internal object PiConfigAdapter : AgentConfigAdapter {
    override fun map(input: AgentProviderMappingInput): AgentProviderMapping {
        val provider = requireNotNull(input.provider) { "Pi requires a shared Provider." }
        val model = requireNotNull(input.model) { "Select a shared Provider model before starting Pi." }
        return AgentProviderMapping(
            launchConfigPath = PI_MODELS_PATH,
            launchConfigExecutorKey = "pi-model-catalog-read",
            environment = mapOf(
                "PI_CODING_AGENT_DIR" to PI_AGENT_HOME,
                "OMNIBOT_PI_MODELS_PATH" to PI_MODELS_PATH,
                "OMNIBOT_PI_MODEL" to model,
                "OMNIBOT_PI_API_KEY" to provider.apiKey,
                "OMNIBOT_PI_HEADERS" to GsonBuilder().disableHtmlEscaping().create().toJson(provider.customHeaders),
                "OMNIBOT_PI_SKILL_PATHS" to "/workspace/.omnibot/skills",
            ),
        )
    }

    override fun launchConfigWrites(
        input: AgentProviderMappingInput,
        mapping: AgentProviderMapping,
        providerModels: List<ProviderModelOption>,
        existingConfig: String,
    ): List<AgentConfigWrite> = listOf(AgentConfigWrite(
        path = PI_MODELS_PATH,
        content = buildPiModelsJson(requireNotNull(input.provider), requireNotNull(input.model), providerModels),
        executorKey = "pi-model-catalog-write",
    ))
}

internal fun buildPiModelsJson(
    provider: AgentProviderCredentials,
    selectedModel: String,
    models: List<ProviderModelOption>,
): String {
    val anthropic = provider.protocolType == "anthropic"
    val api = when {
        anthropic -> "anthropic-messages"
        OpenAiWireApi.isResponses(provider.wireApi) -> "openai-responses"
        else -> "openai-completions"
    }
    val catalog = (models + ProviderModelOption(id = selectedModel)).distinctBy { it.id }
    val config = mapOf("providers" to mapOf("omnibot" to mapOf(
        "api" to api,
        "baseUrl" to if (anthropic) normalizeAnthropicServiceRoot(provider.baseUrl)
            else normalizeOpenCodeBaseUrl(provider.baseUrl),
        "models" to catalog.map { model -> buildMap<String, Any> {
            val contextWindow = model.contextLimit?.takeIf { it > 0 } ?: 128_000
            put("id", model.id)
            put("name", model.displayName)
            put("reasoning", model.reasoning == true)
            put("input", buildList {
                add("text")
                if (model.inputModalities.any { it.equals("image", ignoreCase = true) } || model.attachment == true) add("image")
            })
            put("contextWindow", contextWindow)
            put("maxTokens", (model.outputLimit?.takeIf { it > 0 } ?: 4096).coerceAtMost(contextWindow))
            if (model.reasoning == true && model.supportedReasoningLevels.isNotEmpty()) {
                val levels = model.supportedReasoningLevels.map { it.trim().lowercase() }.toSet()
                put("thinkingLevelMap", buildMap<String, String?> {
                    for (level in listOf("off", "minimal", "low", "medium", "high", "xhigh", "max")) {
                        // Pi owns each API's special wire value for disabling thinking.
                        if (level == "off" && ("off" in levels || "none" in levels)) continue
                        put(level, level.takeIf { it in levels })
                    }
                })
            }
            put("cost", mapOf("input" to 0, "output" to 0, "cacheRead" to 0, "cacheWrite" to 0))
        } },
    )))
    // Credentials and custom header values belong to the process environment,
    // including host-managed local grants. They never enter models.json.
    return GsonBuilder().serializeNulls().setPrettyPrinting().disableHtmlEscaping().create().toJson(config) + "\n"
}
