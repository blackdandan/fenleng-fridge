package com.fenleng.platform.bootstrap

import com.fenleng.platform.application.port.*
import com.fenleng.platform.application.usecase.ProcessUserDataRequests
import com.fenleng.platform.domain.application.*
import com.fenleng.platform.domain.identity.*
import com.fenleng.platform.domain.shared.*
import com.fenleng.platform.persistence.*
import io.zonky.test.db.postgres.embedded.EmbeddedPostgres
import org.flywaydb.core.Flyway
import org.junit.jupiter.api.*
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.jdbc.datasource.DataSourceTransactionManager
import org.springframework.transaction.support.TransactionTemplate
import tools.jackson.databind.ObjectMapper
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.test.*
import kotlin.test.Test

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class UserDataRequestProcessingTransactionTest {
    private lateinit var postgres: EmbeddedPostgres
    private lateinit var jdbc: JdbcTemplate
    private lateinit var transactions: TransactionTemplate
    private val mapper = ObjectMapper()
    private val now = Instant.parse("2026-11-13T09:00:00Z")
    private val clock = PlatformClock { now }
    private val requests get() = JdbcUserDataRequestRepository(jdbc)
    private val events get() = JdbcOutboxEventPublisher(jdbc, mapper)

    @BeforeAll fun start() {
        postgres = EmbeddedPostgres.builder().setPort(0).start()
        val source = postgres.postgresDatabase
        jdbc = JdbcTemplate(source)
        transactions = TransactionTemplate(DataSourceTransactionManager(source))
    }
    @AfterAll fun stop() { postgres.close() }
    @BeforeEach fun schema() {
        jdbc.execute("DROP SCHEMA IF EXISTS platform CASCADE")
        Flyway.configure().dataSource(postgres.postgresDatabase).schemas("platform")
            .defaultSchema("platform").locations("classpath:db/migration").load().migrate()
        JdbcApplicationRepository(jdbc, mapper).save(Application(ApplicationId("cleanup-app"),
            "fenleng-fridge", "Fridge", ApplicationStatus.ACTIVE, MembershipProvisioning.EXPLICIT, 1, now, now))
    }
    private fun seed(id: String = "a") {
        val user = UnifiedUser(UserId("user-$id"), UserKind.HUMAN, UserStatus.ACTIVE,
            version = 1, createdAt = now.minusSeconds(20 * 86400), updatedAt = now)
        JdbcUserRepository(jdbc).save(user.requestDeletion(1, now.minusSeconds(8 * 86400), now.minusSeconds(1)))
        JdbcExternalIdentityRepository(jdbc).insert(ExternalIdentity("binding-$id", user.id,
            "FIREBASE", "cleanup-app:uid-$id", null, false, ExternalIdentityStatus.ACTIVE, now))
        requests.insert(UserDataRequest(DataRequestId("request-$id"), user.id,
            UserDataRequestType.DELETE, UserDataRequestStatus.PENDING, now, now, 1))
    }
    private fun processor(cleanup: FirebaseAccountCleanup = FirebaseAccountCleanup { _, _ -> FirebaseCleanupResult.Completed }) =
        JdbcUserDataRequestProcessor(jdbc, transactions, JdbcSessionTokenStore(jdbc, transactions), mapper, clock, true, cleanup)
    private fun scheduler(processor: UserDataRequestProcessor, publisher: EventPublisher = events,
        repository: UserDataRequestRepository = requests, batch: Int = 20) =
        ScheduledUserDataRequestProcessor(ProcessUserDataRequests(repository, processor, publisher, clock), batch, transactions)
    private fun request(id: String = "a") = requests.find(DataRequestId("request-$id"))!!
    private fun status(id: String = "a") = JdbcUserRepository(jdbc).findById(UserId("user-$id"))!!.status
    private fun outboxCount() = jdbc.queryForObject("SELECT count(*) FROM platform.outbox_events", Int::class.java)

    @Test fun `event failure rolls back claim anonymization and outbox then retries remote UID`() {
        seed(); val targets = mutableListOf<String>()
        val processor = processor(FirebaseAccountCleanup { _, uid -> targets.add(uid); FirebaseCleanupResult.Completed })
        var fail = true
        val publisher = EventPublisher { event ->
            events.publish(event)
            if (fail) error("SIMULATED_FAILURE_BEFORE_COMMIT")
        }
        val scheduler = scheduler(processor, publisher)
        scheduler.process()
        assertEquals(UserDataRequestStatus.PENDING, request().status)
        assertEquals(UserStatus.DELETION_PENDING, status())
        assertEquals(0, outboxCount())
        fail = false; scheduler.process()
        assertEquals(UserDataRequestStatus.COMPLETED, request().status)
        assertEquals(UserStatus.DELETED, status())
        assertEquals(listOf("uid-a", "uid-a"), targets)
        assertEquals(1, outboxCount())
    }

    @Test fun `worker termination after remote acknowledgement leaves request reclaimable`() {
        seed(); val processor = processor()
        val interrupted = scheduler(UserDataRequestProcessor { request ->
            processor.process(request)
            throw AssertionError("SIMULATED_WORKER_TERMINATION")
        })
        assertFailsWith<AssertionError> { interrupted.process() }
        assertEquals(UserDataRequestStatus.PENDING, request().status)
        assertEquals(UserStatus.DELETION_PENDING, status())
        scheduler(processor).process()
        assertEquals(UserDataRequestStatus.COMPLETED, request().status)
        assertEquals(UserStatus.DELETED, status())
    }

    @Test fun `in flight claim is skipped by another worker until completion commits`() {
        seed(); val entered = CountDownLatch(1); val release = CountDownLatch(1)
        val processor = processor(FirebaseAccountCleanup { _, _ ->
            entered.countDown(); check(release.await(10, TimeUnit.SECONDS)); FirebaseCleanupResult.Completed
        })
        val pool = Executors.newSingleThreadExecutor()
        try {
            val running = pool.submit { scheduler(processor).process() }
            assertTrue(entered.await(10, TimeUnit.SECONDS))
            val competing = transactions.execute { requests.claimReady(now, 1) }!!
            assertTrue(competing.isEmpty())
            release.countDown(); running.get(15, TimeUnit.SECONDS)
            assertEquals(UserDataRequestStatus.COMPLETED, request().status)
        } finally { release.countDown(); pool.shutdownNow() }
    }

    @Test fun `later failure does not roll back previous committed task`() {
        seed("a"); seed("b")
        val publisher = EventPublisher { event ->
            events.publish(event)
            if (event.aggregateId == "request-b") error("SIMULATED_SECOND_TASK_FAILURE")
        }
        scheduler(processor(), publisher).process()
        assertEquals(UserDataRequestStatus.COMPLETED, request("a").status)
        assertEquals(UserStatus.DELETED, status("a"))
        assertEquals(UserDataRequestStatus.PENDING, request("b").status)
        assertEquals(UserStatus.DELETION_PENDING, status("b"))
        assertEquals(1, outboxCount())
    }

    @Test fun `ordinary remote failure commits existing bounded backoff`() {
        seed(); var calls = 0
        val processor = processor(FirebaseAccountCleanup { _, _ -> calls++; FirebaseCleanupResult.RetryableFailure })
        val scheduler = scheduler(processor)
        scheduler.process(); scheduler.process()
        assertEquals(UserDataRequestStatus.FAILED, request().status)
        assertEquals(now.plusSeconds(300), request().nextAttemptAt)
        assertEquals(1, request().attemptCount)
        assertEquals(1, calls)
        assertEquals(UserStatus.DELETION_PENDING, status())
    }

    @Test fun `progress CAS conflict cannot commit deletion without completed request`() {
        seed()
        val repository = object : UserDataRequestRepository by requests {
            override fun update(request: UserDataRequest, expectedVersion: Long) = false
        }
        scheduler(processor(), repository = repository).process()
        assertEquals(UserDataRequestStatus.PENDING, request().status)
        assertEquals(UserStatus.DELETION_PENDING, status())
        assertEquals(0, outboxCount())
    }
}
