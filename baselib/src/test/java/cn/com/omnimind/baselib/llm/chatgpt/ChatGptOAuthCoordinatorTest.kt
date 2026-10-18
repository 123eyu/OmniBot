package cn.com.omnimind.baselib.llm.chatgpt

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.Assert.*
import org.junit.Test

class ChatGptOAuthCoordinatorTest {
    @Test fun retainsIssuedClientBeforeSingleUseCodeExchangeFailure() = runBlocking {
        val store = FakeStore()
        val remote = FakeRemote().apply { exchangeHandler = { clientId ->
            assertEquals("issued", clientId)
            assertEquals("issued", store.read("profile")?.clientId)
            throw ChatGptOAuthException("invalid_grant", "expired code")
        } }
        val owner = coordinator(store, remote)
        val first = owner.beginLogin("profile", REDIRECT)
        owner.completeLogin(first.id, callback(first))
        assertEquals("failed", owner.loginStatus(first.id)["status"])
        val retry = owner.beginLogin("profile", REDIRECT).authUrl.toHttpUrl()
        assertEquals("issued", retry.queryParameter("client_id"))
        assertNull(retry.queryParameter("agent_name_hint"))
        assertFalse(owner.account("profile")["connected"] as Boolean)
    }

    @Test fun wrongStateNeverExchangesOrPersistsCredentials() = runBlocking {
        val store = FakeStore()
        val remote = FakeRemote()
        val owner = coordinator(store, remote)
        val attempt = owner.beginLogin("profile", REDIRECT)
        val error = runCatching { owner.completeLogin(attempt.id, callback(attempt) + ("state" to "wrong")) }.exceptionOrNull()
        assertEquals("invalid_state", (error as ChatGptOAuthException).code)
        assertEquals(0, remote.exchangeCalls)
        assertNull(store.read("profile"))
    }

    @Test fun reauthorizationCannotReplaceSelectedClientAndMustCheckSelectedSubject() = runBlocking {
        val existing = registration()
        val store = FakeStore(existing)
        val remote = FakeRemote().apply { identityHandler = { _, client, _, subject, _ ->
            assertEquals(existing.clientId, client)
            assertEquals(existing.subject, subject)
            throw ChatGptOAuthException("invalid_identity", "wrong identity")
        } }
        val owner = coordinator(store, remote)
        val mismatch = owner.beginLogin("profile", REDIRECT)
        owner.completeLogin(mismatch.id, callback(mismatch, "other-client"))
        assertEquals(0, remote.exchangeCalls)
        assertEquals(existing, store.read("profile"))
        val second = owner.beginLogin("profile", REDIRECT)
        owner.completeLogin(second.id, callback(second, "issued"))
        assertEquals("failed", owner.loginStatus(second.id)["status"])
        assertEquals(existing, store.read("profile"))
    }

    @Test fun validIdentityWithoutPlanPermissionIsRetainedButCannotInfer() = runBlocking {
        val store = FakeStore()
        val remote = FakeRemote().apply {
            exchangeHandler = { tokens().copy(refreshToken = null, scopes = setOf("openid")) }
        }
        val owner = coordinator(store, remote)
        val attempt = owner.beginLogin("profile", REDIRECT)
        owner.completeLogin(attempt.id, callback(attempt))
        assertEquals("completed", owner.loginStatus(attempt.id)["status"])
        assertEquals(true, owner.account("profile")["connected"])
        assertEquals(false, owner.account("profile")["planEnabled"])
        val error = runCatching { owner.accessToken("profile") }.exceptionOrNull() as ChatGptOAuthException
        assertEquals("plan_disabled", error.code)
        assertEquals(0, remote.refreshCalls)
    }

    @Test fun initialLoginWithoutOfflineAccessNeedsReauthorizationOnlyWhenRenewalIsRequired() = runBlocking {
        var clock = NOW
        val store = FakeStore()
        val remote = FakeRemote().apply { exchangeHandler = { tokens().copy(refreshToken = null) } }
        val owner = ChatGptOAuthCoordinator(store, remote) { clock }
        val attempt = owner.beginLogin("profile", REDIRECT)
        owner.completeLogin(attempt.id, callback(attempt))
        assertEquals("new-access", owner.accessToken("profile"))
        assertEquals(true, owner.account("profile")["connected"])
        clock = NOW + 3570 * 1000
        assertEquals("new-access", owner.accessToken("profile"))
        clock = NOW + 3600 * 1000
        val error = runCatching { owner.accessToken("profile") }.exceptionOrNull() as ChatGptOAuthException
        assertEquals("sign_in_required", error.code)
        assertEquals(true, owner.account("profile")["needsReauth"])
        assertEquals("issued", store.read("profile")?.clientId)
        assertEquals(0, remote.refreshCalls)
    }

