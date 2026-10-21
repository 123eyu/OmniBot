package cn.com.omnimind.bot.statistics

import android.app.Application
import android.content.Context
import android.content.ContextWrapper
import android.content.res.AssetManager
import cn.com.omnimind.baselib.database.*
import cn.com.omnimind.bot.agent.ChatConversationPreferences
import cn.com.omnimind.bot.agent.runtime.AcpAgentProfileStore
import cn.com.omnimind.bot.agent.runtime.NA_AGENT_ID
import cn.com.omnimind.bot.webchat.ConversationDomainService
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class, manifest = Config.NONE)
class UsageStatisticsDatabaseTest {
    @Test fun `Room queries retain usage semantics and lightweight conversation ownership`() = runBlocking {
        DatabaseHelper.init(RuntimeEnvironment.getApplication())
        val start = 100L
        val week = 604_800_000L
        suspend fun insert(at: Long, completion: Int, reasoning: Int = 0, text: Int = 0, cached: Int = 0) {
            DatabaseHelper.insertTokenUsageRecord(TokenUsageRecord(conversationId = 1, model = "p/model", createdAt = at,
                completionTokens = completion, reasoningTokens = reasoning, textTokens = text, cachedTokens = cached))
        }
        insert(start - 1, 999)
        insert(start, 900, reasoning = 100, text = 200, cached = 400)
        insert(start + 1, 600) // No detail: fall back to completion, not prompt.
        insert(start + 2, -50, cached = -2) // Negative calls must not cancel positive calls.
        insert(start + week, 70)
        insert(start + 2 * week, 999)
        val buckets = DatabaseHelper.getTokenUsageWeeklyBuckets(start, start + 2 * week).sortedBy { it.weekIndex }
        assertEquals(listOf(TokenUsageBucket("p/model", 0, 900, 398), TokenUsageBucket("p/model", 1, 70, 0)), buckets)

        val id = DatabaseHelper.insertConversation(Conversation(title = "Private title", contextSummary = "Private content", createdAt = 100))
        DatabaseHelper.insertConversation(Conversation(title = "Outside range", createdAt = 200))
        DatabaseHelper.upsertAgentSessionBinding(AgentSessionBinding(id, "session", "/workspace", 100, 100))
        assertEquals(listOf(ConversationActivityRow(id, "normal", 100, "session")), DatabaseHelper.getConversationActivityRows(100, 200))

        val assets = Mockito.mock(AssetManager::class.java)
        Mockito.`when`(assets.open(anyString())).thenAnswer { call ->
            File("src/main/assets", call.getArgument<String>(0)).inputStream()
        }
        val context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
            override fun getAssets(): AssetManager = assets
            override fun getApplicationContext(): Context = this
        }
        val domain = ConversationDomainService(context)
        assertEquals(1, domain.listConversationActivity(100, 200).size)
        ChatConversationPreferences(context).hide(id)
        assertTrue(domain.listConversationActivity(100, 200).isEmpty())
        val cloudId = DatabaseHelper.insertConversation(Conversation(title = "Cloud", mode = "agent", createdAt = 150))
        AcpAgentProfileStore(context).bindConversation(cloudId, NA_AGENT_ID)
        // An unknown/logged-out cloud owner stays on disk and out of statistics.
        assertTrue(domain.listConversationActivity(100, 200).isEmpty())
    }
}
