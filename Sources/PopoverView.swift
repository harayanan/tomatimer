import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: Settings
    var onQuit: () -> Void

    @State private var showSettings = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var tint: Color { Theme.color(for: engine.phase) }

    var body: some View {
        VStack(spacing: 16) {
            header
            ring
            intentionField
            controls
            todayRow
            if showSettings {
                Divider().opacity(0.5)
                settingsPanel
            }
        }
        .padding(18)
        .frame(width: 300)
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text("Tomatimer")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: engine.state == .idle ? 1 : engine.fractionRemaining)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: engine.fractionRemaining)
            VStack(spacing: 2) {
                Text(engine.timeString)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(engine.state == .paused ? Color.secondary : tint)
            }
        }
        .frame(width: 156, height: 156)
        .padding(.top, 2)
    }

    private var statusLabel: String {
        switch engine.state {
        case .paused: return "PAUSED"
        default: return engine.phase.title.uppercased()
        }
    }

    private var intentionField: some View {
        TextField("What are you working on?", text: $engine.intention)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
            .onSubmit {
                if engine.state != .running { engine.start() }
            }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            iconButton("arrow.counterclockwise", help: "Reset") { engine.reset() }
            Button(primaryTitle) { engine.toggle() }
                .buttonStyle(PillButtonStyle(tint: tint))
            iconButton("forward.end.fill", help: "Skip to next phase") { engine.skip() }
        }
    }

    private var primaryTitle: String {
        switch engine.state {
        case .running: return "Pause"
        case .paused: return "Resume"
        case .idle: return engine.phase == .focus ? "Start focus" : "Start break"
        }
    }

    private var todayRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, settings.longBreakEvery), id: \.self) { i in
                Circle()
                    .fill(i < engine.cyclePosition ? Theme.color(for: .focus) : Color.primary.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
            Text("\(engine.completedToday) today")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            Spacer()
            if engine.sessionActive && engine.state != .running {
                Button("End session") { engine.endSession() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsPanel: some View {
        VStack(spacing: 8) {
            stepperRow("Focus", value: $settings.focusMinutes, range: 5...120, step: 5, unit: "min")
            stepperRow("Short break", value: $settings.shortBreakMinutes, range: 1...30, step: 1, unit: "min")
            stepperRow("Long break", value: $settings.longBreakMinutes, range: 5...60, step: 5, unit: "min")
            stepperRow("Long break every", value: $settings.longBreakEvery, range: 2...8, step: 1, unit: "")
            stepperRow("Away after", value: $settings.awayMinutes, range: 1...15, step: 1, unit: "min")
            stepperRow("Remind every", value: $settings.reminderMinutes, range: 1...30, step: 1, unit: "min")

            Toggle("Sounds", isOn: $settings.soundOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 12))
            Toggle("Launch at login", isOn: Binding(
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
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.system(size: 12))

            HStack {
                Text("⌃⌥P  start / pause")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit", action: onQuit)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .transition(.opacity)
    }

    // MARK: Helpers

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12))
            Spacer()
            Text(unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}
