package com.fenleng.platform.bootstrap

import com.fenleng.platform.application.port.EventPublisher
import com.fenleng.platform.application.port.PlatformClock
import com.fenleng.platform.application.port.SessionTokenStore
import com.fenleng.platform.application.port.UserDataRequestRepository
import com.fenleng.platform.application.usecase.ProcessUserDataRequests
import com.fenleng.platform.application.usecase.UserDataRequestBatchResult
import com.fenleng.platform.persistence.JdbcUserDataRequestProcessor
import org.slf4j.LoggerFactory
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler
import org.springframework.transaction.support.TransactionTemplate
import tools.jackson.databind.ObjectMapper
import java.time.Duration
import java.util.concurrent.atomic.AtomicBoolean

@ConfigurationProperties("fenleng.platform.identity.data-requests.processing")
class UserDataRequestProcessingProperties {
    var enabled: Boolean = false
    var productionDeletionApproved: Boolean = false
    var batchSize: Int = 20
    var baseBackoff: Duration = Duration.ofMinutes(5)
    var maxBackoff: Duration = Duration.ofHours(24)

    fun validate() {
        require(batchSize in 1..100) { "Data request batch size must be between 1 and 100" }
        require(!baseBackoff.isZero && !baseBackoff.isNegative)
        require(maxBackoff >= baseBackoff)
    }
}

@Configuration(proxyBeanMethods = false)
@EnableScheduling
@EnableConfigurationProperties(UserDataRequestProcessingProperties::class)
@ConditionalOnProperty(
    prefix = "fenleng.platform.identity.data-requests.processing",
    name = ["enabled"],
    havingValue = "true",
)
class UserDataRequestProcessingConfiguration {
    @Bean
    fun userDataRequestProcessingValidated(properties: UserDataRequestProcessingProperties) =
        properties.apply(UserDataRequestProcessingProperties::validate)

    @Bean
    fun userDataRequestProcessor(
        jdbc: JdbcTemplate,
        transactions: TransactionTemplate,
        sessions: SessionTokenStore,
        objectMapper: ObjectMapper,
        clock: PlatformClock,
        properties: UserDataRequestProcessingProperties,
        firebaseCleanup: org.springframework.beans.factory.ObjectProvider<com.fenleng.platform.application.port.FirebaseAccountCleanup>,
    ) = JdbcUserDataRequestProcessor(
        jdbc,
        transactions,
        sessions,
        objectMapper,
        clock,
        properties.productionDeletionApproved,
        firebaseCleanup.getIfAvailable { com.fenleng.platform.application.port.FirebaseAccountCleanup { _, _ ->
            com.fenleng.platform.application.port.FirebaseCleanupResult.NotManaged
        } },
    )

    @Bean
    fun processUserDataRequests(
        requests: UserDataRequestRepository,
        processor: com.fenleng.platform.application.port.UserDataRequestProcessor,
        events: EventPublisher,
        clock: PlatformClock,
        properties: UserDataRequestProcessingProperties,
    ) = ProcessUserDataRequests(
        requests,
        processor,
        events,
        clock,
        properties.baseBackoff,
        properties.maxBackoff,
    )

    @Bean("userDataRequestTaskScheduler")
    fun userDataRequestTaskScheduler() = ThreadPoolTaskScheduler().apply {
        poolSize = 1
        setThreadNamePrefix("fenleng-user-data-request-")
        setWaitForTasksToCompleteOnShutdown(false)
        setAwaitTerminationSeconds(5)
    }

    @Bean
    fun scheduledUserDataRequestProcessor(
        process: ProcessUserDataRequests,
        properties: UserDataRequestProcessingProperties,
        transactions: TransactionTemplate,
    ) = ScheduledUserDataRequestProcessor(process, properties.batchSize, transactions)
}

class ScheduledUserDataRequestProcessor(
    private val process: ProcessUserDataRequests,
    private val batchSize: Int,
    private val transactions: TransactionTemplate,
) {
    private val running = AtomicBoolean()

    @Scheduled(
        initialDelayString = "\${fenleng.platform.identity.data-requests.processing.initial-delay:10s}",
        fixedDelayString = "\${fenleng.platform.identity.data-requests.processing.poll-interval:30s}",
        scheduler = "userDataRequestTaskScheduler",
    )
    fun process() {
        if (!running.compareAndSet(false, true)) return
        try {
            val result = processBatch()
            if (result.claimed > 0) LOGGER.info(
                "user_data_request_cycle claimed={} completed={} blocked={} retryScheduled={} stale={}",
                result.claimed,
                result.completed,
                result.blocked,
                result.retryScheduled,
                result.stale,
            )
        } catch (failure: RuntimeException) {
            LOGGER.error("user_data_request_cycle_failed failureType={}", failure.javaClass.simpleName)
        } finally {
            running.set(false)
        }
    }

    private fun processBatch(): UserDataRequestBatchResult {
        var totals = UserDataRequestBatchResult(0, 0, 0, 0, 0)
        for (index in 0 until batchSize) {
            // Hold the SKIP LOCKED claim until processing, progress and outbox
            // commit together. A worker exit cannot strand IN_PROGRESS rows.
            val result = transactions.execute {
                process.execute(1).also { check(it.stale == 0) { "DATA_REQUEST_PROGRESS_CONFLICT" } }
            } ?: error("DATA_REQUEST_TRANSACTION_RESULT_MISSING")
            totals = UserDataRequestBatchResult(
                totals.claimed + result.claimed,
                totals.completed + result.completed,
                totals.blocked + result.blocked,
                totals.retryScheduled + result.retryScheduled,
                totals.stale + result.stale,
            )
            if (result.claimed == 0) break
        }
        return totals
    }

    private companion object {
        val LOGGER = LoggerFactory.getLogger(ScheduledUserDataRequestProcessor::class.java)
    }
}
