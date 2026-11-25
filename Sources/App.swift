import AppKit
import SwiftUI
import Combine

@main
enum TomatimerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot") {
            app.setActivationPolicy(.prohibited)
            Snapshot.run(outDir: i + 1 < args.count ? args[i + 1] : "snapshots")
            exit(0)
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: Settings!
    private var engine: TimerEngine!
    private var status: StatusItemController!
    private var monitor: AttentionMonitor!
    private var overlay: OverlayController!
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = Settings()
        engine = TimerEngine(settings: settings)
        overlay = OverlayController()
        status = StatusItemController(engine: engine, settings: settings) {
            NSApp.terminate(nil)
        }
        monitor = AttentionMonitor(engine: engine, settings: settings)

        engine.onTick = { [weak self] in self?.monitor.tick() }
        engine.onPhaseFinished = { [weak self] phase in self?.phaseFinished(phase) }
        monitor.onReturn = { [weak self] away in self?.showAwayCard(away) }
        monitor.onDrift = { [weak self] in self?.showDriftCard() }
        monitor.onDriftActiveChanged = { [weak self] on in self?.status.setAttention(on) }

        hotKey = HotKey(keyCode: HotKey.defaultKeyCode, modifiers: HotKey.defaultModifiers) { [weak self] in
            self?.engine.toggle()
        }

        // Starting a timer by any route clears stale prompts (the away card belongs to a running timer).
        engine.$state
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, state == .running, self.overlay.kind != .away else { return }
                self.overlay.dismiss()
            }
            .store(in: &cancellables)
    }

    // MARK: Prompts

    private func phaseFinished(_ finished: Phase) {
        status.closePopover()
        if finished == .focus {
            play("Glass")
            let next = engine.phase
            let minutes = Int(engine.currentDuration / 60)
            let count = engine.completedToday
            overlay.showFullscreen(Prompt(
                symbol: next == .longBreak ? "cup.and.saucer.fill" : "leaf.fill",
                tint: Theme.color(for: next),
                eyebrow: "Focus complete · \(count) today",
                title: next == .longBreak ? "Take a \(minutes)-minute long break" : "Take a \(minutes)-minute break",
                detail: "Stand up, drink water, look at something far away.",
                intention: nil,
                primary: PromptAction(title: "Start break") { [weak self] in self?.engine.start() },
                secondary: PromptAction(title: "Skip break") { [weak self] in
                    self?.engine.skip()
                    self?.engine.start()
                },
                tertiary: PromptAction(title: "Close") { [weak self] in self?.overlay.dismiss() }
            ), kind: .phaseEnd)
        } else {
            play("Hero")
            overlay.showFullscreen(Prompt(
                symbol: "target",
                tint: Theme.color(for: .focus),
                eyebrow: "Break over",
                title: "Back to work",
                detail: nil,
                intention: Binding(get: { [weak self] in self?.engine.intention ?? "" },
                                   set: { [weak self] in self?.engine.intention = $0 }),
                primary: PromptAction(title: "Start focus") { [weak self] in self?.engine.start() },
                secondary: PromptAction(title: "5 more minutes") { [weak self] in
                    self?.engine.startExtraBreak(minutes: 5)
                },
                tertiary: PromptAction(title: "Done for today") { [weak self] in
                    self?.engine.endSession()
                    self?.overlay.dismiss()
                }
            ), kind: .phaseEnd)
        }
    }

    private func showAwayCard(_ away: TimeInterval) {
        guard !overlay.isShowing else { return }
        let minutes = max(1, Int((away / 60).rounded()))
        let intention = engine.intention.trimmingCharacters(in: .whitespaces)
        play("Tink")
        overlay.showCard(Prompt(
            symbol: "arrow.uturn.backward.circle.fill",
            tint: Theme.color(for: .focus),
            eyebrow: "Welcome back",
            title: "Away \(minutes) min",
            detail: intention.isEmpty
                ? "Your focus timer kept running. \(engine.timeString) left."
                : "Resume: \(intention) · \(engine.timeString) left",
            intention: nil,
            primary: PromptAction(title: "Back to it") { [weak self] in self?.overlay.dismiss() },
            secondary: PromptAction(title: "Restart block") { [weak self] in
                self?.overlay.dismiss()
                self?.engine.restartPhase()
            },
            tertiary: PromptAction(title: "Pause timer") { [weak self] in
                self?.engine.pause()
                self?.overlay.dismiss()
            }
        ), kind: .away)
    }

    private func showDriftCard() {
        if overlay.isShowing && overlay.kind == .phaseEnd { return }
        let paused = engine.state == .paused
        let intention = engine.intention.trimmingCharacters(in: .whitespaces)
        play("Tink")
        overlay.showCard(Prompt(
            symbol: "bell.fill",
            tint: Color(nsColor: Theme.attention),
            eyebrow: paused ? "Timer paused" : "No timer running",
            title: paused ? "Resume your focus block?" : "Start the next focus block?",
            detail: intention.isEmpty ? nil : "Next: \(intention)",
            intention: nil,
            primary: PromptAction(title: paused ? "Resume" : "Start focus") { [weak self] in
                guard let self else { return }
                if self.engine.phase != .focus && self.engine.state == .idle { self.engine.skip() }
                self.engine.start()
            },
            secondary: PromptAction(title: "Remind me later") { [weak self] in
                self?.monitor.snooze()
                self?.overlay.dismiss()
            },
            tertiary: PromptAction(title: "Done for today") { [weak self] in
                self?.engine.endSession()
                self?.overlay.dismiss()
            }
        ), kind: .drift)
    }

    private func play(_ name: String) {
        guard settings.soundOn else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
