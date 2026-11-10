//
//  Calendar.swift — Sentra Notch
//  Today's events and reminders (EventKit), with a week strip to look at other days.
//  Copyright © 2026 Abhiram Upadrashta (Bubbles Aro). MIT License.
//

import EventKit
import SwiftUI

struct AgendaItem: Identifiable {
    let id: String
    let title: String
    let start: Date?
    let end: Date?
    let allDay: Bool
    let color: Color
    let isReminder: Bool
    var done: Bool
    let url: URL?
}

@MainActor
final class CalendarModel: ObservableObject {
    static let shared = CalendarModel()
    let store = EKEventStore()
    @Published var day = Calendar.current.startOfDay(for: Date())
    @Published var items: [AgendaItem] = []
    @Published var eventsAllowed = false
    @Published var remindersAllowed = false
    @Published var calendars: [EKCalendar] = []

    func start() {
        refreshAccess()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            Task { @MainActor in CalendarModel.shared.reload() }
        }
        reload()
    }

    func refreshAccess() {
        eventsAllowed = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        remindersAllowed = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        _ = try? await store.requestFullAccessToReminders()
        refreshAccess(); reload()
    }

    func select(_ d: Date) { day = Calendar.current.startOfDay(for: d); reload() }

    func reload() {
        refreshAccess()
        calendars = eventsAllowed ? store.calendars(for: .event) : []
        let hidden = Set(Prefs.string(Prefs.hiddenCalendars).split(separator: ",").map(String.init))
        var out: [AgendaItem] = []
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        if eventsAllowed {
            let cals = calendars.filter { !hidden.contains($0.calendarIdentifier) }
            if !cals.isEmpty {
                let pred = store.predicateForEvents(withStart: day, end: end, calendars: cals)
                for e in store.events(matching: pred) where !(Prefs.bool(Prefs.hideAllDay) && e.isAllDay) {
                    out.append(AgendaItem(id: e.eventIdentifier ?? UUID().uuidString, title: e.title ?? "Event", start: e.startDate, end: e.endDate,
                                          allDay: e.isAllDay, color: Color(cgColor: e.calendar.cgColor), isReminder: false, done: false,
                                          url: e.url ?? Self.meetingLink(e)))
                }
            }
        }
        items = out.sorted { ($0.allDay ? 0 : 1, $0.start ?? .distantPast) < ($1.allDay ? 0 : 1, $1.start ?? .distantPast) }
        guard remindersAllowed, Prefs.bool(Prefs.showReminders) else { return }
        let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        let theDay = day
        store.fetchReminders(matching: pred) { rs in
            let mapped: [AgendaItem] = (rs ?? []).compactMap { r in
                let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                if let due, due < theDay, !Calendar.current.isDateInToday(theDay) { return nil }
                return AgendaItem(id: r.calendarItemIdentifier, title: r.title ?? "Reminder", start: due, end: nil, allDay: due == nil,
                                  color: Color(cgColor: r.calendar.cgColor), isReminder: true, done: r.isCompleted, url: nil)
            }
            Task { @MainActor in
                let me = CalendarModel.shared
                guard me.day == theDay else { return }
                me.items = me.items.filter { !$0.isReminder } + mapped.filter { !(Prefs.bool(Prefs.hideDoneReminders) && $0.done) }
            }
        }
    }

    func complete(_ item: AgendaItem) {
        guard item.isReminder, let r = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        r.isCompleted = true
        try? store.save(r, commit: true)
        reload()
    }

    /// Finds a Zoom/Meet/Teams/Webex link in an event so it can be joined from the notch.
    static func meetingLink(_ e: EKEvent) -> URL? {
        let text = [e.location, e.notes].compactMap { $0 }.joined(separator: " ")
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "facetime.apple.com"]
        return det.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { $0.url }
            .first { u in hosts.contains { (u.host ?? "").contains($0) } }
    }
}
