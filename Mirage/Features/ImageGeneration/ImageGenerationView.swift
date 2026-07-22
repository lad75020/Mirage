import Observation
import SwiftUI

struct ImageGenerationView: View {
    @Bindable var viewModel: ImageGenerationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationStack {
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
            .background(PlatformAppearance.groupedBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ImageGenerationModelSettingsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Model settings")
                    .accessibilityHint("Manage, validate, and select image generation models")
                    .accessibilityIdentifier("Model settings")
                }
            }
        }
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
               let image = Image(platformImageData: generatedImage.pngData) {
                VStack(alignment: .leading, spacing: 12) {
                    image
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
                    Text("Select a model in Settings, describe your idea, then press SEND.")
                }
                .frame(minHeight: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PlatformAppearance.separator.opacity(0.35), lineWidth: 1)
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            selectedModelSummary
            Divider()
            promptSection
            generationOptionsSection
            statusSection
            sendButton
        }
        .padding(20)
        .background(PlatformAppearance.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var selectedModelSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedDescriptor?.familyName ?? "No model selected")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("Selected model summary")
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected model, \(viewModel.selectedDescriptor?.familyName ?? "none")")
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
                .background(PlatformAppearance.tertiaryFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var generationOptionsSection: some View {
        GroupBox("Generation options") {
            VStack(alignment: .leading, spacing: 14) {
                Stepper(value: $viewModel.inferenceSteps, in: 1...50) {
                    LabeledContent("Inference steps", value: "\(viewModel.inferenceSteps)")
                }
                .accessibilityIdentifier("Inference steps")

                Picker("Picture size", selection: $viewModel.pictureSize) {
                    ForEach(viewModel.availablePictureSizes) { size in
                        Text(size.label).tag(size)
                    }
                }
                .accessibilityIdentifier("Picture size")
            }
            .padding(.top, 6)
        }
        .disabled(viewModel.operationLocked)
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
                if let url = PlatformAppearance.photoPrivacySettingsURL {
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
}

#if DEBUG
#Preview {
    ImageGenerationView(viewModel: PreviewDependencies.makeViewModel())
}
#endif
