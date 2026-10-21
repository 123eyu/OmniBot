package cn.com.omnimind.bot.plugin.official.agentweb

import cn.com.omnimind.bot.agent.runtime.AgentProviderCredentials
import cn.com.omnimind.baselib.llm.ProviderModelOption
import com.google.gson.Gson
import com.google.gson.JsonParser
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentWebRuntimeTest {
    @Test
    fun `service commands bind explicitly to loopback`() {
        assertEquals(
            "kimi web --no-open --host 127.0.0.1",
            AgentWebService.KIMI.command,
        )
        assertEquals(
            "node --expose-internals " +
                "/root/.npm-global/lib/node_modules/@deepseek-ai/dsh/lib/bin.js " +
                "web --patch $DEEPSEEK_HARNESS_WEB_PATCH_PATH " +
                "--no-open --host 127.0.0.1 --port 0",
            AgentWebService.DEEPSEEK_HARNESS.command,
        )
        assertTrue(AgentWebService.OPENCODE.command.contains("opencode serve --hostname 127.0.0.1 --port 0"))
        assertFalse(AgentWebService.OPENCODE.command.contains("--service"))
        assertEquals(2, AgentWebService.OPENCODE.minimumMajorVersion)
    }

    @Test
    fun `Kimi parser accepts only authenticated loopback URLs`() {
        val token = "abc_DEF-1234567890_abcdefghijkl"
        assertEquals(
            "http://127.0.0.1:58627/#token=$token",
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.KIMI,
                "\u001B[32mLocal:\u001B[0m http://127.0.0.1:58627/#token=$token\n",
            ),
        )
        assertNull(
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.KIMI,
                "http://127.0.0.1:58627/",
            ),
        )
        assertNull(
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.KIMI,
                "http://example.com:58627/#token=$token",
            ),
        )
        assertNull(
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.KIMI,
                "MCP connected at http://127.0.0.1:58627/#token=$token",
            ),
        )
        assertEquals(
            "http://[::1]:58627/#token=$token",
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.KIMI,
                "Local: http://[::1]:58627/#token=$token",
            ),
        )
    }

    @Test
    fun `DeepSeek parser accepts current bare URL and future process token`() {
        val token = "dsh_process_token_1234567890abcdef"
        val authenticated = "http://localhost:3080/?token=$token"
        assertEquals(
            "http://127.0.0.1:3080",
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: http://127.0.0.1:3080\n",
            ),
        )
        assertEquals(
            "http://[::1]:3080/",
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: http://[::1]:3080/\n",
            ),
        )
        assertEquals(
            authenticated,
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: $authenticated\n",
            ),
        )
        assertNull(
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: http://127.0.0.1:3080/?debug=true\n",
            ),
        )
        assertNull(
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: http://127.0.0.1:3080/#token=$token\n",
            ),
        )
        assertNull(
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: http://192.168.1.2:3080/?token=$token\n",
            ),
        )
        assertEquals(
            authenticated,
            AgentWebTranscriptParser.findUrl(
                AgentWebUrlKind.DEEPSEEK_HARNESS,
                "dsh web: $authenticated\nMCP: http://127.0.0.1:9999\n",
            ),
        )
    }

    @Test
    fun `configuration parser uses the most recent complete fingerprint`() {
        val first = "a".repeat(64)
        val second = "b".repeat(64)
        assertEquals(
            second,
            AgentWebTranscriptParser.findConfigurationFingerprint(
                "__OMNIBOT_AGENT_WEB_CONFIG__:$first\n" +
                    "__OMNIBOT_AGENT_WEB_CONFIG__:$second\n",
            ),
        )
    }

    @Test
    fun `Kimi environment follows the documented in-memory model channel`() {
        val configuration = buildAgentWebLaunchConfiguration(
            service = AgentWebService.KIMI,
            provider = provider(
                baseUrl = "https://gateway.example.com/v1/chat/completions",
                customHeaders = mapOf("X-Route" to "mobile"),
            ),
            model = "glm-5",
            reasoningEffort = "max",
        )

        assertEquals("glm-5", configuration.environment["KIMI_MODEL_NAME"])
        assertEquals("secret", configuration.environment["KIMI_MODEL_API_KEY"])
        assertEquals(
            "https://gateway.example.com/v1",
            configuration.environment["KIMI_MODEL_BASE_URL"],
        )
        assertEquals("openai", configuration.environment["KIMI_MODEL_PROVIDER_TYPE"])
        assertEquals("max", configuration.environment["KIMI_MODEL_THINKING_EFFORT"])
        assertEquals(
            "image_in,thinking",
            configuration.environment["KIMI_MODEL_CAPABILITIES"],
        )
        assertEquals("X-Route: mobile", configuration.environment["KIMI_CODE_CUSTOM_HEADERS"])
    }

    @Test
    fun `Kimi does not advertise images on an explicitly text-only route`() {
        val configuration = buildAgentWebLaunchConfiguration(
            service = AgentWebService.KIMI,
            provider = provider(
                baseUrl = "https://api.deepseek.com",
                protocolType = "deepseek",
            ),
            model = "deepseek-v4-flash",
        )

        assertEquals("thinking", configuration.environment["KIMI_MODEL_CAPABILITIES"])
    }

    @Test
    fun `DeepSeek Web uses the current Cordis provider and default-model surfaces`() {
        val configuration = buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(
                baseUrl = "https://gateway.example.com/v1",
                customHeaders = mapOf("X-Route" to "mobile"),
            ),
            model = "glm-5",
            reasoningEffort = "high",
        )
        val patch = configuration.managedFiles.getValue(DEEPSEEK_HARNESS_WEB_PATCH_PATH)

        assertEquals("secret", configuration.environment["OMNIBOT_DSH_API_KEY"])
        assertEquals(DEEPSEEK_HARNESS_WEB_HOME, configuration.environment["DSH_HOME"])
        assertFalse(configuration.environment.containsKey("DSH_MODEL"))
        assertFalse(configuration.environment.containsKey("DSH_PROVIDER"))
        assertTrue(patch.contains("- id: llm-pi-ai"))
        assertTrue(patch.contains("- id: agent-default-model"))
        assertTrue(patch.contains("\"omnibot-dispatch\""))
        assertTrue(patch.contains("\"api\":\"openai-completions\""))
        assertTrue(patch.contains("\"model\":\"glm-5\""))
        assertTrue(patch.contains("\"input\":[\"text\",\"image\"]"))
        assertTrue(patch.contains("\"reasoningEfforts\""))
        assertTrue(patch.contains("\"off\":\"none\""))
        assertTrue(patch.contains("\"minimal\":\"minimal\""))
        assertTrue(patch.contains("\"X-Route\":\"mobile\""))
        assertTrue(patch.contains("\"reasoning\":\"high\""))
        assertFalse(patch.contains("secret"))
    }

    @Test
    fun `DSH ACP off is explicit on generic OpenAI routes and keeps native provider dialects`() {
        val gateway = buildDeepSeekProviderPatch(
            provider(baseUrl = "https://gateway.example.com/v1"),
            "gateway-reasoner", "off", acp = true,
        )
        assertTrue(gateway.contains("\"off\":\"none\""))
        assertTrue(gateway.contains("\"reasoning\":\"off\""))
        assertTrue(gateway.contains("- id: acp"))
        for (protocol in listOf("deepseek", "anthropic")) {
            val native = buildDeepSeekProviderPatch(
                provider(baseUrl = "https://api.$protocol.com", protocolType = protocol),
                "native-model", "off", acp = true,
            )
            assertTrue(native.contains("\"off\":null"))
            assertFalse(native.contains("\"off\":\"none\""))
        }
    }

    @Test
    fun `DeepSeek Web keeps an explicitly text-only model text-only`() {
        val configuration = buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(
                baseUrl = "https://api.deepseek.com",
                protocolType = "deepseek",
            ),
            model = "deepseek-v4-flash",
        )
        val patch = configuration.managedFiles.getValue(DEEPSEEK_HARNESS_WEB_PATCH_PATH)

        assertTrue(patch.contains("\"input\":[\"text\"]"))
        assertFalse(patch.contains("\"input\":[\"text\",\"image\"]"))
    }

    @Test
    fun `DeepSeek Web maps Responses and Anthropic wires explicitly`() {
        val responses = buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(wireApi = "responses"),
            model = "gpt-5",
        ).managedFiles.getValue(DEEPSEEK_HARNESS_WEB_PATCH_PATH)
        val anthropic = buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(protocolType = "anthropic"),
            model = "claude-sonnet",
        ).managedFiles.getValue(DEEPSEEK_HARNESS_WEB_PATCH_PATH)

        assertTrue(responses.contains("\"api\":\"openai-responses\""))
        assertTrue(anthropic.contains("\"api\":\"anthropic-messages\""))
    }

    @Test
    fun `DeepSeek Web normalizes OpenAI roots without rewriting Anthropic roots`() {
        val openAi = buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(baseUrl = "https://gateway.example.com"),
            model = "glm-5",
        ).managedFiles.getValue(DEEPSEEK_HARNESS_WEB_PATCH_PATH)
        val anthropic = buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(
                baseUrl = "https://gateway.example.com/anthropic",
                protocolType = "anthropic",
            ),
            model = "claude-sonnet",
        ).managedFiles.getValue(DEEPSEEK_HARNESS_WEB_PATCH_PATH)

        assertTrue(openAi.contains("\"baseURL\":\"https://gateway.example.com/v1\""))
        assertTrue(
            anthropic.contains(
                "\"baseURL\":\"https://gateway.example.com/anthropic\"",
            ),
        )
    }

    @Test
    fun `Kimi Responses uses official config instead of unsupported environment wire`() {
        val configuration = buildAgentWebLaunchConfiguration(
            service = AgentWebService.KIMI,
            provider = provider(wireApi = "responses"),
            model = "gpt-5",
            reasoningEffort = "high",
        )
        assertFalse(configuration.environment.containsKey("KIMI_MODEL_NAME"))
        val config = configuration.managedFiles.values.single()
        assertTrue(config.contains("type = \"openai_responses\""))
        assertTrue(config.contains("model = \"gpt-5\""))
        assertTrue(config.contains("effort = \"high\""))
    }

    @Test(expected = IllegalArgumentException::class)
    fun `Agent Web rejects Provider URL fragments`() {
        buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(baseUrl = "https://gateway.example.com/v1#"),
            model = "glm-5",
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `Agent Web rejects Provider URL query parameters`() {
        buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(baseUrl = "https://gateway.example.com/v1?api-version=1"),
            model = "glm-5",
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `Agent Web rejects control characters in model ids`() {
        buildAgentWebLaunchConfiguration(
            service = AgentWebService.DEEPSEEK_HARNESS,
            provider = provider(),
            model = "glm-5\nnext",
        )
    }

    @Test
    fun `operation payload never exposes browser credentials`() {
        val payload = AgentWebOperationResult(
            success = true,
            code = AgentWebResultCode.OPENED,
            service = AgentWebService.KIMI,
            running = true,
        ).toJson().toString()

        assertFalse(payload.contains("url", ignoreCase = true))
        assertFalse(payload.contains("token", ignoreCase = true))
        assertFalse(payload.contains("secret"))
    }

    @Test
    fun `OpenCode waits for matching startup credentials and rejects foreign addresses`() {
        val password = "p".repeat(43)
        val transcript = "server listening on http://127.0.0.1:4088\nserver password $password\n"
        assertEquals("http://127.0.0.1:4088", AgentWebTranscriptParser.findUrl(AgentWebUrlKind.OPENCODE, transcript))
        assertEquals(password, AgentWebTranscriptParser.findOpenCodeEndpoint(transcript)?.password)
        assertFalse(AgentWebTranscriptParser.findOpenCodeEndpoint(transcript).toString().contains(password))
        assertNull(AgentWebTranscriptParser.findUrl(AgentWebUrlKind.OPENCODE, transcript.substringBefore("server password")))
        assertNull(AgentWebTranscriptParser.findOpenCodeEndpoint(transcript.replace("127.0.0.1", "example.com")))
        assertNull(AgentWebTranscriptParser.findOpenCodeEndpoint(transcript.replace(":4088", ":4088/path")))
        assertNull(AgentWebTranscriptParser.findOpenCodeEndpoint(transcript.replace(":4088", ":4088?redirect=external")))
        // An old process's password must not authenticate a new process.
        assertNull(AgentWebTranscriptParser.findOpenCodeEndpoint(transcript +
            "__OMNIBOT_AGENT_WEB_CONFIG__:${"b".repeat(64)}\nserver listening on http://127.0.0.1:4089\n"))
    }

    @Test
    fun `OpenCode reuses its process but creates a new pairing link for every open`() = runBlocking {
        val gateway = FakeGateway()
        val configuration = FakeConfigurationProvider()
        val manager = AgentWebRuntimeManager(gateway, configuration, pollIntervalMs = 90_000L, wait = {})
        assertEquals(AgentWebResultCode.OPENED, manager.open(AgentWebService.OPENCODE).code)
        assertEquals(AgentWebResultCode.RUNNING, manager.status(AgentWebService.OPENCODE).code)
        assertEquals(1, gateway.pairCount) // Status checks do not create sign-in links.
        assertTrue(manager.open(AgentWebService.OPENCODE).reused)
        assertEquals(1, gateway.launchCount)
        assertEquals(2, gateway.openedUrls.toSet().size)
        assertTrue(gateway.openedUrls.all { it.contains("/auth/connect/") })
        configuration.provider = provider(apiKey = "new-key")
        assertEquals(AgentWebResultCode.OPENED, manager.open(AgentWebService.OPENCODE).code)
        assertEquals(2, gateway.launchCount)
        assertEquals(1, gateway.stopCount)
        assertEquals(AgentWebResultCode.STOPPED, manager.stop(AgentWebService.OPENCODE).code)
        assertEquals(AgentWebResultCode.NOT_RUNNING, manager.status(AgentWebService.OPENCODE).code)
    }

    @Test
    fun `failed OpenCode pairing preserves the running process and exposes no credentials`() = runBlocking {
        val gateway = FakeGateway().apply { pairingSucceeds = false }
        val manager = AgentWebRuntimeManager(gateway, FakeConfigurationProvider(), pollIntervalMs = 90_000L, wait = {})
        val result = manager.open(AgentWebService.OPENCODE)
        assertEquals(AgentWebResultCode.PAIRING_FAILED, result.code)
        assertTrue(result.running)
        assertTrue(gateway.openedUrls.isEmpty())
        assertEquals(0, gateway.stopCount)
        assertFalse(result.toJson().toString().contains("secret"))
        assertFalse(result.toJson().toString().contains("password"))
    }

    @Test
    fun `OpenCode Web reuses the ACP config owner for every Provider wire`() = runBlocking {
        for ((protocol, wire) in listOf("openai_compatible" to "chat_completions",
            "openai_compatible" to "responses", "anthropic" to "chat_completions")) {
            val configuration = FakeConfigurationProvider().apply {
                provider = provider(baseUrl = "https://fixture.invalid/v1", apiKey = "fixture-key",
                    protocolType = protocol, wireApi = wire, customHeaders = mapOf("X-Fixture" to "fixture-header"))
                model = "org/test-model"
            }
            val gateway = FakeGateway()
            val manager = AgentWebRuntimeManager(gateway, configuration, pollIntervalMs = 90_000L, wait = {})
            assertEquals(AgentWebResultCode.OPENED, manager.open(AgentWebService.OPENCODE).code)
            val launch = buildAgentWebLaunchConfiguration(AgentWebService.OPENCODE, configuration.provider, configuration.model!!)
            val content = launch.managedFiles.getValue(OPENCODE_WEB_CONFIG_PATH)
            val root = JsonParser.parseString(content).asJsonObject
            val provider = root.getAsJsonObject("providers").getAsJsonObject("omnibot")
            assertEquals("omnibot/org/test-model", root.get("model").asString)
            assertEquals(when {
                protocol == "anthropic" -> "@opencode/ai/providers/anthropic-compatible"
                wire == "responses" -> "@opencode/ai/providers/openai-compatible/responses"
                else -> "@opencode/ai/providers/openai-compatible"
            }, provider.get("package").asString)
            assertEquals(OPENCODE_WEB_CONFIG_PATH, launch.environment["OPENCODE_CONFIG"])
            assertEquals(setOf(OPENCODE_WEB_CONFIG_PATH), launch.managedFiles.keys)
            assertFalse(content.contains("fixture-key"))
            assertFalse(content.contains("fixture-header"))
            assertFalse(gateway.lastLaunchCommand.contains("fixture-key"))
            // Used by the real-CLI HTTP smoke test; no browser automation.
            File("build/reports/agent-web/opencode-$protocol-$wire.json").apply {
                parentFile.mkdirs()
                writeText(Gson().toJson(mapOf("protocol" to protocol, "wire" to wire,
                    "environment" to launch.environment, "files" to launch.managedFiles,
                    "command" to gateway.lastLaunchCommand)))
            }
        }
    }

    @Test
    fun `OpenCode Web forwards the cached Provider catalog and declared capabilities`() {
        val launch = buildAgentWebLaunchConfiguration(AgentWebService.OPENCODE, provider(), "model-a",
            providerModels = listOf(ProviderModelOption("model-a", reasoning = true,
                inputModalities = listOf("text", "image")), ProviderModelOption("model-b", toolCall = true)))
        val root = JsonParser.parseString(launch.managedFiles.getValue(OPENCODE_WEB_CONFIG_PATH)).asJsonObject
        val models = root.getAsJsonObject("providers").getAsJsonObject("omnibot").getAsJsonObject("models")
        assertEquals(setOf("model-a", "model-b"), models.keySet())
        val capabilities = models.getAsJsonObject("model-a").getAsJsonObject("capabilities")
        assertEquals(listOf("text", "image"), capabilities.getAsJsonArray("input").map { it.asString })
        assertTrue(capabilities.getAsJsonObject("reasoning").get("supported").asBoolean)
    }

    @Test
    fun `manager reuses matching process and restarts after Provider changes`() = runBlocking {
        val gateway = FakeGateway()
        val configuration = FakeConfigurationProvider()
        val manager = AgentWebRuntimeManager(
            gateway = gateway,
            configurationProvider = configuration,
            pollIntervalMs = 60_000L,
            wait = {},
        )

        val first = manager.open(AgentWebService.KIMI)
        val second = manager.open(AgentWebService.KIMI)
        configuration.provider = provider(apiKey = "rotated-secret")
        val third = manager.open(AgentWebService.KIMI)

        assertEquals(AgentWebResultCode.OPENED, first.code)
        assertFalse(first.reused)
        assertTrue(second.reused)
        assertFalse(third.reused)
        assertEquals(2, gateway.launchCount)
        assertEquals(1, gateway.stopCount)
        assertEquals(3, gateway.openedUrls.size)
        assertTrue(gateway.openedUrls.all { it.contains("#token=") })
    }

    @Test
    fun `manager stops a process that never publishes an authenticated URL`() = runBlocking {
        val gateway = FakeGateway(publishUrl = false)
        val manager = AgentWebRuntimeManager(
            gateway = gateway,
            configurationProvider = FakeConfigurationProvider(),
            pollIntervalMs = 60_000L,
            wait = {},
        )

        val result = manager.open(AgentWebService.KIMI)

        assertEquals(AgentWebResultCode.URL_TIMEOUT, result.code)
        assertFalse(result.success)
        assertFalse(result.running)
        assertEquals(1, gateway.stopCount)
        assertTrue(gateway.openedUrls.isEmpty())
    }

    @Test
    fun `manager never reuses stale config when the old process cannot stop`() = runBlocking {
        val gateway = FakeGateway()
        val configuration = FakeConfigurationProvider()
        val manager = AgentWebRuntimeManager(
            gateway = gateway,
            configurationProvider = configuration,
            pollIntervalMs = 60_000L,
            wait = {},
        )
        manager.open(AgentWebService.KIMI)
        configuration.provider = provider(apiKey = "rotated-secret")
        gateway.stopSucceeds = false

        val result = manager.open(AgentWebService.KIMI)

        assertEquals(AgentWebResultCode.STOP_FAILED, result.code)
        assertFalse(result.success)
        assertTrue(result.running)
        assertEquals(1, gateway.launchCount)
        assertEquals(1, gateway.openedUrls.size)
    }

    @Test
    fun `manager reports failed timeout cleanup without claiming the process stopped`() = runBlocking {
        val gateway = FakeGateway(publishUrl = false).apply { stopSucceeds = false }
        val manager = AgentWebRuntimeManager(
            gateway = gateway,
            configurationProvider = FakeConfigurationProvider(),
            pollIntervalMs = 60_000L,
            wait = {},
        )

        val result = manager.open(AgentWebService.KIMI)

        assertEquals(AgentWebResultCode.STOP_FAILED, result.code)
        assertFalse(result.success)
        assertTrue(result.running)
    }

    @Test
    fun `manager reports a missing runtime without launching`() = runBlocking {
        val gateway = FakeGateway(commandAvailable = false)
        val manager = AgentWebRuntimeManager(
            gateway = gateway,
            configurationProvider = FakeConfigurationProvider(),
        )

        val result = manager.open(AgentWebService.DEEPSEEK_HARNESS)

        assertEquals(AgentWebResultCode.RUNTIME_MISSING, result.code)
        assertEquals("deepseek_harness", result.toJson()["packageId"].toString().trim('"'))
        assertEquals(0, gateway.launchCount)
    }

    @Test
    fun `manager writes managed DSH config without putting credentials in the command`() =
        runBlocking {
            val gateway = FakeGateway()
            val manager = AgentWebRuntimeManager(
                gateway = gateway,
                configurationProvider = FakeConfigurationProvider(),
                pollIntervalMs = 60_000L,
                wait = {},
            )

            val result = manager.open(AgentWebService.DEEPSEEK_HARNESS)

            assertEquals(AgentWebResultCode.OPENED, result.code)
            assertTrue(gateway.lastLaunchCommand.contains("base64 -d"))
            assertTrue(gateway.lastLaunchCommand.contains(DEEPSEEK_HARNESS_WEB_PATCH_PATH))
            assertTrue(gateway.lastLaunchCommand.contains(AgentWebService.DEEPSEEK_HARNESS.command))
            assertFalse(gateway.lastLaunchCommand.contains("secret"))
            assertEquals("secret", gateway.lastLaunchEnvironment["OMNIBOT_DSH_API_KEY"])
        }

    private class FakeConfigurationProvider : AgentWebConfigurationProvider {
        var provider = provider()
        var model: String? = "glm-5"

        override fun providerCredentials(): AgentProviderCredentials? = provider

        override fun modelId(): String? = model
    }

    private class FakeGateway(
        private val publishUrl: Boolean = true,
        private val commandAvailable: Boolean = true,
    ) : AgentWebRuntimeGateway {
        var launchCount = 0
        var stopCount = 0
        var running = false
        var transcript = ""
        var stopSucceeds = true
        var lastLaunchCommand = ""
        var lastLaunchEnvironment = emptyMap<String, String>()
        var pairCount = 0
        var pairingSucceeds = true
        val openedUrls = mutableListOf<String>()

        override suspend fun isRuntimeAvailable(service: AgentWebService): Boolean = commandAvailable

        override suspend fun prepareBrowserUrl(service: AgentWebService, snapshot: AgentWebRuntimeSnapshot): String? {
            if (service == AgentWebService.OPENCODE) {
                if (!pairingSucceeds) error("secret pairing failure")
                pairCount++
                return "http://127.0.0.1:4088/auth/connect/${"c".repeat(22)}$pairCount"
            }
            return AgentWebTranscriptParser.findUrl(service.urlKind, snapshot.transcript)
        }

        override suspend fun snapshot(sessionId: String): AgentWebRuntimeSnapshot? =
            if (running || transcript.isNotEmpty()) {
                AgentWebRuntimeSnapshot(running = running, transcript = transcript)
            } else {
                null
            }

        override suspend fun launch(
            sessionId: String,
            command: String,
            environment: Map<String, String>,
        ): AgentWebRuntimeLaunch {
            launchCount += 1
            lastLaunchCommand = command
            lastLaunchEnvironment = environment
            running = true
            val marker = Regex("__OMNIBOT_AGENT_WEB_CONFIG__:[0-9a-f]{64}")
                .find(command)
                ?.value
                .orEmpty()
            transcript = buildString {
                appendLine(marker)
                if (publishUrl) {
                    appendLine(
                        if (sessionId.contains("kimi")) {
                            "Kimi server: http://127.0.0.1:58627/#token=${"k".repeat(32)}"
                        } else if (sessionId.contains("opencode")) {
                            "server listening on http://127.0.0.1:4088\nserver password ${"p".repeat(43)}"
                        } else {
                            "dsh web: http://127.0.0.1:3080/?token=${"d".repeat(32)}"
                        },
                    )
                }
            }
            return AgentWebRuntimeLaunch(started = true, alreadyRunning = false)
        }

        override suspend fun stop(sessionId: String): Boolean {
            if (!stopSucceeds) return false
            val existed = running
            if (existed) stopCount += 1
            running = false
            transcript = ""
            return existed
        }

        override suspend fun openBrowser(url: String): Boolean {
            openedUrls += url
            return true
        }
    }

    private companion object {
        fun provider(
            baseUrl: String = "https://gateway.example.com/v1",
            apiKey: String = "secret",
            wireApi: String = "chat_completions",
            customHeaders: Map<String, String> = emptyMap(),
            protocolType: String = "openai_compatible",
        ) = AgentProviderCredentials(
            baseUrl = baseUrl,
            apiKey = apiKey,
            wireApi = wireApi,
            customHeaders = customHeaders,
            protocolType = protocolType,
        )
    }
}
