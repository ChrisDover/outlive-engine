// GenomeUploadView.swift
// OutliveEngine
//
// File picker for 23andMe / AncestryDNA raw data. All SNP processing
// happens on-device. This step is optional and can be skipped.

import SwiftUI
import UniformTypeIdentifiers

struct GenomeUploadView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var processingStatus: GenomeProcessingStatus = .idle
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: .genome, progress: viewModel.progress)

            ScrollView {
                VStack(spacing: OutliveSpacing.lg) {
                    privacySection
                    uploadSection
                    statusSection
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.lg)
            }

            Spacer()

            buttonSection
        }
        .background(Color.surfaceBackground)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { viewModel.previous() } label: {
                    Image(systemName: "chevron.left")
                        .font(.outliveHeadline)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText, .commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onAppear { viewModel.currentStep = .genome }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        HStack(alignment: .top, spacing: OutliveSpacing.sm) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.domainGenomics)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("On-Device Processing")
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                Text("Your genome data is processed entirely on-device. Raw SNP data never leaves your phone.")
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: OutliveSpacing.md) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.textTertiary)

            Text("Import Raw Genome Data")
                .font(.outliveTitle3)
                .foregroundStyle(Color.textPrimary)

            Text("Upload your raw data file from 23andMe or AncestryDNA (.txt or .csv format).")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OutliveSpacing.lg)

            OutliveButton(title: "Choose File", style: .secondary) {
                showFilePicker = true
            }
            .padding(.horizontal, OutliveSpacing.xxl)
            .disabled(processingStatus == .processing)
        }
        .padding(.vertical, OutliveSpacing.lg)
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        switch processingStatus {
        case .idle:
            EmptyView()

        case .processing:
            HStack(spacing: OutliveSpacing.sm) {
                ProgressView()
                Text("Parsing SNP data...")
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(OutliveSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))

        case .complete:
            HStack(spacing: OutliveSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.recoveryGreen)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Genome Data Loaded")
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Text("SNP profiles parsed and stored locally.")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(OutliveSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))

        case .error:
            HStack(spacing: OutliveSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.recoveryRed)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Import Failed")
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Text(errorMessage ?? "The file could not be parsed. Please check the format and try again.")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(OutliveSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            OutliveButton(title: "Continue", style: .primary) {
                viewModel.next()
            }
            .disabled(processingStatus == .processing)

            Button("Skip for Now") {
                viewModel.skipStep()
            }
            .font(.outliveSubheadline)
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.bottom, OutliveSpacing.lg)
    }

    // MARK: - File Handling

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            processGenomeFile(at: fileURL)

        case .failure(let error):
            processingStatus = .error
            errorMessage = error.localizedDescription
        }
    }

    private func processGenomeFile(at url: URL) {
        processingStatus = .processing

        // Simulated on-device processing. In production this would parse
        // the raw SNP file and populate a GenomicProfile model.
        Task {
            guard url.startAccessingSecurityScopedResource() else {
                processingStatus = .error
                errorMessage = "Unable to access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                guard !data.isEmpty else {
                    throw GenomeImportError.emptyFile
                }

                // Simulate processing time
                try await Task.sleep(for: .seconds(2))

                processingStatus = .complete
                viewModel.genomeUploaded = true
            } catch {
                processingStatus = .error
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Processing Status

private enum GenomeProcessingStatus: Sendable {
    case idle
    case processing
    case complete
    case error
}

// MARK: - Import Error

private enum GenomeImportError: LocalizedError {
    case emptyFile
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .emptyFile:     "The selected file is empty."
        case .invalidFormat: "The file format is not recognized as 23andMe or AncestryDNA raw data."
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenomeUploadView(viewModel: OnboardingViewModel())
            .environment(AppState())
    }
}
