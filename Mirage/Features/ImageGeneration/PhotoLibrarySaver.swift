import CryptoKit
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

public enum PhotoLibrarySaveError: Error, Equatable, Sendable {
    case invalidImage
    case denied
    case restricted
    case writeFailed
}

public protocol PhotoLibraryClient: Sendable {
    func authorizationStatus() async -> PhotoAuthorizationState
    func requestAddAuthorization() async -> PhotoAuthorizationState
    func createPNGAsset(from data: Data, filename: String) async throws
}

public struct SystemPhotoLibraryClient: PhotoLibraryClient {
    public init() {}

    public func authorizationStatus() async -> PhotoAuthorizationState {
        map(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    public func requestAddAuthorization() async -> PhotoAuthorizationState {
        map(await PHPhotoLibrary.requestAuthorization(for: .addOnly))
    }

    public func createPNGAsset(from data: Data, filename: String) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.contentType = .png
                options.originalFilename = filename
                request.addResource(with: .photo, data: data, options: options)
            }
        } catch {
            throw PhotoLibrarySaveError.writeFailed
        }
    }

    private func map(_ status: PHAuthorizationStatus) -> PhotoAuthorizationState {
        switch status {
        case .authorized, .limited: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .restricted
        }
    }
}

public actor PhotoLibrarySaver: PhotoLibrarySaving {
    private static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    private let client: any PhotoLibraryClient
    private var savedDigests: Set<String> = []
    private var inFlightDigests: Set<String> = []

    public init(client: any PhotoLibraryClient = SystemPhotoLibraryClient()) {
        self.client = client
    }

    public func authorizationStatus() async -> PhotoAuthorizationState {
        await client.authorizationStatus()
    }

    public func savePNG(_ data: Data) async throws -> PhotoSaveResult {
        guard Self.isValidMetadataFreePNG(data) else {
            throw PhotoLibrarySaveError.invalidImage
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if savedDigests.contains(digest) || inFlightDigests.contains(digest) {
            return .alreadySaved
        }

        var status = await client.authorizationStatus()
        if status == .notDetermined {
            status = await client.requestAddAuthorization()
        }
        switch status {
        case .authorized:
            break
        case .denied, .notDetermined:
            throw PhotoLibrarySaveError.denied
        case .restricted:
            throw PhotoLibrarySaveError.restricted
        }

        inFlightDigests.insert(digest)
        defer { inFlightDigests.remove(digest) }
        try await client.createPNGAsset(from: data, filename: "Mirage-\(digest.prefix(12)).png")
        savedDigests.insert(digest)
        return .saved
    }

    private static func isValidMetadataFreePNG(_ data: Data) -> Bool {
        guard data.starts(with: pngSignature),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              properties[kCGImagePropertyGPSDictionary] == nil,
              properties[kCGImagePropertyExifDictionary] == nil,
              properties[kCGImagePropertyTIFFDictionary] == nil else {
            return false
        }
        return true
    }
}
