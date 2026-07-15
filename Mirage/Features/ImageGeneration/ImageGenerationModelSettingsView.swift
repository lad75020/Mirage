import Observation
import SwiftUI

struct ImageGenerationModelSettingsView: View {
    @Bindable var viewModel: ImageGenerationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                selectionSummary
                featuredModelsSection
                customReferenceSection
                downloadedModelsSection
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Model Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refreshAvailability() }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.state)
    }

    private var selectionSummary: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Active Model", systemImage: "cube.transparent")
                    .font(.headline)
                Text(viewModel.selectedDescriptor?.familyName ?? "No model selected")
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("Selected model")
                Text(viewModel.filesLocationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("Files location")
            }
        }
    }

    private var featuredModelsSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Featured Models")
                    .font(.headline)
                Text("Downloads are resolved, confirmed, and validated before they can be selected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.featuredReferences, id: \.self) { reference in
                    featuredSourceCard(reference)
                }

                pendingConfirmation
            }
        }
    }

    private func featuredSourceCard(_ reference: ModelRepositoryReference) -> some View {
        let descriptor = ModelCatalog.descriptor(for: reference)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reference.id)
                        .font(.body.weight(.semibold))
                    Text(descriptor?.summary ?? "User-supplied Hugging Face model.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                downloadAction(for: reference)
            }
            downloadProgress(for: reference)
            Label(downloadStateText(for: reference), systemImage: downloadStateIcon(for: reference))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Featured model \(reference.id)")
        .accessibilityIdentifier("Featured model \(reference.id)")
    }

    @ViewBuilder
    private func downloadAction(for reference: ModelRepositoryReference) -> some View {
        switch viewModel.downloadState(for: reference) {
        case .validating, .downloading:
            Button("Cancel", systemImage: "xmark.circle") {
                viewModel.cancelDownload()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("Cancel \(reference.id)")
        case .resolving:
            ProgressView()
                .accessibilityLabel("Resolving \(reference.id)")
        case .failed:
            Button("Retry", systemImage: "arrow.clockwise") {
                Task { await viewModel.retryDownload(for: reference) }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.operationLocked)
            .accessibilityIdentifier("Retry \(reference.id)")
        case .downloaded:
            Label("Validated", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        default:
            Button("Download", systemImage: "arrow.down.circle") {
                Task { await viewModel.requestDownload(for: reference) }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.operationLocked)
            .accessibilityIdentifier("Download \(reference.id)")
        }
    }

    @ViewBuilder
    private func downloadProgress(for reference: ModelRepositoryReference) -> some View {
        if case .downloading(_, let progress) = viewModel.downloadState(for: reference) {
            ProgressView(value: progress.fractionCompleted ?? 0)
                .accessibilityIdentifier("Progress \(reference.id)")
        }
    }

    @ViewBuilder
    private var pendingConfirmation: some View {
        if let plan = viewModel.pendingDownloadPlan {
            VStack(alignment: .leading, spacing: 8) {
                Label("Confirm Download", systemImage: "externaldrive.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("Download confirmation")
                Text("\(plan.revision.reference.id) · \(byteText(plan.expectedSizeBytes)) · \(plan.revision.license ?? "license unavailable")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Confirm", systemImage: "checkmark.circle") {
                        viewModel.confirmDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Confirm download")
                    Button("Cancel", systemImage: "xmark.circle") {
                        viewModel.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Cancel confirmation")
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var customReferenceSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Hugging Face Reference")
                    .font(.headline)
                Text("Only public owner/repository references are accepted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("owner/repository", text: $viewModel.customReferenceInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("Custom model reference")
                    Button("Download", systemImage: "arrow.down.circle") {
                        Task { await viewModel.submitCustomReference() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.operationLocked)
                    .accessibilityIdentifier("Download custom model")
                }
                if let error = viewModel.customReferenceError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("Custom reference error")
                }
            }
        }
    }

    private var downloadedModelsSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Downloaded Models")
                    .font(.headline)
                if viewModel.catalogEntries.compactMap(\.snapshot).isEmpty {
                    ContentUnavailableView(
                        "No Downloaded Models",
                        systemImage: "externaldrive",
                        description: Text("Download and validate a model before selecting it.")
                    )
                    .accessibilityIdentifier("No downloaded models")
                } else {
                    ForEach(viewModel.catalogEntries) { entry in
                        if let snapshot = entry.snapshot {
                            downloadedModelRow(entry: entry, snapshot: snapshot)
                        }
                    }
                }
            }
        }
    }

    private func downloadedModelRow(entry: ModelCatalogEntry, snapshot: LocalModelSnapshot) -> some View {
        let availability = entry.descriptor.map { viewModel.availability(for: $0.id) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.reference.id)
                        .font(.body.weight(.semibold))
                    Text(compatibilityText(snapshot.compatibility))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let availability {
                        Text(availability.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(availability.isAvailable ? .green : .secondary)
                        Text(availability.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if entry.descriptor?.id == viewModel.selectedModelID {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)
                        .accessibilityIdentifier("Selected \(snapshot.reference.id)")
                } else if let descriptor = entry.descriptor {
                    Button("Select", systemImage: "checkmark.circle") {
                        Task { await viewModel.selectModel(descriptor.id) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!snapshot.compatibility.isSelectable || availability?.isAvailable != true || viewModel.operationLocked)
                    .accessibilityIdentifier("Select \(snapshot.reference.id)")
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func downloadStateText(for reference: ModelRepositoryReference) -> String {
        switch viewModel.downloadState(for: reference) {
        case .notDownloaded: "Not downloaded"
        case .resolving: "Resolving metadata"
        case .awaitingConfirmation(_, let size, let license):
            "Awaiting confirmation · \(size.map(byteText) ?? "size unknown") · \(license ?? "license unavailable")"
        case .downloading(_, let progress):
            progress.fractionCompleted.map { "Downloading \(Int($0 * 100))%" } ?? "Downloading"
        case .validating: "Validating snapshot"
        case .downloaded: "Downloaded and validated"
        case .cancelled: "Download cancelled"
        case .failed: "Download failed"
        }
    }

    private func downloadStateIcon(for reference: ModelRepositoryReference) -> String {
        switch viewModel.downloadState(for: reference) {
        case .downloaded: "checkmark.shield"
        case .failed: "exclamationmark.triangle"
        case .cancelled: "xmark.circle"
        case .resolving, .awaitingConfirmation, .downloading, .validating: "clock"
        case .notDownloaded: "externaldrive"
        }
    }

    private func compatibilityText(_ compatibility: ModelCompatibility) -> String {
        switch compatibility {
        case .compatible: "Validated and compatible"
        case .incompatible(let reason): "Incompatible: \(reason)"
        case .unknownCustomRepository: "Downloaded but not compatible yet"
        }
    }

    private func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ImageGenerationModelSettingsView(viewModel: PreviewDependencies.makeViewModel())
    }
}
#endif
