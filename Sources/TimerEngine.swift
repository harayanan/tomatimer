import Foundation
import Combine

/// Pomodoro state machine. Ticks at 1 Hz only while a timer is running.
/// Remaining time is derived from an end date, so it stays correct across sleep.
@MainActor
final class TimerEngine: NSObject, ObservableObject {
    let settings: Settings

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var state: RunState = .idle
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var currentDuration: TimeInterval
    /// Focus blocks completed in the current cycle (resets after a long break).
    @Published private(set) var cyclePosition = 0
    @Published private(set) var completedToday = 0
    /// True from the first start until the user ends the session. Drives drift reminders.
    @Published private(set) var sessionActive = false
    @Published var intention: String {
        didSet { UserDefaults.standard.set(intention, forKey: "intention") }
    }

    /// Called when a phase runs to zero (not when skipped). Argument: the phase that finished.
    var onPhaseFinished: ((Phase) -> Void)?
    /// Called once per second while running.
    var onTick: (() -> Void)?

    private var endDate: Date?
    private var ticker: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings
        let focus = settings.duration(for: .focus)
        remaining = focus
        currentDuration = focus
        intention = UserDefaults.standard.string(forKey: "intention") ?? ""
        super.init()
        refreshDay()

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &cancellables)
    }

    // MARK: Derived values

    /// Fraction of the current phase still remaining, 1 → 0.
    var fractionRemaining: Double {
        guard currentDuration > 0 else { return 0 }
        return min(1, max(0, remaining / currentDuration))
    }

    var timeString: String { Self.format(remaining) }

    /// Wall-clock time the running phase ends.
    var endsAt: Date? { endDate }

    /// Snapshot/testing hook: put the engine into an arbitrary visible state.
    func debugSet(phase: Phase, state: RunState, fraction: Double, cycle: Int, today: Int) {
        stopTicking()
        self.phase = phase
        currentDuration = settings.duration(for: phase)
        remaining = currentDuration * fraction
        self.state = state
        cyclePosition = cycle
        completedToday = today
        sessionActive = state != .idle
        endDate = state == .running ? Date().addingTimeInterval(remaining) : nil
    }

    static func format(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Controls

    func start() {
        guard state != .running else { return }
        if state == .idle {
            remaining = currentDuration
        }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        sessionActive = true
        startTicking()
    }

    func pause() {
        guard state == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        endDate = nil
        state = .paused
        stopTicking()
    }

    func toggle() {
        state == .running ? pause() : start()
    }

    /// Reset the current phase to its full length without starting it.
    func reset() {
        stopTicking()
        endDate = nil
        state = .idle
        currentDuration = settings.duration(for: phase)
        remaining = currentDuration
    }

    /// Restart the current phase from full length and run it.
    func restartPhase() {
        reset()
        start()
    }

    /// Move to the next phase without counting the current one.
    func skip() {
        finishPhase(natural: false)
    }

    /// Start an extra short break of the given length (used by "5 more minutes").
    func startExtraBreak(minutes: Int) {
        stopTicking()
        phase = .shortBreak
        currentDuration = TimeInterval(minutes * 60)
        remaining = currentDuration
        state = .idle
        start()
    }

    /// Stop for the day: back to an idle focus block, no more reminders.
    func endSession() {
        stopTicking()
        endDate = nil
        phase = .focus
        cyclePosition = 0
        state = .idle
        currentDuration = settings.duration(for: .focus)
        remaining = currentDuration
        sessionActive = false
    }

    /// Re-read today's count (rolls over at midnight).
    func refreshDay() {
        let d = UserDefaults.standard
        completedToday = d.string(forKey: "countDay") == Self.today() ? d.integer(forKey: "countValue") : 0
    }

    // MARK: Internals

    private func startTicking() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 1, target: self, selector: #selector(tickFired), userInfo: nil, repeats: true)
        t.tolerance = 0.15
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    @objc private func tickFired() {
        guard state == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0.05 {
            finishPhase(natural: true)
        } else {
            onTick?()
        }
    }

    private func finishPhase(natural: Bool) {
        let finished = phase
        stopTicking()
        endDate = nil

        if finished == .focus {
            if natural {
                cyclePosition += 1
                recordCompletion()
            }
            phase = cyclePosition >= settings.longBreakEvery ? .longBreak : .shortBreak
        } else {
            if finished == .longBreak { cyclePosition = 0 }
            phase = .focus
        }

        state = .idle
        currentDuration = settings.duration(for: phase)
        remaining = currentDuration

        if natural { onPhaseFinished?(finished) }
    }

    private func recordCompletion() {
        refreshDay()
        completedToday += 1
        let d = UserDefaults.standard
        d.set(Self.today(), forKey: "countDay")
        d.set(completedToday, forKey: "countValue")
    }

    private func settingsChanged() {
        guard state == .idle else { return }
        currentDuration = settings.duration(for: phase)
        remaining = currentDuration
    }

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
