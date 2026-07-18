import Darwin
import SwiftUI

@main
struct MirageMacApp: App {
    @StateObject private var modelStorageLocation = ModelStorageLocation()

    init() {
        setenv("GGML_METAL_TENSOR_DISABLE", "1", 1)
        setenv("GGML_METAL_FUSION_DISABLE", "1", 1)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelStorageBaseURL: modelStorageLocation.baseURL)
                .id(modelStorageLocation.selectionID)
                .frame(minWidth: 760, minHeight: 680)
        }
        .defaultSize(width: 900, height: 900)

        Settings {
            ModelStorageSettingsView(storageLocation: modelStorageLocation)
        }
    }
}
