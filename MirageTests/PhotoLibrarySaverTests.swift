import Foundation
import Photos
import XCTest
@testable import MirageApp

private actor StubPhotoLibraryClient: PhotoLibraryClient {
    var status: PhotoAuthorizationState
    var requestedStatus: PhotoAuthorizationState
    private(set) var assets: [Data] = []
    private(set) var filenames: [String] = []

    init(status: PhotoAuthorizationState, requestedStatus: PhotoAuthorizationState = .authorized) {
        self.status = status
        self.requestedStatus = requestedStatus
    }

    func authorizationStatus() async -> PhotoAuthorizationState { status }

    func requestAddAuthorization() async -> PhotoAuthorizationState {
        status = requestedStatus
        return requestedStatus
    }

    func createPNGAsset(from data: Data, filename: String) async throws {
        assets.append(data)
        filenames.append(filename)
    }

    func assetCount() -> Int { assets.count }
    func createdFilenames() -> [String] { filenames }
}

final class PhotoLibrarySaverTests: XCTestCase {
    func testRequestsAddAuthorizationAndCreatesExactlyOneAsset() async throws {
        let client = StubPhotoLibraryClient(status: .notDetermined)
        let saver = PhotoLibrarySaver(client: client)

        let firstResult = try await saver.savePNG(onePixelPNG)
        let secondResult = try await saver.savePNG(onePixelPNG)
        let assetCount = await client.assetCount()
        let filenames = await client.createdFilenames()
        XCTAssertEqual(firstResult, .saved)
        XCTAssertEqual(secondResult, .alreadySaved)
        XCTAssertEqual(assetCount, 1)
        XCTAssertEqual(filenames.count, 1)
        XCTAssertTrue(filenames[0].hasPrefix("Mirage-"))
        XCTAssertTrue(filenames[0].hasSuffix(".png"))
    }

    func testDeniedAuthorizationDoesNotCreateAsset() async {
        let client = StubPhotoLibraryClient(status: .denied)
        let saver = PhotoLibrarySaver(client: client)

        await XCTAssertThrowsErrorAsync { try await saver.savePNG(onePixelPNG) }
        let assetCount = await client.assetCount()
        XCTAssertEqual(assetCount, 0)
    }

    func testMalformedDataIsRejected() async {
        let client = StubPhotoLibraryClient(status: .authorized)
        let saver = PhotoLibrarySaver(client: client)

        await XCTAssertThrowsErrorAsync { try await saver.savePNG(Data("not-png".utf8)) }
        let assetCount = await client.assetCount()
        XCTAssertEqual(assetCount, 0)
    }
}
