import Foundation
import XCTest
@testable import MirageApp

final class HuggingFaceModelDownloaderTests: XCTestCase {
    func testResolvesImmutableRevisionSizeLicenseAndSupportedFiles() async throws {
        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        let metadata = """
        {
          "sha": "97ae389b962ee927d83c1911be743c8d82c11674",
          "cardData": { "license": "apache-2.0" },
          "siblings": [
            { "rfilename": "model.gguf", "size": 5, "lfs": { "sha256": "\(Data("model".utf8).sha256String)" } },
            { "rfilename": "README.md", "size": 1 }
          ]
        }
        """.data(using: .utf8)!
        let downloader = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            reference.apiURLWithBlobs.absoluteString: .init(data: metadata, finalURL: reference.apiURLWithBlobs, statusCode: 200)
        ]))

        let plan = try await downloader.resolve(reference: reference)

        XCTAssertEqual(plan.revision.commitSHA, "97ae389b962ee927d83c1911be743c8d82c11674")
        XCTAssertEqual(plan.revision.license, "apache-2.0")
        XCTAssertEqual(plan.expectedSizeBytes, 5)
        XCTAssertEqual(plan.files.map(\.path), ["model.gguf"])
    }

    func testRejectsRedirectEscapeAndMissingImmutableMetadata() async throws {
        XCTAssertTrue(HuggingFaceModelDownloader.validateRedirect(
            from: URL(string: "https://huggingface.co/a/b")!,
            to: URL(string: "https://cdn-lfs.huggingface.co/repos/file")!
        ))
        XCTAssertTrue(HuggingFaceModelDownloader.validateRedirect(
            from: URL(string: "https://huggingface.co/a/b")!,
            to: URL(string: "https://cas-bridge.xethub.hf.co/xet/file")!
        ))
        XCTAssertFalse(HuggingFaceModelDownloader.validateRedirect(
            from: URL(string: "https://huggingface.co/a/b")!,
            to: URL(string: "https://evil.example/file")!
        ))

        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        let metadata = #"{"sha":"main","cardData":{"license":"apache-2.0"},"siblings":[]}"#.data(using: .utf8)!
        let downloader = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            reference.apiURLWithBlobs.absoluteString: .init(data: metadata, finalURL: reference.apiURLWithBlobs, statusCode: 200)
        ]))

        do {
            _ = try await downloader.resolve(reference: reference)
            XCTFail("Expected immutable revision failure")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .immutableRevisionMissing)
        }
    }

    func testResolveRequestsBlobsRejectsPrivateGatedMissingHashesAndOversizedMetadata() async throws {
        let reference = try ModelRepositoryReference("owner/private-token-gated-name-is-ok")
        let privateMetadata = #"{"sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","private":true,"cardData":{"license":"mit"},"siblings":[]}"#.data(using: .utf8)!
        let privateDownloader = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            reference.apiURLWithBlobs.absoluteString: .init(data: privateMetadata, finalURL: reference.apiURLWithBlobs, statusCode: 200)
        ]))
        do {
            _ = try await privateDownloader.resolve(reference: reference)
            XCTFail("Expected private repository rejection")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .privateOrGatedRepository)
        }

        let missingHash = """
        {
          "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "private": false,
          "gated": false,
          "cardData": { "license": "mit" },
          "siblings": [
            { "rfilename": "model.gguf", "size": 5 }
          ]
        }
        """.data(using: .utf8)!
        let hashDownloader = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            reference.apiURLWithBlobs.absoluteString: .init(data: missingHash, finalURL: reference.apiURLWithBlobs, statusCode: 200)
        ]))
        do {
            _ = try await hashDownloader.resolve(reference: reference)
            XCTFail("Expected hash rejection")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .expectedHashUnavailable("model.gguf"))
        }

        let oversized = StubHFTransport(
            responses: [
                reference.apiURLWithBlobs.absoluteString: .init(
                    data: Data(repeating: 0, count: HuggingFaceModelDownloader.metadataByteLimit + 1),
                    finalURL: reference.apiURLWithBlobs,
                    statusCode: 200
                )
            ],
            enforceMetadataCap: true
        )
        do {
            _ = try await HuggingFaceModelDownloader(transport: oversized).resolve(reference: reference)
            XCTFail("Expected metadata cap rejection")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .metadataTooLarge)
        }
    }

    func testDownloadReportsProgressRejectsIntegrityFailureAndSupportsCancellation() async throws {
        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "97ae389b962ee927d83c1911be743c8d82c11674",
            license: "apache-2.0",
            totalSizeBytes: 5
        )
        let fileURL = URL(string: "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS/resolve/97ae389b962ee927d83c1911be743c8d82c11674/model.gguf")!
        let plan = ModelDownloadPlan(revision: revision, files: [
            .init(path: "model.gguf", sizeBytes: 5, sha256: Data("model".utf8).sha256String, downloadURL: fileURL)
        ])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let progress = ProgressRecorder()
        let progressExpectation = expectation(description: "Download progress reported")
        let downloader = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            fileURL.absoluteString: .init(data: Data("model".utf8), finalURL: fileURL, statusCode: 200)
        ]))

        try await downloader.download(plan: plan, to: root) { value in
            Task {
                if await progress.record(value) {
                    progressExpectation.fulfill()
                }
            }
        }
        await fulfillment(of: [progressExpectation], timeout: 1)

        let reportedProgress = await progress.values
        XCTAssertEqual(reportedProgress.last?.fractionCompleted, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("model.gguf").path))

        let bad = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            fileURL.absoluteString: .init(data: Data("wrong".utf8), finalURL: fileURL, statusCode: 200)
        ]))
        do {
            try await bad.download(plan: plan, to: root.appendingPathComponent("bad")) { _ in }
            XCTFail("Expected integrity failure")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .integrityFailed("model.gguf"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("bad").path))
    }

    func testInterruptedDownloadRemovesStagingAndRetryCanRecover() async throws {
        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "97ae389b962ee927d83c1911be743c8d82c11674",
            license: "apache-2.0",
            totalSizeBytes: 5
        )
        let fileURL = URL(string: "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS/resolve/97ae389b962ee927d83c1911be743c8d82c11674/model.gguf")!
        let plan = ModelDownloadPlan(revision: revision, files: [
            .init(path: "model.gguf", sizeBytes: 5, sha256: Data("model".utf8).sha256String, downloadURL: fileURL)
        ])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let failing = HuggingFaceModelDownloader(transport: ThrowingHFTransport(error: ModelDownloadError.cancelled))
        do {
            try await failing.download(plan: plan, to: root) { _ in }
            XCTFail("Expected cancellation")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .cancelled)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))

        let retry = HuggingFaceModelDownloader(transport: StubHFTransport(responses: [
            fileURL.absoluteString: .init(data: Data("model".utf8), finalURL: fileURL, statusCode: 200)
        ]))
        try await retry.download(plan: plan, to: root) { _ in }
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("model.gguf")), Data("model".utf8))
    }
}

