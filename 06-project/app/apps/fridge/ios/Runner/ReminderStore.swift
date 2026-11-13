import Foundation

/// Accessed only on the main queue, after the bootstrap consent gate.
final class ReminderStore {
  private let defaults: UserDefaults
  init(defaults: UserDefaults) { self.defaults = defaults }
  var enabled: Bool { defaults.bool(forKey: "enabled") }
  var requested: Bool { defaults.bool(forKey: "requested") }
  var limited: Bool { defaults.integer(forKey: "deferredCount") > 0 }
  var seen: Set<String> { Set(defaults.stringArray(forKey: "seen") ?? []) }
  var healthy: Bool {
    if defaults.object(forKey: "seen") != nil && defaults.stringArray(forKey: "seen") == nil { return false }
    guard let data = defaults.data(forKey: "deliveries") else {
      return defaults.object(forKey: "deliveries") == nil
    }
    guard let values = try? JSONDecoder().decode([ReminderDelivery].self, from: data) else { return false }
    return Set(values.map { $0.id }).count == values.count
  }
  var deliveries: [ReminderDelivery] {
    guard let data = defaults.data(forKey: "deliveries") else { return [] }
    return (try? JSONDecoder().decode([ReminderDelivery].self, from: data)) ?? []
  }
  func write(_ value: Any?, key: String) throws {
    let previous = defaults.object(forKey: key)
    defaults.set(value, forKey: key)
    guard defaults.synchronize() else {
      defaults.set(previous, forKey: key); throw ReminderFailure.write
    }
  }
  func remember(_ keys: [String]) throws { try write(Array(seen.union(keys)).sorted(), key: "seen") }
  func save(_ deliveries: [ReminderDelivery]) throws {
    guard healthy else { throw ReminderFailure.write }
    try write(JSONEncoder().encode(deliveries), key: "deliveries")
  }
  func tap(day: String, id: String) throws {
    guard ReminderCycle.validDay(day) else { throw ReminderFailure.invalid }
    if let delivery = deliveries.first(where: { $0.id == id }) { try remember(delivery.keys) }
    try write(day, key: "pendingDay")
  }
  func consumeTap() throws -> String? {
    let day = defaults.string(forKey: "pendingDay")
    try write(nil, key: "pendingDay")
    return day.flatMap { ReminderCycle.validDay($0) ? $0 : nil }
  }
}

/// Callback operations stay serialized across UNUserNotificationCenter replies.
final class ReminderQueue {
  private var operations: [(@escaping () -> Void) -> Void] = []
  private var running = false
  func add(_ operation: @escaping (@escaping () -> Void) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    operations.append(operation); next()
  }
  private func next() {
    guard !running, !operations.isEmpty else { return }
    running = true
    let operation = operations.removeFirst()
    operation { [weak self] in
      DispatchQueue.main.async { self?.running = false; self?.next() }
    }
  }
}
