import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: Settings
    var onQuit: () -> Void

    @State private var showSettings: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init(engine: TimerEngine, settings: Settings, onQuit: @escaping () -> Void, showSettings: Bool = false) {
        _engine = ObservedObject(wrappedValue: engine)
        _settings = ObservedObject(wrappedValue: settings)
        self.onQuit = onQuit
        _showSettings = State(initialValue: showSettings)
    }

    private var tint: Color {
        engine.state == .paused ? Color.secondary : Theme.color(for: engine.phase)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 14)
            DialView(engine: engine, tint: tint)
                .frame(width: 196, height: 196)
                .padding(.bottom, 18)
            intentionField
                .padding(.bottom, 16)
            controls
                .padding(.bottom, 16)
            footer
            if showSettings {
                settingsPanel
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: 300)
        .animation(.easeInOut(duration: 0.25), value: engine.phase)
        .animation(.easeInOut(duration: 0.2), value: engine.state)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(phaseChipText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.12)))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(showSettings ? "Close settings" : "Settings")
        }
    }

    private var phaseChipText: String {
        switch engine.phase {
        case .focus:
            let n = min(engine.cyclePosition + 1, max(1, settings.longBreakEvery))
            return "FOCUS · \(n) OF \(settings.longBreakEvery)"
        case .shortBreak: return "SHORT BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }

    // MARK: Intention

    private var intentionField: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.color(for: .focus).opacity(0.9))
            TextField("What are you working on?", text: $engine.intention)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit {
                    if engine.state != .running { engine.start() }
                }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 16) {
            Button { engine.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(CircleIconButtonStyle())
                .help("Reset this block")
            Button(primaryTitle) { engine.toggle() }
                .buttonStyle(PillButtonStyle(tint: engine.state == .paused ? Theme.color(for: engine.phase) : tint))
                .frame(minWidth: 128)
            Button { engine.skip() } label: { Image(systemName: "forward.end.fill") }
                .buttonStyle(CircleIconButtonStyle())
                .help("Skip to next phase")
        }
    }

    private var primaryTitle: String {
        switch engine.state {
        case .running: return "Pause"
        case .paused: return "Resume"
        case .idle: return engine.phase == .focus ? "Start focus" : "Start break"
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(1, settings.longBreakEvery), id: \.self) { i in
                SessionPip(state: pipState(i))
            }
            Text("\(engine.completedToday) today")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .padding(.leading, 6)
            Spacer()
            if engine.sessionActive && engine.state != .running {
                Button("End session") { engine.endSession() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            } else {
                Text("⌃⌥P")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .help("Start or pause from anywhere")
            }
        }
    }

    private func pipState(_ i: Int) -> SessionPip.Kind {
        if i < engine.cyclePosition { return .done }
        if i == engine.cyclePosition && engine.phase == .focus && engine.state != .idle { return .current }
        return .pending
    }

    // MARK: Settings

    private var settingsPanel: some View {
        VStack(spacing: 10) {
            SettingsGroup {
                stepperRow("Focus", value: $settings.focusMinutes, range: 5...120, step: 5, unit: "min")
                Divider().opacity(0.4)
                stepperRow("Short break", value: $settings.shortBreakMinutes, range: 1...30, step: 1, unit: "min")
                Divider().opacity(0.4)
                stepperRow("Long break", value: $settings.longBreakMinutes, range: 5...60, step: 5, unit: "min")
                Divider().opacity(0.4)
                stepperRow("Long break every", value: $settings.longBreakEvery, range: 2...8, step: 1, unit: "blocks")
            }
            SettingsGroup {
                stepperRow("Away after", value: $settings.awayMinutes, range: 1...15, step: 1, unit: "min")
                Divider().opacity(0.4)
                stepperRow("Remind every", value: $settings.reminderMinutes, range: 1...30, step: 1, unit: "min")
            }
            SettingsGroup {
                toggleRow("Sounds", isOn: $settings.soundOn)
                Divider().opacity(0.4)
                toggleRow("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            NSSound.beep()
                        }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
            }
            HStack {
                Text("Click the menu bar timer to pause · right-click for this panel")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Quit", action: onQuit)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, 2)
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12))
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: 24)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .frame(height: 24)
    }
}

// MARK: - Dial

/// Large countdown dial: minute ticks, a gradient arc for the time left (shrinks clockwise
/// back to 12 o'clock), and a knob at its leading edge. Click to pause or resume.
struct DialView: View {
    @ObservedObject var engine: TimerEngine
    var tint: Color
    @State private var hovering = false

    private let line: CGFloat = 13

    private var fraction: Double {
        engine.state == .idle ? 1 : engine.fractionRemaining
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - line / 2
            ZStack {
                // Track
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: line)

                // Minute ticks
                ForEach(0..<60, id: \.self) { i in
                    let major = i % 5 == 0
                    Capsule()
                        .fill(Color.primary.opacity(major ? 0.28 : 0.11))
                        .frame(width: major ? 2 : 1, height: major ? 7 : 4)
                        .offset(y: -(radius - line / 2 - (major ? 9 : 7.5)))
                        .rotationEffect(.degrees(Double(i) * 6))
                }

                // Remaining-time arc
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [tint.opacity(0.55), tint]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * max(fraction, 0.01))
                        ),
                        style: StrokeStyle(lineWidth: line, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(engine.state == .running ? 0.4 : 0), radius: 7)

                // Knob at the arc's leading edge
                if engine.state != .idle && fraction > 0.004 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: line - 4, height: line - 4)
                        .shadow(color: Color.black.opacity(0.25), radius: 1.5, y: 0.5)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(360 * fraction))
                }

                // Centre read-out
                VStack(spacing: 3) {
                    Text(engine.timeString)
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(engine.state == .paused ? Color.secondary : Color.primary)
                    centreCaption
                }
            }
            .frame(width: size, height: size)
            .animation(.linear(duration: 0.95), value: fraction)
        }
        .contentShape(Circle())
        .onHover { hovering = $0 }
        .onTapGesture { engine.toggle() }
        .help(engine.state == .running ? "Click to pause" : "Click to start")
    }

    @ViewBuilder
    private var centreCaption: some View {
        if hovering {
            Label(engine.state == .running ? "Pause" : (engine.state == .paused ? "Resume" : "Start"),
                  systemImage: engine.state == .running ? "pause.fill" : "play.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        } else {
            Text(captionText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.secondary)
        }
    }

    private var captionText: String {
        switch engine.state {
        case .running:
            guard let end = engine.endsAt else { return "" }
            return "until \(Self.clock.string(from: end))"
        case .paused:
            return "paused"
        case .idle:
            return engine.phase == .focus ? "ready to focus" : "break is ready"
        }
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Small pieces

private struct SessionPip: View {
    enum Kind { case done, current, pending }
    let state: Kind

    var body: some View {
        let red = Theme.color(for: .focus)
        ZStack {
            switch state {
            case .done:
                Circle().fill(red)
            case .current:
                Circle().strokeBorder(red, lineWidth: 1.5)
                Circle().fill(red).padding(2.5)
            case .pending:
                Circle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.2)
            }
        }
        .frame(width: 9, height: 9)
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) { content }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
    }
}
