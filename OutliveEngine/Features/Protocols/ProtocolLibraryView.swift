// ProtocolLibraryView.swift
// OutliveEngine
//
// List of all protocol sources with filtering, reordering, and active toggles.

import SwiftUI
import SwiftData

struct ProtocolLibraryView: View {

    @Query(sort: \ProtocolSource.priority)
    private var protocols: [ProtocolSource]

    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: String?

    private var categories: [String] {
        Array(Set(protocols.map(\.category))).sorted()
    }

    private var filteredProtocols: [ProtocolSource] {
        guard let category = selectedCategory else { return protocols }
        return protocols.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            Group {
                if protocols.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.clipboard",
                        title: "No Protocols",
                        message: "Add evidence-based protocols to personalize your daily health plan."
                    )
                } else {
                    protocolListContent
                }
            }
            .navigationTitle("Protocol Library")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - List Content

    private var protocolListContent: some View {
        VStack(spacing: 0) {
            if categories.count > 1 {
                categoryFilter
            }

            List {
                ForEach(filteredProtocols) { proto in
                    NavigationLink {
                        ProtocolDetailView(protocolSource: proto)
                    } label: {
                        ProtocolRow(protocolSource: proto)
                    }
                }
                .onMove(perform: reorderProtocols)
                .listRowBackground(Color.surfaceCard)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OutliveSpacing.xs) {
                filterChip(title: "All", isSelected: selectedCategory == nil) {
                    withAnimation { selectedCategory = nil }
                }

                ForEach(categories, id: \.self) { category in
                    filterChip(title: category.capitalized, isSelected: selectedCategory == category) {
                        withAnimation { selectedCategory = category }
                    }
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.vertical, OutliveSpacing.xs)
        }
        .background(Color.surfaceBackground)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.outliveSubheadline)
                .foregroundStyle(isSelected ? .white : Color.textPrimary)
                .padding(.horizontal, OutliveSpacing.sm)
                .padding(.vertical, OutliveSpacing.xs)
                .background(isSelected ? Color.domainTraining : Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        }
    }

    // MARK: - Reorder

    private func reorderProtocols(from source: IndexSet, to destination: Int) {
        var reordered = filteredProtocols
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, proto) in reordered.enumerated() {
            proto.priority = index
        }
    }
}

// MARK: - Protocol Row

private struct ProtocolRow: View {

    @Bindable var protocolSource: ProtocolSource

    var body: some View {
        HStack(spacing: OutliveSpacing.sm) {
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(protocolSource.name)
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: OutliveSpacing.xs) {
                    Text(protocolSource.author)
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)

                    evidenceBadge
                }
            }

            Spacer()

            Toggle("", isOn: $protocolSource.isActive)
                .labelsHidden()
                .tint(Color.recoveryGreen)
        }
        .padding(.vertical, OutliveSpacing.xxs)
    }

    private var evidenceBadge: some View {
        Text(protocolSource.evidenceLevel.displayLabel)
            .font(.outliveCaption)
            .foregroundStyle(protocolSource.evidenceLevel.color)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, 2)
            .background(protocolSource.evidenceLevel.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }
}

// MARK: - Evidence Level Display

extension EvidenceLevel {

    var displayLabel: String {
        switch self {
        case .metaAnalysis:  return "Meta-Analysis"
        case .rct:           return "RCT"
        case .observational: return "Observational"
        case .mechanistic:   return "Mechanistic"
        case .anecdotal:     return "Anecdotal"
        }
    }

    var color: Color {
        switch self {
        case .metaAnalysis:  return .recoveryGreen
        case .rct:           return .domainTraining
        case .observational: return .domainNutrition
        case .mechanistic:   return .domainSupplements
        case .anecdotal:     return .textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    ProtocolLibraryView()
        .modelContainer(for: ProtocolSource.self, inMemory: true)
}
