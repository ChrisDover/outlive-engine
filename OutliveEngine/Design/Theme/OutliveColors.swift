// OutliveColors.swift
// OutliveEngine
//
// Adaptive color palette for the Outlive Engine design system.
// All colors support light and dark mode via dynamic providers.

import SwiftUI

// MARK: - Color Extension

extension Color {

    // MARK: Recovery Zones

    /// Recovery zone green — system is recovered and ready.
    static let recoveryGreen = Color(
        light: Color(red: 0.204, green: 0.780, blue: 0.349),   // #34C759
        dark:  Color(red: 0.251, green: 0.831, blue: 0.400)    // slightly lifted for dark
    )

    /// Recovery zone yellow — moderate readiness, train with awareness.
    static let recoveryYellow = Color(
        light: Color(red: 1.0, green: 0.839, blue: 0.039),     // #FFD60A
        dark:  Color(red: 1.0, green: 0.855, blue: 0.118)
    )

    /// Recovery zone red — suppressed readiness, prioritize recovery.
    static let recoveryRed = Color(
        light: Color(red: 1.0, green: 0.231, blue: 0.188),     // #FF3B30
        dark:  Color(red: 1.0, green: 0.302, blue: 0.259)
    )

    // MARK: Domain Accents

    /// Training domain accent — strength, hypertrophy, endurance.
    static let domainTraining = Color(
        light: Color(red: 0.0, green: 0.478, blue: 1.0),       // #007AFF
        dark:  Color(red: 0.039, green: 0.518, blue: 1.0)
    )

    /// Nutrition domain accent — meals, macros, timing.
    static let domainNutrition = Color(
        light: Color(red: 1.0, green: 0.584, blue: 0.0),       // #FF9500
        dark:  Color(red: 1.0, green: 0.624, blue: 0.039)
    )

    /// Supplements domain accent — stacks, timing, dosing.
    static let domainSupplements = Color(
        light: Color(red: 0.686, green: 0.322, blue: 0.871),   // #AF52DE
        dark:  Color(red: 0.749, green: 0.380, blue: 0.918)
    )

    /// Interventions domain accent — sauna, cold, breathwork.
    static let domainInterventions = Color(
        light: Color(red: 0.353, green: 0.784, blue: 0.980),   // #5AC8FA
        dark:  Color(red: 0.392, green: 0.808, blue: 1.0)
    )

    /// Sleep domain accent — quality, staging, HRV trends.
    static let domainSleep = Color(
        light: Color(red: 0.345, green: 0.337, blue: 0.839),   // #5856D6
        dark:  Color(red: 0.408, green: 0.400, blue: 0.882)
    )

    /// Genomics domain accent — SNPs, risk profiles.
    static let domainGenomics = Color(
        light: Color(red: 1.0, green: 0.176, blue: 0.333),     // #FF2D55
        dark:  Color(red: 1.0, green: 0.243, blue: 0.392)
    )

    /// Bloodwork domain accent — biomarkers, lab panels.
    static let domainBloodwork = Color(
        light: Color(red: 1.0, green: 0.231, blue: 0.188),     // #FF3B30
        dark:  Color(red: 1.0, green: 0.302, blue: 0.259)
    )

    // MARK: Surfaces

    /// Primary background — full-screen base layer.
    static let surfaceBackground = Color(
        light: Color(red: 0.949, green: 0.949, blue: 0.969),   // #F2F2F7
        dark:  Color(red: 0.0, green: 0.0, blue: 0.0)          // #000000
    )

    /// Secondary background — grouped table / inset areas.
    static let surfaceSecondary = Color(
        light: Color.white,
        dark:  Color(red: 0.110, green: 0.110, blue: 0.118)    // #1C1C1E
    )

    /// Card background — floating card surfaces.
    static let surfaceCard = Color(
        light: Color.white,
        dark:  Color(red: 0.141, green: 0.141, blue: 0.153)    // #242427
    )

    /// Elevated surface — modals, popovers, raised elements.
    static let surfaceElevated = Color(
        light: Color.white,
        dark:  Color(red: 0.173, green: 0.173, blue: 0.180)    // #2C2C2E
    )

    // MARK: Text

    /// Primary text — headlines, body copy.
    static let textPrimary = Color(
        light: Color(red: 0.0, green: 0.0, blue: 0.0),
        dark:  Color.white
    )

    /// Secondary text — subtitles, metadata.
    static let textSecondary = Color(
        light: Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.6),
        dark:  Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.6)
    )

    /// Tertiary text — placeholders, disabled labels.
    static let textTertiary = Color(
        light: Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.3),
        dark:  Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.3)
    )
}

// MARK: - Color Convenience Initializer

extension Color {

    /// Creates an adaptive color that resolves differently in light and dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
