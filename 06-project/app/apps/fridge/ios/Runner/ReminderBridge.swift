import Flutter
import UIKit
import UserNotifications

/// No defaults, inventory, permission query, or SDK access before authorize().
final class ReminderBridge {
  private var channel: FlutterMethodChannel?
  private var store: ReminderStore?
  private var scheduler: ReminderScheduler?
  private var allowed = false
  private var requesting = false
  private var earlyTap: (day: String, id: String)?
  private let queue = ReminderQueue()

  func authorize(messenger: FlutterBinaryMessenger) {
    allowed = true
    if store == nil {
      let defaults = UserDefaults(suiteName: "com.fenlengtech.fridge.local-reminders.v1")!
      let storage = ReminderStore(defaults: defaults)
      store = storage
      scheduler = ReminderScheduler(store: storage, permitted: { [weak self] in self?.allowed == true })
    }
    if channel == nil {
      let created = FlutterMethodChannel(name: "fenleng.fridge/notifications", binaryMessenger: messenger)
      created.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(Self.error("NOTIFICATIONS_UNAVAILABLE")); return }
        self.queue.add { done in
          guard self.allowed else { result(Self.error("CONSENT_REQUIRED")); done(); return }
          self.handle(call) { value in result(value); done() }
        }
      }
      channel = created
    }
    if let tap = earlyTap { earlyTap = nil; receive(day: tap.day, id: tap.id) }
  }

  func revoke(completion: @escaping (Error?) -> Void) {
    allowed = false; earlyTap = nil
    queue.add { done in
      guard let store = self.store, let scheduler = self.scheduler else { completion(nil); done(); return }
      var failure: Error?
      do { try store.write(false, key: "enabled"); try store.write(nil, key: "pendingDay") }
      catch { failure = error }
      scheduler.cancelAll { error in completion(error ?? failure); done() }
    }
  }

  func receive(day: String, id: String) {
    guard id.hasPrefix(ReminderDelivery.prefix), ReminderCycle.validDay(day) else { return }
    guard allowed else { earlyTap = (day, id); return }
    queue.add { done in
      defer { done() }
      guard self.allowed, let store = self.store else { return }
      do {
        try store.tap(day: day, id: id)
        self.channel?.invokeMethod("openReminder", arguments: ["day": day])
      } catch { /* Do not send a hint when the durable queue write failed. */ }
    }
  }

  static func day(_ notification: UNNotification) -> String? {
    guard notification.request.identifier.hasPrefix(ReminderDelivery.prefix),
      let day = notification.request.content.userInfo["fridgeReminderDay"] as? String,
      ReminderCycle.validDay(day) else { return nil }
    return day
  }

  func foreground(_ notification: UNNotification, completion: @escaping (UNNotificationPresentationOptions) -> Void) {
    guard allowed, store?.enabled == true else { completion([]); return }
    // UN already consumed this request; do not convert foreground receipt into a tap.
    queue.add { done in
      defer { done() }
      guard self.allowed, let store = self.store else { completion([]); return }
      do {
        if let delivery = store.deliveries.first(where: { $0.id == notification.request.identifier }) {
          try store.remember(delivery.keys)
        }
        if #available(iOS 14.0, *) { completion([.banner, .list, .sound]) }
        else { completion([.alert, .sound]) }
      } catch { completion([]) }
    }
  }

  private func status(_ completion: @escaping ([String: Any]) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let permission = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let authorized = permission && settings.alertSetting == .enabled
        completion(["enabled": self.store?.enabled == true,
          "authorized": authorized, "requested": self.store?.requested == true,
          "limited": self.store?.limited == true])
      }
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let store = store, let scheduler = scheduler else { result(Self.error("NOTIFICATIONS_UNAVAILABLE")); return }
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status": status { result($0) }
    case "consumeTap":
      do { result(try store.consumeTap()) } catch { result(Self.error("NOTIFICATION_WRITE_FAILED")) }
    case "request": request(result)
    case "settings":
      let setting: String
      if #available(iOS 15.4, *) { setting = UIApplication.openNotificationSettingsURLString }
      else { setting = UIApplication.openSettingsURLString }
      guard let url = URL(string: setting) else { result(false); return }
      UIApplication.shared.open(url, options: [:]) { result($0) }
    case "enable":
      guard let enabled = args["enabled"] as? Bool else { result(Self.error("NOTIFICATION_PLAN_INVALID")); return }
      status { value in
        guard self.allowed else { result(Self.error("CONSENT_REQUIRED")); return }
        guard !enabled || value["authorized"] as? Bool == true else { result(Self.error("NOTIFICATION_PERMISSION_REQUIRED")); return }
        do {
          try store.write(enabled, key: "enabled")
          if enabled { self.status { result($0) } }
          else { scheduler.cancelAll { error in
            if error != nil { result(Self.error("NOTIFICATION_WRITE_FAILED")) }
            else { self.status { result($0) } }
          } }
        } catch { result(Self.error("NOTIFICATION_WRITE_FAILED")) }
      }
    case "sync":
      do {
        let data = try JSONSerialization.data(withJSONObject: args)
        let plan = try JSONDecoder().decode(Plan.self, from: data)
        try plan.copy.validate()
        for cycle in plan.cycles { _ = try cycle.at(calendar: .current) }
        guard Set(plan.cycles.map { $0.key }).count == plan.cycles.count else { throw ReminderFailure.invalid }
        status { value in
          guard self.allowed else { result(Self.error("CONSENT_REQUIRED")); return }
          scheduler.reconcile(cycles: plan.cycles, copy: plan.copy,
            authorized: value["authorized"] as? Bool == true) { error in
            if error == nil { result(true) }
            else { result(Self.error("NOTIFICATION_SCHEDULE_FAILED")) }
          }
        }
      } catch { result(Self.error("NOTIFICATION_PLAN_INVALID")) }
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func request(_ result: @escaping FlutterResult) {
    guard !requesting, let store = store else { result(Self.error("NOTIFICATION_REQUEST_BUSY")); return }
    do { try store.write(true, key: "requested") }
    catch { result(Self.error("NOTIFICATION_WRITE_FAILED")); return }
    requesting = true
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
      DispatchQueue.main.async {
        self.requesting = false
        guard self.allowed else { result(Self.error("CONSENT_REQUIRED")); return }
        if error != nil { result(Self.error("NOTIFICATION_REQUEST_FAILED")) }
        else { self.status { result($0) } }
      }
    }
  }
  private struct Plan: Decodable { let cycles: [ReminderCycle]; let copy: ReminderCopy }
  private static func error(_ code: String) -> FlutterError { FlutterError(code: code, message: nil, details: nil) }
}
