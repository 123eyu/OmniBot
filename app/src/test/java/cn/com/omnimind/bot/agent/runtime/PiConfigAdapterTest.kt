package cn.com.omnimind.bot.agent.runtime

import cn.com.omnimind.baselib.llm.ProviderModelOption
import com.google.gson.JsonParser
import org.junit.Assert.*
import org.junit.Test

class PiConfigAdapterTest {
    @Test
    fun sharedProviderSelectsTheOfficialWireAndKeepsSecretsOutOfFiles() {
        for ((protocol, wire, api) in listOf(
            Triple("openai_compatible", "chat_completions", "openai-completions"),
            Triple("openai_compatible", "responses", "openai-responses"),
            Triple("anthropic", "chat_completions", "anthropic-messages"),
        )) {
            val provider = AgentProviderCredentials(
                "https://fixture.invalid/v1", "private-key", wireApi = wire, protocolType = protocol,
                customHeaders = mapOf("X-Tenant" to "private-header"),
            )
            val input = AgentProviderMappingInput("pi-acp", provider, "org/model", AcpHarnessAdapters.pi)
            val mapping = AgentConfigAdapterRegistry.map(input)
            val files = AgentConfigAdapterRegistry.launchConfigWrites(input, mapping, listOf(
                ProviderModelOption(id = "org/model", contextLimit = 32000, outputLimit = 4000,
                    inputModalities = listOf("text", "image"), reasoning = true),
                ProviderModelOption(id = "other"),
            ), "{}")
            assertEquals(PI_MODELS_PATH, files.single().path)
            assertEquals("private-key", mapping.environment["OMNIBOT_PI_API_KEY"])
            assertEquals("org/model", mapping.environment["OMNIBOT_PI_MODEL"])
            assertTrue(mapping.environment.getValue("OMNIBOT_PI_HEADERS").contains("private-header"))
            assertFalse(files.single().content.contains("private-key"))
            assertFalse(files.single().content.contains("private-header"))
            val config = JsonParser.parseString(files.single().content).asJsonObject
                .getAsJsonObject("providers").getAsJsonObject("omnibot")
            assertEquals(api, config["api"].asString)
            assertEquals(if (protocol == "anthropic") "https://fixture.invalid" else "https://fixture.invalid/v1", config["baseUrl"].asString)
            val models = config.getAsJsonArray("models")
            assertEquals(2, models.size())
            assertEquals(32000, models[0].asJsonObject["contextWindow"].asInt)
            assertEquals(4000, models[0].asJsonObject["maxTokens"].asInt)
            assertTrue(models[0].asJsonObject["reasoning"].asBoolean)
            assertTrue(models[0].asJsonObject["input"].asJsonArray.any { it.asString == "image" })
        }
    }

    @Test
    fun declaredReasoningLevelsAndSmallModelLimitsArePreserved() {
        val config = JsonParser.parseString(buildPiModelsJson(
            AgentProviderCredentials("https://fixture.invalid/v1", "key"), "small",
            listOf(ProviderModelOption(id = "small", contextLimit = 2048, reasoning = true,
                supportedReasoningLevels = listOf("off", "high", "max"))),
        )).asJsonObject.getAsJsonObject("providers").getAsJsonObject("omnibot")
            .getAsJsonArray("models")[0].asJsonObject
        assertEquals(2048, config["maxTokens"].asInt)
        val thinking = config.getAsJsonObject("thinkingLevelMap")
        assertFalse(thinking.has("off"))
        assertEquals("high", thinking["high"].asString)
        assertEquals("max", thinking["max"].asString)
        assertTrue(thinking["medium"].isJsonNull)
    }

    @Test
    fun aHostManagedResponsesGrantOnlyLivesInTheLaunchEnvironment() {
        val input = AgentProviderMappingInput("pi-acp", AgentProviderCredentials(
            "http://127.0.0.1:32123/v1", "process-grant", wireApi = "responses",
            authentication = AgentProviderAuthentication.HOST_MANAGED,
        ), "selected-model", AcpHarnessAdapters.pi)
        val mapping = AgentConfigAdapterRegistry.map(input)
        val content = AgentConfigAdapterRegistry.launchConfigWrites(input, mapping, emptyList(), "{}").single().content
        assertEquals("process-grant", mapping.environment["OMNIBOT_PI_API_KEY"])
        assertFalse(content.contains("process-grant"))
        assertTrue(content.contains("selected-model"))
        assertTrue(content.contains("openai-responses"))
    }

    @Test
    fun staleProfileOverridesCannotReplaceTheSharedPiProvider() {
        val profile = AcpAgentProfile(
            "pi-acp", "Pi", command = "omnibot-pi-acp", builtIn = true,
            environment = mapOf("OMNIBOT_PI_API_KEY" to "old", "OMNIBOT_PI_MODEL" to "old", "CUSTOM" to "keep"),
            officialRuntime = AcpOfficialRuntime("omnibot-pi-acp", harnessAdapter = AcpHarnessAdapters.pi, usesSharedProvider = true),
        )
        assertEquals(mapOf("CUSTOM" to "keep", "OMNIBOT_PI_MODEL" to "selected"),
            mergeAcpLaunchEnvironment(profile, mapOf("OMNIBOT_PI_MODEL" to "selected")))
    }
}
