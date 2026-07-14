import Foundation
import Photos
import XCTest
@testable import MirageApp

private actor StubPhotoLibraryClient: PhotoLibraryClient {
    var status: PhotoAuthorizationState
    var requestedStatus: PhotoAuthorizationState
    private(set) var assets: [Data] = []

    init(status: PhotoAuthorizationState, requestedStatus: PhotoAuthorizationState = .authorized) {
        self.status = status
        self.requestedStatus = requestedStatus
    }

    func authorizationStatus() async -> PhotoAuthorizationState { status }

    func requestAddAuthorization() async -> PhotoAuthorizationState {
        status = requestedStatus
        return requestedStatus
    }

    func createAsset(from data: Data) async throws {
        assets.append(data)
    }

    func assetCount() -> Int { assets.count }
}

final class PhotoLibrarySaverTests: XCTestCase {
    func testRequestsAddAuthorizationAndCreatesExactlyOneAsset() async throws {
        let client = StubPhotoLibraryClient(status: .notDetermined)
        let saver = PhotoLibrarySaver(client: client)

        let firstResult = try await saver.savePNG(onePixelPNG)
        let secondResult = try await saver.savePNG(onePixelPNG)
        let assetCount = await client.assetCount()
        XCTAssertEqual(firstResult, .saved)
        XCTAssertEqual(secondResult, .alreadySaved)
        XCTAssertEqual(assetCount, 1)
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
