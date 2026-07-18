import Foundation
import XCTest
@testable import MirageApp

final class ModelFileResolverTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testResolvesVerifiedFilesInsideModelRoot() async throws {
        let model = Data("model".utf8)
        let modelRoot = root.appendingPathComponent(ModelID.ernieImageTurbo.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: modelRoot, withIntermediateDirectories: true)
        let modelURL = modelRoot.appendingPathComponent("model.gguf")
        try model.write(to: modelURL)
        let descriptor = ModelDescriptor.testFixture(
            requirements: [
                .init(role: .diffusionModel, fileName: "model.gguf", sha256: model.sha256String)
            ]
        )
        let resolver = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )

        let availability = await resolver.availability(for: descriptor)
        let files = try await resolver.resolve(descriptor)

        XCTAssertEqual(availability, .available)
        XCTAssertEqual(files.diffusionModel.standardizedFileURL, modelURL.standardizedFileURL)
    }

    func testFastAvailabilityRehashesWhenAFileSignatureChanges() async throws {
        let original = Data("model".utf8)
        let changed = Data("wrong".utf8)
        let modelRoot = root.appendingPathComponent(ModelID.ernieImageTurbo.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: modelRoot, withIntermediateDirectories: true)
        let modelURL = modelRoot.appendingPathComponent("model.gguf")
        try original.write(to: modelURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: modelURL.path)
        let descriptor = ModelDescriptor.testFixture(requirements: [
            .init(
                role: .diffusionModel,
                fileName: "model.gguf",
                expectedByteCount: Int64(original.count),
                sha256: original.sha256String
            )
        ])
        let resolver = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )

        let initiallyAvailable = await resolver.availability(for: descriptor, revalidateFiles: false)
        XCTAssertEqual(initiallyAvailable, .available)
        try changed.write(to: modelURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2_000)], ofItemAtPath: modelURL.path)

        let changedAvailability = await resolver.availability(for: descriptor, revalidateFiles: false)
        XCTAssertEqual(changedAvailability, .integrityFailed("model.gguf"))
    }

    func testRejectsTraversalOutsideModelRoot() async throws {
        let descriptor = ModelDescriptor.testFixture(
            requirements: [
                .init(role: .diffusionModel, fileName: "../outside.gguf", sha256: String(repeating: "0", count: 64))
            ]
        )
        let resolver = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )

        let availability = await resolver.availability(for: descriptor)
        XCTAssertEqual(availability, .invalidPath)
    }

    func testRejectsMissingHashAndUnapprovedEvidence() async throws {
        let descriptor = ModelDescriptor.testFixture(
            requirements: [.init(role: .diffusionModel, fileName: "model.gguf", sha256: nil)],
            licenseApproved: false,
            evaluationApproved: false
        )
        let resolver = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )

        let availability = await resolver.availability(for: descriptor)
        XCTAssertEqual(availability, .licenseNotApproved)
    }

    func testRejectsInsufficientMemoryAndUnavailableProtectedData() async throws {
        let descriptor = ModelDescriptor.testFixture(minimumAvailableMemoryBytes: 1_000)
        let lowMemory = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: 999),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )
        let lowMemoryAvailability = await lowMemory.availability(for: descriptor)
        XCTAssertEqual(
            lowMemoryAvailability,
            .insufficientMemory(required: 1_000, available: 999)
        )

        let locked = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: false)
        )
        let lockedAvailability = await locked.availability(for: descriptor)
        XCTAssertEqual(lockedAvailability, .protectedDataUnavailable)
    }

    func testRejectsUnsupportedDeviceAllowlist() async throws {
        let descriptor = ModelDescriptor(
            id: .ernieImageTurbo,
            familyName: "Test",
            summary: "Test",
            packageVersion: "0.2.0",
            requirements: [
                .init(
                    role: .diffusionModel,
                    fileName: "model.gguf",
                    sha256: String(repeating: "a", count: 64)
                )
            ],
            profile: .init(width: 1024, height: 1024, steps: 8, cfgScale: 1),
            minimumAvailableMemoryBytes: 0,
            licenseApproved: true,
            evaluationApproved: true,
            supportedDeviceIdentifiers: ["approved-device"]
        )
        let resolver = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: true),
            deviceProvider: FixedDeviceCapabilityProvider(identifier: "different-device")
        )
        let availability = await resolver.availability(for: descriptor)
        XCTAssertEqual(availability, .unsupportedDevice)
    }
}
