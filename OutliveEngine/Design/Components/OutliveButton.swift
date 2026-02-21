// OutliveButton.swift
// OutliveEngine
//
// Configurable button with primary, secondary, and destructive styles.

import SwiftUI

// MARK: - Style Enum

enum OutliveButtonStyle: Sendable {
    case primary
    case secondary
    case destructive
}

// MARK: - Button View

struct OutliveButton: View {

    let title: String
    let style: OutliveButtonStyle
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            action()
        }) {
            label
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(backgroundFill)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
                .overlay {
                    if style == .secondary {
                        RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous)
                            .strokeBorder(Color.domainTraining, lineWidth: 1.5)
                    }
                }
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var label: some View {
        if isLoading {
            ProgressView()
                .tint(progressTint)
        } else {
            Text(title)
                .font(.outliveHeadline)
                .foregroundStyle(foregroundColor)
        }
    }

    // MARK: - Style Resolution

    private var backgroundFill: Color {
        switch style {
        case .primary:     return .domainTraining
        case .secondary:   return .clear
        case .destructive: return .recoveryRed
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .domainTraining
        case .destructive: return .white
        }
    }

    private var progressTint: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .domainTraining
        case .destructive: return .white
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: OutliveSpacing.md) {
        OutliveButton(title: "Start Protocol", style: .primary) { }
        OutliveButton(title: "Edit Schedule", style: .secondary) { }
        OutliveButton(title: "Delete Entry", style: .destructive) { }
        OutliveButton(title: "Saving...", style: .primary, isLoading: true) { }
    }
    .padding()
}
