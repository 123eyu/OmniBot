package cn.com.omnimind.baselib.privileged

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PrivilegedCommandExecutorTest {
    private fun request(command: String) = PrivilegedRequest(UUID.randomUUID().toString(), "shell.exec",
        mapOf("confirmed" to "true"), command = command)

    @Test fun cancellationBeforeDispatchCannotAdmitALateBinderRequest() {
        val runner = PrivilegedProcessRunner(startProcess = { error("A cancelled request must not start") })
        val executor = PrivilegedCommandExecutor(PrivilegedBackend.ADB, PrivilegedProvider.SHIZUKU, runner)
        val request = request("id")
        executor.cancel(request.requestId)
        assertEquals("cancelled", executor.execute(request).code)
    }

    @Test fun staleAuthorizationCannotStartEvenIfTheProviderIsAvailableAgain() {
        val runner = PrivilegedProcessRunner(admission = { true }, startProcess = { error("Stale authorization") })
        val result = runner.execute("request", listOf("id"), 1, requestAdmission = { false })
        assertEquals("privileged_access_changed", result.errorCode)
    }

    @Test fun blockedCommandsAndUnconfirmedWritesDoNotReachTheProcessRunner() {
        val executor = PrivilegedCommandExecutor(PrivilegedBackend.ROOT, PrivilegedProvider.ROOT,
            PrivilegedProcessRunner(startProcess = { error("Must not execute") }))
        assertEquals("blocked_by_policy", executor.execute(request("reboot")).code)
        assertEquals("confirmation_required", executor.execute(request("id").copy(arguments = emptyMap())).code)
    }

    @Test fun publicOutputLimitIsReportedEvenBelowTheDrainBufferLimit() {
        val executor = PrivilegedCommandExecutor(PrivilegedBackend.ROOT, PrivilegedProvider.ROOT,
            PrivilegedProcessRunner(startProcess = { args -> ProcessBuilder(listOf("/bin/sh") + args.drop(1)).start() }))
        try {
            val result = executor.execute(request("i=0; while [ \"\$i\" -lt 2000 ]; do printf 0123456789; i=\$((i+1)); done"))
            assertTrue(result.message, result.success)
            assertEquals(16000, result.stdout.length)
            assertEquals("true", result.data["truncated"])
        } finally { executor.shutdown() }
    }
}
