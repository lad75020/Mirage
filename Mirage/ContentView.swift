import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.18), Color.cyan.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(AppMetadata.name)
                        .font(.largeTitle.bold())

                    Text(AppMetadata.tagline)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Label(AppMetadata.status, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ContentView()
}
