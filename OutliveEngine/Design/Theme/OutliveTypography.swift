// OutliveTypography.swift
// OutliveEngine
//
// Typography scale for the Outlive Engine design system.
// Uses SF Pro Display for titles, SF Pro Text (default) for body,
// and SF Pro Mono (monospaced) for data readouts.
// All styles support Dynamic Type automatically.

import SwiftUI

// MARK: - Font Extension

extension Font {

    // MARK: Display (Titles)

    /// 34pt bold rounded — top-level screen titles.
    static let outliveLargeTitle: Font = .system(size: 34, weight: .bold, design: .rounded)

    /// 28pt bold rounded — section titles.
    static let outliveTitle: Font = .system(size: 28, weight: .bold, design: .rounded)

    /// 22pt bold rounded — secondary titles.
    static let outliveTitle2: Font = .system(size: 22, weight: .bold, design: .rounded)

    /// 20pt semibold rounded — tertiary titles.
    static let outliveTitle3: Font = .system(size: 20, weight: .semibold, design: .rounded)

    // MARK: Text (Body)

    /// 17pt semibold default — emphasized body text.
    static let outliveHeadline: Font = .system(size: 17, weight: .semibold, design: .default)

    /// 17pt regular default — standard body copy.
    static let outliveBody: Font = .system(size: 17, weight: .regular, design: .default)

    /// 16pt regular default — supporting descriptive text.
    static let outliveCallout: Font = .system(size: 16, weight: .regular, design: .default)

    /// 15pt regular default — secondary information.
    static let outliveSubheadline: Font = .system(size: 15, weight: .regular, design: .default)

    /// 13pt regular default — footnotes, attributions.
    static let outliveFootnote: Font = .system(size: 13, weight: .regular, design: .default)

    /// 12pt regular default — timestamps, badges, labels.
    static let outliveCaption: Font = .system(size: 12, weight: .regular, design: .default)

    // MARK: Mono (Data)

    /// 17pt medium monospaced — metric readouts, timers.
    static let outliveMonoData: Font = .system(size: 17, weight: .medium, design: .monospaced)

    /// 13pt regular monospaced — small data labels, units.
    static let outliveMonoSmall: Font = .system(size: 13, weight: .regular, design: .monospaced)
}
