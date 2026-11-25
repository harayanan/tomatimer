import Foundation
import CoreGraphics
import Combine

/// Detects two ways of drifting off:
/// 1. Away: no keyboard/mouse input (or the Mac slept) for `awayMinutes` during a focus block.
///    Fires `onReturn` with the away duration once input resumes.
/// 2. Drift: in an active session, no timer running for `reminderMinutes`.
///    Fires `onDrift` every `reminderMinutes` until a timer starts or the session ends.
@MainActor
final class AttentionMonitor: NSObject {
    private let engine: TimerEngine
    private let settings: Settings

    var onReturn: ((TimeInterval) -> Void)?
    var onDrift: (() -> Void)?
    var onDriftActiveChanged: ((Bool) -> Void)?

    private var awaySince: Date?
    private var lastTick = Date()
    private var driftTimer: Timer?
    private var driftActive = false
    private var cancellables = Set<AnyCancellable>()

    init(engine: TimerEngine, settings: Settings) {
        self.engine = engine
        self.settings = settings
        super.init()

        Publishers.CombineLatest(engine.$state, engine.$sessionActive)
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.evaluateDrift() }
            .store(in: &cancellables)
    }

    // MARK: Away detection (called every second while a timer runs)

    func tick() {
        let now = Date()
        let gap = now.timeIntervalSince(lastTick)
        lastTick = now

        guard engine.state == .running, engine.phase == .focus else {
            awaySince = nil
            return
        }

        let threshold = TimeInterval(settings.awayMinutes * 60)
        let idle = Self.secondsSinceLastInput()

        // A long gap between ticks means the Mac slept.
        if gap > threshold, awaySince == nil {
            awaySince = now.addingTimeInterval(-gap)
        }
        if idle >= threshold, awaySince == nil {
            awaySince = now.addingTimeInterval(-idle)
        }
        if let since = awaySince, idle < 3 {
            awaySince = nil
            let away = now.timeIntervalSince(since) - idle
            if away >= threshold { onReturn?(away) }
        }
    }

    static func secondsSinceLastInput() -> TimeInterval {
        // ~0 is kCGAnyInputEventType: any keyboard, mouse or trackpad event.
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    // MARK: Drift reminders

    /// Restart the reminder countdown (e.g. after "Remind me later").
    func snooze() {
        guard driftTimer != nil else { return }
        scheduleDrift()
    }

    private func evaluateDrift() {
        let shouldWatch = engine.sessionActive && engine.state != .running
        if shouldWatch {
            if driftTimer == nil { scheduleDrift() }
        } else {
            driftTimer?.invalidate()
            driftTimer = nil
            setDriftActive(false)
        }
        if engine.state == .running { lastTick = Date() }
    }

    private func scheduleDrift() {
        driftTimer?.invalidate()
        let interval = TimeInterval(max(1, settings.reminderMinutes) * 60)
        let t = Timer(timeInterval: interval, target: self, selector: #selector(driftFired), userInfo: nil, repeats: true)
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        driftTimer = t
    }

    @objc private func driftFired() {
        guard engine.sessionActive, engine.state != .running else { return }
        setDriftActive(true)
        onDrift?()
    }

    private func setDriftActive(_ on: Bool) {
        guard on != driftActive else { return }
        driftActive = on
        onDriftActiveChanged?(on)
    }
}
