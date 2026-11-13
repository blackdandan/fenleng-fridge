import Foundation
import UserNotifications

protocol ReminderNotificationCenter {
  func pending(_ completion: @escaping ([UNNotificationRequest]) -> Void)
  func delivered(_ completion: @escaping (Set<String>) -> Void)
  func add(_ request: UNNotificationRequest, completion: @escaping (Error?) -> Void)
  func removePending(_ ids: [String])
  func removeDelivered(_ ids: [String])
}

final class SystemReminderCenter: ReminderNotificationCenter {
  private let center = UNUserNotificationCenter.current()
  func pending(_ completion: @escaping ([UNNotificationRequest]) -> Void) {
    center.getPendingNotificationRequests { values in DispatchQueue.main.async { completion(values) } }
  }
  func delivered(_ completion: @escaping (Set<String>) -> Void) {
    center.getDeliveredNotifications { values in
      DispatchQueue.main.async { completion(Set(values.map { $0.request.identifier })) }
    }
  }
  func add(_ request: UNNotificationRequest, completion: @escaping (Error?) -> Void) {
    center.add(request) { error in DispatchQueue.main.async { completion(error) } }
  }
  func removePending(_ ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }
  func removeDelivered(_ ids: [String]) { center.removeDeliveredNotifications(withIdentifiers: ids) }
}

final class ReminderScheduler {
  let store: ReminderStore
  let center: ReminderNotificationCenter
  let permitted: () -> Bool
  init(store: ReminderStore, center: ReminderNotificationCenter = SystemReminderCenter(),
    permitted: @escaping () -> Bool = { true }) {
    self.store = store; self.center = center; self.permitted = permitted
  }
  func reconcile(cycles: [ReminderCycle], copy: ReminderCopy, authorized: Bool,
    now: Date = Date(), calendar: Calendar = .current, completion: @escaping (Error?) -> Void) {
    center.pending { pending in
      self.center.delivered { delivered in
        do {
          guard self.store.healthy else { throw ReminderFailure.write }
          let pendingIDs = Set(pending.map { $0.identifier })
          let deliveredIDs = delivered
          // Missing, elapsed requests are consumed handoffs, not proof a person saw them.
          let consumed = self.store.deliveries.filter {
            deliveredIDs.contains($0.id) || ($0.fireAt <= now && !pendingIDs.contains($0.id))
          }.flatMap { $0.keys }
          try self.store.remember(consumed)
          guard self.permitted() && self.store.enabled && authorized else {
            self.cancel(pending: pending, delivered: delivered)
            try self.store.write(0, key: "deferredCount")
            try self.store.save([]); completion(nil); return
          }
          let all = try ReminderDelivery.make(cycles: cycles, seen: self.store.seen, copy: copy,
            now: now, calendar: calendar)
          // Conservative bounded window; do not rely on silent OS queue truncation.
          let foreign = pending.filter { !$0.identifier.hasPrefix(ReminderDelivery.prefix) }.count
          let selected = Array(all.prefix(max(0, 60 - foreign)))
          try self.store.write(all.count - selected.count, key: "deferredCount")
          let wanted = Set(selected.map { $0.id })
          let retained = self.store.deliveries.filter {
            deliveredIDs.contains($0.id) || (wanted.contains($0.id) && pendingIDs.contains($0.id))
          }
          try self.store.save(retained)
          self.center.removePending(pending.filter {
            $0.identifier.hasPrefix(ReminderDelivery.prefix) && !wanted.contains($0.identifier)
          }.map { $0.identifier })
          let activeKeys = Set(cycles.map { $0.key })
          self.center.removeDelivered(self.store.deliveries.filter {
            deliveredIDs.contains($0.id) && activeKeys.isDisjoint(with: $0.keys)
          }.map { $0.id })
          let previous = Dictionary(uniqueKeysWithValues: self.store.deliveries.map { ($0.id, $0) })
          // Preserve delivery evidence until all replacements have committed.
          let oldDelivered = self.store.deliveries.filter { deliveredIDs.contains($0.id) }
          self.submit(selected, index: 0, accepted: oldDelivered, previous: previous,
            pending: pendingIDs, now: now, calendar: calendar, completion: completion)
        } catch { completion(error) }
      }
    }
  }

  private func cancel(pending: [UNNotificationRequest], delivered: Set<String>) {
    center.removePending(pending.filter { $0.identifier.hasPrefix(ReminderDelivery.prefix) }.map { $0.identifier })
    center.removeDelivered(delivered.filter { $0.hasPrefix(ReminderDelivery.prefix) }.sorted())
  }

  func cancelAll(completion: @escaping (Error?) -> Void) {
    center.pending { pending in
      self.center.delivered { delivered in
        // Revocation cancels OS work even if writing the ledger fails.
        self.cancel(pending: pending, delivered: delivered)
        do {
          let pendingIDs = Set(pending.map { $0.identifier })
          guard self.store.healthy else { throw ReminderFailure.write }
          let consumed = self.store.deliveries.filter {
            delivered.contains($0.id) || ($0.fireAt <= Date() && !pendingIDs.contains($0.id))
          }.flatMap { $0.keys }
          try self.store.remember(consumed)
          try self.store.write(0, key: "deferredCount")
          try self.store.save([]); completion(nil)
        } catch { completion(error) }
      }
    }
  }

  private func submit(_ items: [ReminderDelivery], index: Int, accepted: [ReminderDelivery],
    previous: [String: ReminderDelivery], pending: Set<String>, now: Date, calendar: Calendar,
    completion: @escaping (Error?) -> Void) {
    guard index < items.count else {
      do { try store.save(accepted); completion(nil) } catch { completion(error) }; return
    }
    let delivery = items[index]
    guard permitted() else { completion(ReminderFailure.consent); return }
    let next: () -> Void = {
      self.submit(items, index: index + 1, accepted: accepted + [delivery], previous: previous,
        pending: pending, now: now, calendar: calendar, completion: completion)
    }
    if pending.contains(delivery.id), previous[delivery.id] == delivery { next(); return }
    let content = UNMutableNotificationContent()
    content.title = delivery.copy.title; content.body = delivery.copy.message(delivery.count)
    content.threadIdentifier = "fridge.check.day." + delivery.day
    content.userInfo = ["fridgeReminderDay": delivery.day]
    if delivery.sound { content.sound = .default }
    let trigger: UNNotificationTrigger?
    if delivery.fireAt <= now { trigger = nil }
    else {
      let c = ReminderCycle.gregorian(calendar)
      var components = c.dateComponents([.year, .month, .day, .hour, .minute, .second], from: delivery.fireAt)
      var floating = Calendar(identifier: .gregorian); floating.timeZone = .autoupdatingCurrent
      components.calendar = floating
      // Floating local wall time matches the inventory, including after timezone changes.
      components.timeZone = nil
      trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
    center.add(UNNotificationRequest(identifier: delivery.id, content: content, trigger: trigger)) { error in
      guard error == nil else { completion(ReminderFailure.schedule); return }
      do {
        // Persist each real successful handoff; partial failure is recoverable on retry.
        var known = self.store.deliveries.filter { $0.id != delivery.id }; known.append(delivery)
        try self.store.save(known)
        next()
      } catch {
        self.center.removePending([delivery.id]); completion(error)
      }
    }
  }
}
