package cn.com.omnimind.baselib.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface TokenUsageRecordDao {

    @Insert
    suspend fun insert(record: TokenUsageRecord): Long

    @Query("SELECT * FROM token_usage_records WHERE createdAt >= :since ORDER BY createdAt ASC")
    suspend fun getRecordsSince(since: Long): List<TokenUsageRecord>

    @Query("""
        SELECT model, CAST((createdAt - :since) / 604800000 AS INTEGER) AS weekIndex,
            SUM(MAX(CASE WHEN reasoningTokens + textTokens > 0
                THEN reasoningTokens + textTokens ELSE completionTokens END, 0)) AS tokens,
            SUM(cachedTokens) AS cachedTokens
        FROM token_usage_records
        WHERE createdAt >= :since AND createdAt < :until
        GROUP BY model, weekIndex
    """)
    suspend fun getWeeklyBuckets(since: Long, until: Long): List<TokenUsageBucket>

    @Query("SELECT * FROM token_usage_records WHERE conversationId = :conversationId ORDER BY createdAt DESC")
    suspend fun getByConversationId(conversationId: Long): List<TokenUsageRecord>

    @Query("DELETE FROM token_usage_records WHERE id = :id")
    suspend fun deleteById(id: Long)
}
