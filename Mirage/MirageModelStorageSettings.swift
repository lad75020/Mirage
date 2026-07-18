import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ModelStorageLocation: ObservableObject {
    private static let bookmarkDefaultsKey = "mirage.model-storage.bookmark"

    @Published private(set) var baseURL: URL
    @Published private(set) var selectionID = UUID()
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasUnavailablePersistedFolder = false

    private let defaultBaseURL: URL
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private var securityScopedURLs: [URL] = []

    var modelRootURL: URL {
        baseURL
            .appendingPathComponent("Mirage Models", isDirectory: true)
            .standardizedFileURL
    }

    init(
        defaultBaseURL: URL? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        let documentsURL = defaultBaseURL
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.defaultBaseURL = documentsURL.standardizedFileURL
        self.baseURL = documentsURL.standardizedFileURL
        restoreBookmarkIfNeeded()
    }

    deinit {
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose where Mirage stores its models"
        panel.prompt = "Choose Folder"

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            try useSelectedFolder(selectedURL)
        } catch {
            errorMessage = "Mirage couldn’t access that folder. Choose it again or select another folder."
        }
    }

    func resetToDefault() {
        defaults.removeObject(forKey: Self.bookmarkDefaultsKey)
        baseURL = defaultBaseURL
        selectionID = UUID()
        errorMessage = nil
        hasUnavailablePersistedFolder = false
    }

    func retryPersistedFolder() {
        restoreBookmarkIfNeeded()
    }

    func dismissError() {
        errorMessage = nil
    }

    private func restoreBookmarkIfNeeded() {
        guard let bookmarkData = defaults.data(forKey: Self.bookmarkDefaultsKey) else {
            return
        }

        do {
            var bookmarkIsStale = false
            let restoredURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &bookmarkIsStale
            )
            guard restoredURL.startAccessingSecurityScopedResource() else {
                throw ModelStorageLocationError.authorizationFailed
            }
            securityScopedURLs.append(restoredURL)
            try validateDirectory(restoredURL)

            if bookmarkIsStale,
               let renewedBookmark = try? restoredURL.bookmarkData(
                   options: .withSecurityScope,
                   includingResourceValuesForKeys: nil,
                   relativeTo: nil
               ) {
                defaults.set(renewedBookmark, forKey: Self.bookmarkDefaultsKey)
            }
            baseURL = restoredURL.standardizedFileURL
            selectionID = UUID()
            errorMessage = nil
            hasUnavailablePersistedFolder = false
        } catch {
            baseURL = defaultBaseURL
            selectionID = UUID()
            hasUnavailablePersistedFolder = true
            errorMessage = "Selected model folder is unavailable. Reconnect the drive, then Retry."
        }
    }

    private func useSelectedFolder(_ selectedURL: URL) throws {
        guard selectedURL.startAccessingSecurityScopedResource() else {
            throw ModelStorageLocationError.authorizationFailed
        }
        securityScopedURLs.append(selectedURL)
        try validateDirectory(selectedURL)
        let bookmarkData = try selectedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        defaults.set(bookmarkData, forKey: Self.bookmarkDefaultsKey)
        baseURL = selectedURL.standardizedFileURL
        selectionID = UUID()
        errorMessage = nil
        hasUnavailablePersistedFolder = false
    }

    private func validateDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ModelStorageLocationError.notADirectory
        }
    }
}

private enum ModelStorageLocationError: Error {
    case authorizationFailed
    case notADirectory
}

struct ModelStorageSettingsView: View {
    @ObservedObject var storageLocation: ModelStorageLocation

    var body: some View {
        Form {
            Section("Model Storage") {
                LabeledContent("Mirage Models folder") {
                    Text(storageLocation.modelRootURL.path)
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }

                HStack {
                    Button("Choose Folder") {
                        storageLocation.chooseFolder()
                    }
                    .accessibilityLabel("Choose model storage folder")
                    .accessibilityIdentifier("chooseModelStorageFolder")

                    Button("Reset to Default") {
                        storageLocation.resetToDefault()
                    }
                    .accessibilityLabel("Reset model storage to Documents")
                    .accessibilityIdentifier("resetModelStorageFolder")
                }

                if storageLocation.hasUnavailablePersistedFolder {
                    Text("Selected model storage is unavailable. Reconnect the drive, then Retry.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Retry", systemImage: "arrow.clockwise") {
                        storageLocation.retryPersistedFolder()
                    }
                    .accessibilityLabel("Retry model storage connection")
                    .accessibilityHint("Reconnects the selected model storage folder after its drive is connected")
                    .accessibilityIdentifier("retryModelStorageFolder")
                }
            }

            Section {
                Text("Mirage uses a Mirage Models subfolder in the folder you choose. Removable and external volumes must be connected before opening Mirage.")
                Text("Changing this location switches the visible model library. Mirage does not move or delete models already stored elsewhere.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 500)
        .alert(
            "Model Storage",
            isPresented: Binding(
                get: { storageLocation.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        storageLocation.dismissError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                storageLocation.dismissError()
            }
        } message: {
            Text(storageLocation.errorMessage ?? "")
        }
    }
}
