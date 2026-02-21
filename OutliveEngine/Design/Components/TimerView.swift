// TimerView.swift
// OutliveEngine
//
// Countdown timer with circular progress ring, play/pause/reset controls.

import SwiftUI

struct TimerView: View {

    let totalSeconds: Int
    let onComplete: () -> Void

    @State private var remainingSeconds: Int
    @State private var isRunning = false
    @State private var timer: Timer?

    init(totalSeconds: Int, onComplete: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.onComplete = onComplete
        self._remainingSeconds = State(initialValue: totalSeconds)
    }

    var body: some View {
        VStack(spacing: OutliveSpacing.lg) {
            timerRing
            controls
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(ringColor.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            // Time display
            VStack(spacing: OutliveSpacing.xxs) {
                Text(formattedTime)
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)

                Text(isRunning ? "Running" : (remainingSeconds < totalSeconds ? "Paused" : "Ready"))
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(width: 200, height: 200)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: OutliveSpacing.xl) {
            // Reset
            Button {
                reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.outliveTitle3)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(remainingSeconds == totalSeconds && !isRunning)
            .opacity(remainingSeconds == totalSeconds && !isRunning ? 0.3 : 1.0)

            // Play / Pause
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.outliveTitle2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(ringColor)
                    .clipShape(Circle())
            }
            .disabled(remainingSeconds == 0)

            // Spacer for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - State

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(remainingSeconds) / CGFloat(totalSeconds)
    }

    private var ringColor: Color {
        if progress > 0.5 {
            return .recoveryGreen
        } else if progress > 0.2 {
            return .recoveryYellow
        } else {
            return .recoveryRed
        }
    }

    private var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Actions

    private func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    private func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard remainingSeconds > 0 else {
                pause()
                onComplete()
                return
            }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                pause()
                onComplete()
            }
        }
    }

    private func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func reset() {
        pause()
        remainingSeconds = totalSeconds
    }
}

// MARK: - Preview

#Preview {
    TimerView(totalSeconds: 180) {
        // Timer complete
    }
    .padding()
}
