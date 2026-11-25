import Foundation
import Combine

enum Phase: String {
    case focus, shortBreak, longBreak

    var isBreak: Bool { self != .focus }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long break"
        }
    }
}

enum RunState {
    case idle, running, paused
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var focusMinutes: Int { didSet { save(focusMinutes, "focusMinutes") } }
    @Published var shortBreakMinutes: Int { didSet { save(shortBreakMinutes, "shortBreakMinutes") } }
    @Published var longBreakMinutes: Int { didSet { save(longBreakMinutes, "longBreakMinutes") } }
    @Published var longBreakEvery: Int { didSet { save(longBreakEvery, "longBreakEvery") } }
    @Published var awayMinutes: Int { didSet { save(awayMinutes, "awayMinutes") } }
    @Published var reminderMinutes: Int { didSet { save(reminderMinutes, "reminderMinutes") } }
    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: "soundOn") } }

    init() {
        defaults.register(defaults: [
            "focusMinutes": 25,
            "shortBreakMinutes": 5,
            "longBreakMinutes": 15,
            "longBreakEvery": 4,
            "awayMinutes": 3,
            "reminderMinutes": 5,
            "soundOn": true,
        ])
        focusMinutes = defaults.integer(forKey: "focusMinutes")
        shortBreakMinutes = defaults.integer(forKey: "shortBreakMinutes")
        longBreakMinutes = defaults.integer(forKey: "longBreakMinutes")
        longBreakEvery = defaults.integer(forKey: "longBreakEvery")
        awayMinutes = defaults.integer(forKey: "awayMinutes")
        reminderMinutes = defaults.integer(forKey: "reminderMinutes")
        soundOn = defaults.bool(forKey: "soundOn")
    }

    func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(focusMinutes * 60)
        case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        }
    }

    private func save(_ value: Int, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
