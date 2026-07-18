import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PlatformAppearance {
    static var groupedBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var secondaryGroupedBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    static var secondaryFill: Color {
        #if os(macOS)
        Color(nsColor: .controlColor)
        #else
        Color(uiColor: .secondarySystemFill)
        #endif
    }

    static var tertiaryFill: Color {
        #if os(macOS)
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemFill)
        #endif
    }

    static var separator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    static var photoPrivacySettingsURL: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")
        #else
        URL(string: UIApplication.openSettingsURLString)
        #endif
    }
}

extension Image {
    init?(platformImageData data: Data) {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #endif
    }
}

extension View {
    @ViewBuilder
    func mirageInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func mirageRepositoryTextInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
