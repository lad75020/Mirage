import Darwin
import SwiftUI

@main
struct MirageApp: App {
    init() {
        setenv("GGML_METAL_TENSOR_DISABLE", "1", 1)
        setenv("GGML_METAL_FUSION_DISABLE", "1", 1)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