private struct StubHFTransport: HFHTTPTransport {
    let responses: [String: HFHTTPResponse]
    var enforceMetadataCap = false

    func metadata(from url: URL, maxBytes: Int) async throws -> HFHTTPResponse {
        guard let response = responses[url.absoluteString] else {
            throw ModelDownloadError.transportFailed
        }
        if enforceMetadataCap, response.data.count > maxBytes {
            throw ModelDownloadError.metadataTooLarge
        }
        return response
    }

    func download(
        from url: URL,
        to destinationURL: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> HFDownloadResponse {
        guard let response = responses[url.absoluteString] else {
            throw ModelDownloadError.transportFailed
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try response.data.write(to: destinationURL)
        progress(Int64(response.data.count))
        return HFDownloadResponse(
            finalURL: response.finalURL,
            statusCode: response.statusCode,
            bytesWritten: Int64(response.data.count)
        )
    }
}

private struct ThrowingHFTransport: HFHTTPTransport {
    let error: Error

    func metadata(from url: URL, maxBytes: Int) async throws -> HFHTTPResponse {
        throw error
    }

    func download(
        from url: URL,
        to destinationURL: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> HFDownloadResponse {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("part".utf8).write(to: destinationURL)
        progress(4)
        throw error
    }
}

private actor ProgressRecorder {
    private(set) var values: [ModelDownloadProgress] = []
    private var didReportCompletion = false

    func record(_ value: ModelDownloadProgress) -> Bool {
        values.append(value)
        guard value.fractionCompleted == 1, !didReportCompletion else { return false }
        didReportCompletion = true
        return true
    }
}
