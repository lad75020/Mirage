import SwiftUI

struct ContentView: View {
    @State private var viewModel: ImageGenerationViewModel

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            _viewModel = State(initialValue: PreviewDependencies.makeViewModel())
            return
        }
        #endif
        _viewModel = State(initialValue: LiveDependencies.makeViewModel())
    }

    var body: some View {
        ImageGenerationView(viewModel: viewModel)
            .tint(.indigo)
    }
}

#Preview {
    ContentView()
}
