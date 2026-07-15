import Observation
import SwiftUI
import UIKit

struct ImageGenerationView: View {
    @Bindable var viewModel: ImageGenerationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var promptFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                resultCard
                controlsCard
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .task { await viewModel.refreshAvailability() }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                Task { await viewModel.refreshAvailability() }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.state)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(AppMetadata.name)
                .font(.largeTitle.bold())
            Text("Create privately on this device")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var resultCard: some View {
        Group {
            if let generatedImage = viewModel.state.currentImage,
               let image = UIImage(data: generatedImage.pngData) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("Generated image")
                        .accessibilityIdentifier("Generated image")

                    HStack(spacing: 12) {
                        Label("AI-generated", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        saveButton
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Your image will appear here", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Choose an available model, describe your idea, then press SEND.")
                }
                .frame(minHeight: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            modelSection
            Divider()
            promptSection
            statusSection
            sendButton
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Model")
                    .font(.headline)
                Spacer()
                Text(viewModel.selectedDescriptor?.familyName ?? "No model selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("Selected model")
            }

            Text(viewModel.filesLocationText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("Files location")

            ForEach(viewModel.featuredReferences, id: \.self) { reference in
                featuredSourceCard(reference)
            }

            pendingConfirmation
            customReferenceField
            downloadedModels
        }
    }

    private func featuredSourceCard(_ reference: ModelRepositoryReference) -> some View {
        let descriptor = ModelCatalog.descriptor(for: reference)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reference.id)
                        .font(.body.weight(.semibold))
                    Text(descriptor?.summary ?? "User-supplied Hugging Face model.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                downloadAction(for: reference)
            }
            downloadProgress(for: reference)
            Text(downloadStateText(for: reference))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
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
            Label("Downloaded", systemImage: "checkmark.circle")
                .font(.caption.weight(.semibold))
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
                Text("Confirm Download")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("Download confirmation")
                Text("\(plan.revision.reference.id) - \(byteText(plan.expectedSizeBytes)) - \(plan.revision.license ?? "license unavailable")")
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
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var customReferenceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Hugging Face Reference")
                .font(.subheadline.weight(.semibold))
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

    private var downloadedModels: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Downloaded Models")
                .font(.subheadline.weight(.semibold))
            if viewModel.catalogEntries.compactMap(\.snapshot).isEmpty {
                Text("No downloaded models")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("No downloaded models")
            } else {
                ForEach(viewModel.catalogEntries) { entry in
                    if let snapshot = entry.snapshot {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snapshot.reference.id)
                                    .font(.body.weight(.semibold))
                                Text(compatibilityText(snapshot.compatibility))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if entry.descriptor?.id == viewModel.selectedModelID {
                                Label("Selected", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .accessibilityIdentifier("Selected \(snapshot.reference.id)")
                            } else if let descriptor = entry.descriptor {
                                Button("Select", systemImage: "checkmark.circle") {
                                    Task { await viewModel.selectModel(descriptor.id) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(!snapshot.compatibility.isSelectable || viewModel.operationLocked)
                                .accessibilityIdentifier("Select \(snapshot.reference.id)")
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Describe your image")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.prompt.count)/1,000")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(viewModel.prompt.count >= 950 ? Color.orange : Color.secondary)
            }
            TextEditor(text: $viewModel.prompt)
                .focused($promptFocused)
                .frame(minHeight: 112)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Image prompt")
                .accessibilityIdentifier("Image prompt")
            if let validationMessage = viewModel.validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.state.isBusy {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: viewModel.state.progress?.fractionCompleted ?? 0)
                Text(viewModel.state.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.state.statusText)
        } else if case .refused = viewModel.state {
            Label(viewModel.state.statusText, systemImage: "hand.raised.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if case .failed = viewModel.state {
            Label(viewModel.state.statusText, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var sendButton: some View {
        Button {
            promptFocused = false
            viewModel.startGeneration()
        } label: {
            HStack {
                if viewModel.state.isBusy {
                    ProgressView()
                        .tint(.white)
                }
                Text("SEND")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(!viewModel.canSend)
        .keyboardShortcut(.return, modifiers: .command)
        .accessibilityHint("Generates one image on this device")
    }

    @ViewBuilder
    private var saveButton: some View {
        switch viewModel.saveState {
        case .hidden:
            EmptyView()
        case .requestingPermission, .saving:
            Button(action: {}) {
                Label("Saving", systemImage: "arrow.down.circle")
            }
            .disabled(true)
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Saved to Photos")
        case .denied:
            Button("Open Settings", systemImage: "gear") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
        case .ready, .failed:
            Button {
                viewModel.startSaving()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .accessibilityLabel("Save generated image")
            .accessibilityIdentifier("Save generated image")
        }
    }

    private var selectedAvailability: ModelAvailability {
        guard let id = viewModel.selectedModelID else {
            return viewModel.catalog
                .map { viewModel.availability(for: $0.id) }
                .first { $0 != .checking } ?? .checking
        }
        return viewModel.availability(for: id)
    }

    private func downloadStateText(for reference: ModelRepositoryReference) -> String {
        switch viewModel.downloadState(for: reference) {
        case .notDownloaded: "Not downloaded"
        case .resolving: "Resolving metadata"
        case .awaitingConfirmation(_, let size, let license):
            "Awaiting confirmation - \(size.map(byteText) ?? "size unknown") - \(license ?? "license unavailable")"
        case .downloading(_, let progress):
            progress.fractionCompleted.map { "Downloading \(Int($0 * 100))%" } ?? "Downloading"
        case .validating: "Validating snapshot"
        case .downloaded: "Downloaded and validated"
        case .cancelled: "Download cancelled"
        case .failed: "Download failed"
        }
    }

    private func compatibilityText(_ compatibility: ModelCompatibility) -> String {
        switch compatibility {
        case .compatible: "Compatible"
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
    ImageGenerationView(viewModel: PreviewDependencies.makeViewModel())
}
#endif
