package cn.com.omnimind.bot.agent.runtime

import cn.com.omnimind.baselib.database.AgentSessionBinding
import cn.com.omnimind.bot.agent.AgentScheduleToolBridge
import com.agentclientprotocol.agent.AgentInfo
import com.agentclientprotocol.client.Client
import com.agentclientprotocol.client.ClientSession
import com.agentclientprotocol.common.SessionCreationParameters
import com.agentclientprotocol.model.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.mockito.Mockito.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.Continuation
import kotlin.coroutines.intrinsics.COROUTINE_SUSPENDED
import kotlin.coroutines.intrinsics.suspendCoroutineUninterceptedOrReturn

class LocalAcpDraftSessionTest {
    @get:Rule val folder = TemporaryFolder()

    @Test fun configuringAnUnsentSessionDoesNotCreateHistoryAndTheFirstPromptKeepsItsConfiguration() = runBlocking {
        val f = fixture()
        val session = f.session("draft")
        val options = MutableStateFlow(listOf<SessionConfigOption>(modelOption("one")))
        `when`(session.configOptionsSupported).thenReturn(true)
        `when`(session.configOptions).thenReturn(options)
        `when`(session.setConfigOption(SessionConfigId("model"), SessionConfigOptionValue.StringValue("two")))
            .thenAnswer { options.value = listOf(modelOption("two")); SetSessionConfigOptionResponse(options.value) }
        f.runtime.setField("catalogSessionId", "draft")
        try {
            val created = f.runtime.handleMethod("session/new", emptyMap()) as Map<*, *>
            assertEquals("draft", created["sessionId"])
            assertNull(created["conversationId"])
            f.runtime.handleMethod("session/set_config_option", mapOf(
                "sessionId" to "draft", "configId" to "model", "value" to "two",
            ))
            val loaded = f.runtime.handleMethod("session/load", mapOf("sessionId" to "draft")) as Map<*, *>
            assertNull(loaded["conversationId"])
            assertFalse(mockingDetails(f.repository).invocations.any { it.method.name == "ensureBinding" })

            `when`(f.repository.ensureBinding("draft", 42L, "/workspace", conversationMode = "agent"))
                .thenReturn(42L)
            val admitted = f.runtime.resolveForPrompt(mapOf("threadId" to "draft", "conversationId" to 42L))
            assertSame(session, admitted)
            assertEquals("two", (options.value.single() as SessionConfigOption.Select).currentValue.value)
            verify(f.repository).ensureBinding("draft", 42L, "/workspace", conversationMode = "agent")
            assertEquals(AcpAgentProfileStore.XIAOWAN_AGENT_ID, f.store.agentIdForConversation(42L))
        } finally { f.scope.cancel() }
    }

    @Test fun firstPromptCannotTakeASessionFromAnotherConversationOrAdoptAnUnknownSession() = runBlocking {
        val f = fixture()
        val old = f.session("old")
        val fresh = f.session("fresh")
        f.runtime.setField("catalogSessionId", "fresh")
        `when`(f.repository.getBindingByThreadId("old"))
            .thenReturn(AgentSessionBinding(41L, "old", "/workspace", 1L, 1L))
        `when`(f.repository.ensureBinding("fresh", 42L, "/workspace", conversationMode = "agent"))
            .thenReturn(42L)
        try {
            assertSame(fresh, f.runtime.resolveForPrompt(mapOf("threadId" to "old", "conversationId" to 42L)))
            assertSame(old, f.runtime.sessions()["old"])
            assertFalse(explicitThreadMatchesConversation("unknown", 42L, null))
            assertFalse(explicitThreadMatchesConversation("old", 42L, 41L, ownsUnboundSession = true))
        } finally { f.scope.cancel() }
    }

    @Test fun listingAfterRuntimeRecreationDoesNotImportUnsentSessionsButStillImportsExternalHistory() = runBlocking {
        val f = fixture()
        f.store.bindSession("draft", AcpAgentProfileStore.XIAOWAN_AGENT_ID)
        val info = mock(AgentInfo::class.java)
        `when`(info.capabilities).thenReturn(AgentCapabilities(sessionCapabilities = SessionCapabilities(list = SessionListCapabilities())))
        f.runtime.setField("agentInfo", info)
        val client = mock(Client::class.java)
        `when`(client.listSessions(null, emptyList())).thenReturn(flowOf(
            SessionInfo(SessionId("draft"), "/workspace", title = "Unsent"),
            SessionInfo(SessionId("external"), "/workspace", title = "Existing task"),
        ))
        f.runtime.setField("client", client)
        try {
            f.runtime.handleMethod("session/list", emptyMap())
            val createdFor = mockingDetails(f.repository).invocations
                .filter { it.method.name == "ensureBinding" }.map { it.arguments[0] }
            assertEquals(listOf("external"), createdFor)
        } finally { f.scope.cancel() }
    }

    private fun modelOption(value: String) = SessionConfigOption.Select(
        id = SessionConfigId("model"), name = "Model", category = SessionConfigOptionCategory.MODEL,
        currentValue = SessionConfigValueId(value),
        options = SessionConfigSelectOptions.Flat(listOf("one", "two").map {
            SessionConfigSelectOption(SessionConfigValueId(it), it)
        }),
    )

    private fun fixture(): Fixture {
        val context = acpProfileStoreTestContext(folder.root)
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)
        val repository = mock(AgentSessionBindingRepository::class.java)
        val store = AcpAgentProfileStore(context)
        val runtime = LocalAcpRuntime(context, scope, repository, store,
            prepareLaunchEnvironment = { _, _ -> PreparedAcpLaunch(emptyMap()) },
            buildHandoffContext = { _, _ -> null },
            scheduleToolBridge = mock(AgentScheduleToolBridge::class.java), onMessage = {})
        val info = mock(AgentInfo::class.java)
        `when`(info.capabilities).thenReturn(AgentCapabilities())
        runtime.setField("agentInfo", info)
        return Fixture(runtime, repository, store, scope)
    }

    private inner class Fixture(
        val runtime: LocalAcpRuntime,
        val repository: AgentSessionBindingRepository,
        val store: AcpAgentProfileStore,
        val scope: CoroutineScope,
    ) {
        fun session(id: String): ClientSession = mock(ClientSession::class.java).also {
            `when`(it.sessionId).thenReturn(SessionId(id))
            `when`(it.parameters).thenReturn(SessionCreationParameters("/workspace", emptyList()))
            runtime.sessions()[id] = it
            @Suppress("UNCHECKED_CAST")
            val cwds = runtime.javaClass.getDeclaredField("sessionCwds").run {
                isAccessible = true; get(runtime) as ConcurrentHashMap<String, String>
            }
            cwds[id] = "/workspace"
        }
    }

    private fun LocalAcpRuntime.setField(name: String, value: Any) =
        javaClass.getDeclaredField(name).apply { isAccessible = true }.set(this, value)

    @Suppress("UNCHECKED_CAST")
    private fun LocalAcpRuntime.sessions() = javaClass.getDeclaredField("sessions").run {
        isAccessible = true; get(this@sessions) as ConcurrentHashMap<String, ClientSession>
    }

    private suspend fun LocalAcpRuntime.resolveForPrompt(args: Map<String, Any?>): ClientSession =
        suspendCoroutineUninterceptedOrReturn { continuation ->
            javaClass.getDeclaredMethod("ensureSessionForTurn", Map::class.java, Continuation::class.java)
                .apply { isAccessible = true }.invoke(this, args, continuation).let {
                    if (it === COROUTINE_SUSPENDED) it else it as ClientSession
                }
        }
}