    @Test fun concurrentRequestsRefreshOnlyOnceAndPersistRotationBeforeReturning() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val store = FakeStore(registration())
        val remote = FakeRemote().apply { refreshHandler = {
            assertEquals("old-refresh", it.refreshToken)
            entered.complete(Unit); release.await(); tokens()
        } }
        val owner = coordinator(store, remote)
        val first = async { owner.accessToken("profile") }
        entered.await()
        val second = async { owner.accessToken("profile") }
        release.complete(Unit)
        assertEquals("new-access", first.await())
        assertEquals("new-access", second.await())
        assertEquals(1, remote.refreshCalls)
        assertEquals("new-refresh", store.read("profile")?.refreshToken)
        assertEquals(OLD_REVISION, owner.account("profile")["revision"])
    }

    @Test fun logoutWhileRefreshIsInFlightCannotRestoreTokens() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val store = FakeStore(registration())
        val remote = FakeRemote().apply { refreshHandler = { entered.complete(Unit); release.await(); tokens() } }
        val owner = coordinator(store, remote)
        val request = async { runCatching { owner.accessToken("profile") } }
        entered.await()
        val logout = owner.logout("profile")
        assertEquals(false, logout["remoteRevocationConfirmed"])
        release.complete(Unit)
        assertTrue(request.await().isFailure)
        assertNull(store.read("profile")?.accessToken)
        assertNull(store.read("profile")?.refreshToken)
        assertEquals("issued", store.read("profile")?.clientId)
        assertEquals("subject", store.read("profile")?.subject)
        assertEquals(true, owner.account("profile")["needsReauth"])
    }

    @Test fun cancellingInferenceDuringRefreshStillPersistsRotatingToken() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val store = FakeStore(registration())
        val remote = FakeRemote().apply { refreshHandler = { entered.complete(Unit); release.await(); tokens() } }
        val owner = coordinator(store, remote)
        val request = async { owner.accessToken("profile") }
        entered.await()
        request.cancel()
        release.complete(Unit)
        request.join()
        assertTrue(request.isCancelled)
        assertEquals("new-refresh", store.read("profile")?.refreshToken)
        assertEquals("new-access", store.read("profile")?.accessToken)
    }

    @Test fun cancelOrRemoveWhileCodeExchangeIsInFlightCannotPublishCredentials() = runBlocking {
        for (remove in listOf(false, true)) {
            val entered = CompletableDeferred<Unit>()
            val release = CompletableDeferred<Unit>()
            val store = FakeStore()
            val remote = FakeRemote().apply { exchangeHandler = { entered.complete(Unit); release.await(); tokens() } }
            val owner = coordinator(store, remote)
            val attempt = owner.beginLogin("profile", REDIRECT)
            val exchange = async { owner.completeLogin(attempt.id, callback(attempt)) }
            entered.await()
            if (remove) owner.removeProfile("profile") else owner.cancelLogin(attempt.id)
            release.complete(Unit); exchange.await()
            assertEquals("cancelled", owner.loginStatus(attempt.id)["status"])
            assertEquals(false, owner.account("profile")["connected"])
            if (remove) assertNull(store.read("profile")) else assertEquals("issued", store.read("profile")?.clientId)
        }
    }

    @Test fun abandonedReauthorizationDoesNotLoseConcurrentRefreshRotation() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val store = FakeStore(registration())
        val remote = FakeRemote().apply { refreshHandler = { entered.complete(Unit); release.await(); tokens() } }
        val owner = coordinator(store, remote)
        val request = async { owner.accessToken("profile") }
        entered.await()
        val attempt = owner.beginLogin("profile", REDIRECT)
        owner.cancelLogin(attempt.id)
        release.complete(Unit)
        assertEquals("new-access", request.await())
        assertEquals("new-refresh", store.read("profile")?.refreshToken)
    }

    @Test fun temporaryRefreshFailureKeepsCredentialsButRevocationClearsOnlyTokens() = runBlocking {
        for (code in listOf("network_error", "invalid_grant")) {
            val original = registration()
            val store = FakeStore(original)
            val remote = FakeRemote().apply { refreshHandler = { throw ChatGptOAuthException(code, "safe error") } }
            val owner = coordinator(store, remote)
            assertTrue(runCatching { owner.accessToken("profile") }.isFailure)
            if (code == "network_error") assertEquals(original, store.read("profile")) else {
                assertNull(store.read("profile")?.accessToken)
                assertEquals("issued", store.read("profile")?.clientId)
                assertEquals("subject", store.read("profile")?.subject)
                assertTrue((owner.account("profile")["revision"] as Long) > OLD_REVISION)
            }
        }
    }

    @Test fun refreshPermissionsLossPersistsDisabledStateAndInvalidatesCatalogRevision() = runBlocking {
        val store = FakeStore(registration())
        val remote = FakeRemote().apply { refreshHandler = { tokens().copy(scopes = setOf("openid")) } }
        val owner = coordinator(store, remote)
        val result = runCatching { owner.accessToken("profile") }.exceptionOrNull() as ChatGptOAuthException
        assertEquals("plan_disabled", result.code)
        assertEquals("new-refresh", store.read("profile")?.refreshToken)
        assertEquals(false, owner.account("profile")["planEnabled"])
        assertTrue((owner.account("profile")["revision"] as Long) > OLD_REVISION)
    }

    @Test fun accountsStayIsolatedAndHealthyAccountDoesNotWaitOnAnotherRefresh() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val store = FakeStore(registration()).apply {
            write("other", registration().copy(clientId = "other-issued", accessToken = "other-access", expiresAtSeconds = NOW / 1000 + 3600))
        }
        val remote = FakeRemote().apply { refreshHandler = { entered.complete(Unit); release.await(); tokens() } }
        val owner = coordinator(store, remote)
        val request = async { owner.accessToken("profile") }
        entered.await()
        assertEquals("other-access", owner.accessToken("other"))
        release.complete(Unit); request.await()
        assertEquals("other-issued", store.read("other")?.clientId)
        assertEquals("other-access", store.read("other")?.accessToken)
    }

    @Test fun timeoutRejectsLateCodeWithoutErasingPreviouslyConnectedAccount() = runBlocking {
        var clock = NOW
        val original = registration()
        val store = FakeStore(original)
        val remote = FakeRemote()
        val owner = ChatGptOAuthCoordinator(store, remote) { clock }
        val attempt = owner.beginLogin("profile", REDIRECT)
        clock += ChatGptOAuthCoordinator.LOGIN_TIMEOUT_MILLIS
        assertEquals("failed", owner.loginStatus(attempt.id)["status"])
        assertTrue(runCatching { owner.completeLogin(attempt.id, callback(attempt)) }.isFailure)
        assertEquals(original, store.read("profile"))
        assertEquals(0, remote.exchangeCalls)
    }

    private fun coordinator(store: FakeStore, remote: FakeRemote) = ChatGptOAuthCoordinator(store, remote) { NOW }
    private fun callback(attempt: ChatGptOAuthCoordinator.Attempt, clientId: String = "issued") =
        mapOf("state" to attempt.state, "code" to "single-use-code", "client_id" to clientId)

    private class FakeStore(initial: ChatGptRegistration? = null) : ChatGptCredentialStore {
        private val values = mutableMapOf<String, ChatGptRegistration>()
        init { initial?.let { values["profile"] = it } }
        override fun hostId() = "urn:uuid:host"
        override fun read(profileId: String) = values[profileId]
        override fun write(profileId: String, registration: ChatGptRegistration) { values[profileId] = registration }
        override fun delete(profileId: String) { values.remove(profileId) }
    }

    private class FakeRemote : ChatGptOAuthRemote {
        var exchangeCalls = 0
        var refreshCalls = 0
        var exchangeHandler: suspend (String) -> ChatGptTokens = { tokens() }
        var refreshHandler: suspend (ChatGptRegistration) -> ChatGptTokens = { tokens() }
        var identityHandler: suspend (String, String, String?, String?, Boolean) -> ChatGptIdentity =
            { _, _, _, _, _ -> ChatGptIdentity("subject", "me@example.com") }
        override suspend fun exchange(clientId: String, code: String, verifier: String, redirectUri: String): ChatGptTokens {
            exchangeCalls++; return exchangeHandler(clientId)
        }
        override suspend fun refresh(registration: ChatGptRegistration): ChatGptTokens {
            refreshCalls++; return refreshHandler(registration)
        }
        override suspend fun identity(token: String, clientId: String, nonce: String?, subject: String?, requireNonce: Boolean) =
            identityHandler(token, clientId, nonce, subject, requireNonce)
        override suspend fun revoke(registration: ChatGptRegistration) = true
    }

    companion object {
        private const val REDIRECT = "http://127.0.0.1:54321/auth/callback"
        private const val NOW = 1_800_000_000_000L
        private const val OLD_REVISION = NOW - 1_000_000
        private val SCOPES = setOf("openid", "resource.invoke", "chatgpt.tokens.use.direct")
        private fun registration() = ChatGptRegistration(
            "issued", "subject", "me@example.com", "old-access", "old-refresh", "old-id", "old-nonce",
            NOW / 1000 + 20, 0, SCOPES, OLD_REVISION,
        )
        private fun tokens() = ChatGptTokens("new-access", "new-refresh", "new-id", 3600, 0, SCOPES)
    }
}
