import Foundation
import UserNotifications
import XCTest
@testable import Runner

final class FakeReminderCenter: ReminderNotificationCenter {
  var requests: [UNNotificationRequest] = []
  var deliveredIDs: Set<String> = []
  var additions = 0
  var fail = false
  func pending(_ completion: @escaping ([UNNotificationRequest]) -> Void) { completion(requests) }
  func delivered(_ completion: @escaping (Set<String>) -> Void) { completion(deliveredIDs) }
  func add(_ request: UNNotificationRequest, completion: @escaping (Error?) -> Void) {
    additions += 1
    if fail { completion(ReminderFailure.schedule); return }
    requests.removeAll { $0.identifier == request.identifier }; requests.append(request); completion(nil)
  }
  func removePending(_ ids: [String]) { requests.removeAll { ids.contains($0.identifier) } }
  func removeDelivered(_ ids: [String]) { deliveredIDs.subtract(ids) }
}

final class RunnerTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!
  private var store: ReminderStore!
  private var center: FakeReminderCenter!
  private var scheduler: ReminderScheduler!
  private let labels = ReminderCopy(title: "Check", body: "{count} due", channel: "Checks", locale: "en")
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c
  }
  private func cycle(_ key: String, day: String = "2026-11-13", hour: Int = 10,
    millisecond: Int = 0) -> ReminderCycle {
    ReminderCycle(key: key, day: day, hour: hour, minute: 0, second: 0, millisecond: millisecond)
  }
  private func date(_ hour: Int, day: Int = 13) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
  }
  override func setUpWithError() throws {
    suite = "fridge.notification.tests." + UUID().uuidString
    defaults = UserDefaults(suiteName: suite)!
    store = ReminderStore(defaults: defaults); center = FakeReminderCenter()
    scheduler = ReminderScheduler(store: store, center: center)
    try store.write(true, key: "enabled")
  }
  override func tearDown() { defaults.removePersistentDomain(forName: suite) }

  func testSameTimeCoalescesButLaterBatchDoesNotAlertEarly() throws {
    let plan = try ReminderDelivery.make(cycles: [cycle("a"), cycle("b"), cycle("c", hour: 12)],
      seen: [], copy: labels, now: date(9), calendar: calendar)
    XCTAssertEqual(plan.count, 2); XCTAssertEqual(plan.map { $0.count }, [2, 3])
    XCTAssertEqual(plan.map { $0.keys.count }, [2, 1]); XCTAssertEqual(plan.map { $0.sound }, [true, false])
    XCTAssertEqual(plan.map { $0.fireAt }, [date(10), date(12)])
  }
  func testFractionalSecondRoundsUpAndIDSurvivesDueBoundary() throws {
    let c = cycle("a", millisecond: 999)
    let before = try ReminderDelivery.make(cycles: [c], seen: [], copy: labels, now: date(9), calendar: calendar)
    let after = try ReminderDelivery.make(cycles: [c], seen: [], copy: labels, now: date(11), calendar: calendar)
    XCTAssertEqual(before[0].fireAt, date(10).addingTimeInterval(1))
    XCTAssertEqual(before[0].id, after[0].id)
  }
  func testSeenCycleNotQueuedAgainButContributesCurrentPendingCount() throws {
    let plan = try ReminderDelivery.make(cycles: [cycle("a"), cycle("b", hour: 12)],
      seen: ["a"], copy: labels, now: date(11), calendar: calendar)
    XCTAssertEqual(plan.count, 1); XCTAssertEqual(plan[0].keys, ["b"])
    XCTAssertEqual(plan[0].count, 2); XCTAssertFalse(plan[0].sound)
  }
  func testRejectsInvalidDayClockAndDuplicateCycles() {
    XCTAssertFalse(ReminderCycle.validDay("2026-02-30"))
    XCTAssertFalse(ReminderCycle.validDay("٢٠٢٦-١١-١٣"))
    XCTAssertFalse(ReminderCycle.validDay("2026-11-13\n"))
    XCTAssertThrowsError(try cycle("a", hour: 24).at(calendar: calendar))
    XCTAssertThrowsError(try ReminderDelivery.make(cycles: [cycle("a"), cycle("a")],
      seen: [], copy: labels, now: date(9), calendar: calendar))
  }
  func testDSTGapPreservesMinutesAndUsesGregorianDate() throws {
    var c = calendar; c.timeZone = TimeZone(identifier: "America/New_York")!
    let value = ReminderCycle(key: "a", day: "2026-03-08", hour: 2, minute: 30, second: 0, millisecond: 0)
    let parts = c.dateComponents([.hour, .minute], from: try value.at(calendar: c))
    XCTAssertEqual(parts.hour, 3); XCTAssertEqual(parts.minute, 30)
  }
  private func reconcile(_ cycles: [ReminderCycle], now: Date, authorized: Bool = true) throws {
    var called = false; var error: Error?
    scheduler.reconcile(cycles: cycles, copy: labels, authorized: authorized, now: now, calendar: calendar) {
      called = true; error = $0
    }
    XCTAssertTrue(called)
    if let error = error { throw error }
  }
  func testUnchangedSynchronizationDoesNotResubmitPendingRequests() throws {
    try reconcile([cycle("a")], now: date(9))
    try reconcile([cycle("a")], now: date(9).addingTimeInterval(30))
    XCTAssertEqual(center.additions, 1)
    XCTAssertEqual(center.requests[0].content.threadIdentifier, "fridge.check.day.2026-11-13")
    XCTAssertEqual(center.requests[0].content.userInfo.count, 1)
    XCTAssertFalse(center.requests[0].trigger!.repeats)
  }
  func testConsumedRequestSurvivesFreshStoreAndDoesNotRepeat() throws {
    try reconcile([cycle("a")], now: date(9))
    center.requests = []
    store = ReminderStore(defaults: UserDefaults(suiteName: suite)!)
    scheduler = ReminderScheduler(store: store, center: center)
    try reconcile([cycle("a")], now: date(11))
    XCTAssertEqual(center.additions, 1); XCTAssertTrue(store.seen.contains("a"))
    XCTAssertTrue(store.deliveries.isEmpty)
  }
  func testCancelPreservesForeignRequestAndConsumedLedger() throws {
    let other = UNNotificationRequest(identifier: "other.feature", content: UNMutableNotificationContent(), trigger: nil)
    center.requests = [other]; try store.remember(["old"])
    try reconcile([cycle("a")], now: date(9))
    try store.write(false, key: "enabled"); try reconcile([cycle("a")], now: date(9))
    XCTAssertEqual(center.requests.map { $0.identifier }, ["other.feature"])
    XCTAssertTrue(store.seen.contains("old")); XCTAssertTrue(store.deliveries.isEmpty)
  }
  func testFailedAddIsNotSuccessfulOrSeenAndRetrySchedules() throws {
    center.fail = true
    XCTAssertThrowsError(try reconcile([cycle("a")], now: date(9)))
    XCTAssertTrue(store.deliveries.isEmpty); XCTAssertTrue(store.seen.isEmpty)
    center.fail = false
    try reconcile([cycle("a")], now: date(9)); XCTAssertEqual(store.deliveries.count, 1)
  }
  func testRollingWindowSelectsEarliestAndReportsDeferredWork() throws {
    let values = (0..<61).map { n -> ReminderCycle in
      let day = calendar.date(byAdding: .day, value: n, to: date(10))!
      let f = DateFormatter(); f.calendar = calendar; f.timeZone = calendar.timeZone
      f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
      return cycle(String(n), day: f.string(from: day))
    }
    try reconcile(values, now: date(9))
    XCTAssertEqual(center.requests.count, 60); XCTAssertTrue(store.limited)
    XCTAssertFalse(store.deliveries.flatMap { $0.keys }.contains("60"))
    center.requests.removeFirst(); try reconcile(values, now: date(11))
    XCTAssertEqual(center.requests.count, 60); XCTAssertFalse(store.limited)
    XCTAssertTrue(store.deliveries.flatMap { $0.keys }.contains("60"))
  }
  func testHandledCycleRemovesDeliveredCardWithoutChangingSeenHistory() throws {
    try reconcile([cycle("a")], now: date(9))
    center.deliveredIDs = [center.requests[0].identifier]; center.requests = []
    try reconcile([], now: date(11))
    XCTAssertTrue(center.deliveredIDs.isEmpty); XCTAssertTrue(store.seen.contains("a"))
  }
  func testTapIsDurableAndConsumedOnce() throws {
    try store.tap(day: "2026-11-13", id: "fridge.check.unknown")
    let restored = ReminderStore(defaults: UserDefaults(suiteName: suite)!)
    XCTAssertEqual(try restored.consumeTap(), "2026-11-13")
    XCTAssertNil(try restored.consumeTap())
  }
  func testCorruptManifestIsPreservedAndDoesNotScheduleAsEmptyState() {
    let damaged = Data("damaged-reminder-manifest".utf8)
    defaults.set(damaged, forKey: "deliveries")
    XCTAssertFalse(store.healthy)
    XCTAssertThrowsError(try reconcile([cycle("a")], now: date(9)))
    XCTAssertEqual(center.additions, 0)
    XCTAssertEqual(defaults.data(forKey: "deliveries"), damaged)
  }
}
