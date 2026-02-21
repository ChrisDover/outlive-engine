// OutliveSpacing.swift
// OutliveEngine
//
// Spatial rhythm constants for the Outlive Engine design system.
// Provides a consistent 4-point spacing scale and shared radius values.

import SwiftUI

// MARK: - Spacing Scale

enum OutliveSpacing {

    /// 4pt — hairline gaps, icon insets.
    static let xxs: CGFloat = 4

    /// 8pt — tight padding, compact rows.
    static let xs: CGFloat = 8

    /// 12pt — standard inner padding.
    static let sm: CGFloat = 12

    /// 16pt — default content padding.
    static let md: CGFloat = 16

    /// 24pt — section gaps, group spacing.
    static let lg: CGFloat = 24

    /// 32pt — large section breaks.
    static let xl: CGFloat = 32

    /// 48pt — screen-level vertical margins.
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radii

extension OutliveSpacing {

    enum CornerRadius {
        /// 8pt — buttons, small chips.
        static let small: CGFloat = 8

        /// 12pt — cards, text fields.
        static let medium: CGFloat = 12

        /// 16pt — modals, sheets.
        static let large: CGFloat = 16
    }
}

// MARK: - Semantic Shortcuts

extension OutliveSpacing {

    /// Standard internal padding for cards (16pt).
    static let cardPadding: CGFloat = 16

    /// Vertical spacing between major sections (24pt).
    static let sectionSpacing: CGFloat = 24
}
