import Observation
import SwiftUI
import UIKit

struct ImageGenerationView: View {
    @Bindable var viewModel: ImageGenerationViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.headline)
            Menu {
                ForEach(viewModel.catalog) { descriptor in
                    Button {
                        viewModel.selectModel(descriptor.id)
                    } label: {
                        if viewModel.selectedModelID == descriptor.id {
                            Label(descriptor.familyName, systemImage: "checkmark")
                        } else {
                            Text(descriptor.familyName)
                        }
                    }
                    .disabled(!viewModel.availability(for: descriptor.id).isAvailable)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.selectedDescriptor?.familyName ?? "No model available")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(selectedAvailability.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 14)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(viewModel.selectionLocked)
            .accessibilityLabel("Model selection")
            .accessibilityIdentifier("Model selection")
            .accessibilityValue(viewModel.selectedDescriptor?.familyName ?? "No model available")

            Text(selectedAvailability.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
}

#if DEBUG
#Preview {
    ImageGenerationView(viewModel: PreviewDependencies.makeViewModel())
}
#endif
