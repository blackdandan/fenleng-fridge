import Foundation
import CryptoKit

enum ReminderFailure: Error { case invalid, write, schedule, consent }

struct ReminderCycle: Codable, Equatable {
  let key: String
  let day: String
  let hour: Int
  let minute: Int
  let second: Int
  let millisecond: Int

  static func validDay(_ day: String) -> Bool {
    guard day.utf8.count == 10,
      day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else { return false }
    let p = day.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return false }
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
    guard let date = c.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return false }
    let v = c.dateComponents([.year, .month, .day], from: date)
    return v.year == p[0] && v.month == p[1] && v.day == p[2]
  }

  func at(calendar: Calendar) throws -> Date {
    guard !key.trimmingCharacters(in: .whitespaces).isEmpty, key.count <= 512,
      Self.validDay(day), (0...23).contains(hour), (0...59).contains(minute),
      (0...59).contains(second), (0...1000).contains(millisecond) else { throw ReminderFailure.invalid }
    let p = day.split(separator: "-").compactMap { Int($0) }
    var calendar = calendar; calendar = Self.gregorian(calendar)
    guard let midnight = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])),
      let clock = calendar.date(bySettingHour: hour, minute: minute, second: second, of: midnight,
        matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first, direction: .forward)
      else { throw ReminderFailure.invalid }
    return clock.addingTimeInterval(Double(millisecond) / 1000)
  }

  static func gregorian(_ calendar: Calendar) -> Calendar {
    var value = Calendar(identifier: .gregorian); value.timeZone = calendar.timeZone; return value
  }
}

struct ReminderCopy: Codable, Equatable {
  let title: String
  let body: String
  let channel: String
  let locale: String
  func validate() throws {
    guard !title.isEmpty, title.count <= 256, body.contains("{count}"), body.count <= 1024,
      !channel.isEmpty, channel.count <= 128, locale.count <= 32 else { throw ReminderFailure.invalid }
  }
  func message(_ count: Int) -> String {
    let format = NumberFormatter(); format.locale = Locale(identifier: locale); format.numberStyle = .decimal
    return body.replacingOccurrences(of: "{count}", with: format.string(from: NSNumber(value: count)) ?? String(count))
  }
}

struct ReminderDelivery: Codable, Equatable {
  static let prefix = "fridge.check."
  let id: String
  let day: String
  let fireAt: Date
  let keys: [String]
  let count: Int
  let copy: ReminderCopy
  let sound: Bool

  static func make(cycles: [ReminderCycle], seen: Set<String>, copy: ReminderCopy,
    now: Date, calendar: Calendar) throws -> [ReminderDelivery] {
    try copy.validate()
    guard Set(cycles.map { $0.key }).count == cycles.count else { throw ReminderFailure.invalid }
    let dated = try cycles.map { ($0, try $0.at(calendar: calendar)) }
    var groups: [String: [(ReminderCycle, Date)]] = [:]
    for (cycle, at) in dated where !seen.contains(cycle.key) {
      // Calendar triggers use whole seconds; always round up, never alert early.
      let seconds = Int(ceil(at.timeIntervalSince1970))
      groups[cycle.day + ":" + String(seconds), default: []].append((cycle, at))
    }
    return groups.values.map { group in
      let day = group[0].0.day
      let fireAt = Date(timeIntervalSince1970: ceil(group.map { $0.1.timeIntervalSince1970 }.max()!))
      let keys = group.map { $0.0.key }.sorted()
      let identity = day + ":" + String(Int(fireAt.timeIntervalSince1970)) + ":" + keys.joined(separator: "\n")
      let digest = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
      let earlier = dated.contains {
        $0.0.day == day && (ceil($0.1.timeIntervalSince1970) < fireAt.timeIntervalSince1970 || seen.contains($0.0.key))
      }
      let count = dated.filter { $0.0.day == day && $0.1 <= max(now, fireAt) }.count
      return ReminderDelivery(id: prefix + digest, day: day, fireAt: fireAt, keys: keys,
        count: count, copy: copy, sound: !earlier)
    }.sorted { $0.fireAt == $1.fireAt ? $0.id < $1.id : $0.fireAt < $1.fireAt }
  }
}
