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
        let downloader = HuggingFaceModelDownloader(fileDownloader: StubHFFileDownloader(responses: [
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
        let manifestData = try Data(contentsOf: root.appendingPathComponent(VerifiedDownloadManifest.fileName))
        let manifest = try JSONDecoder().decode(VerifiedDownloadManifest.self, from: manifestData)
        XCTAssertTrue(manifest.matches(plan, rootURL: root))

        let bad = HuggingFaceModelDownloader(fileDownloader: StubHFFileDownloader(responses: [
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

        let failing = HuggingFaceModelDownloader(fileDownloader: ThrowingHFFileDownloader(error: ModelDownloadError.cancelled))
        do {
            try await failing.download(plan: plan, to: root) { _ in }
            XCTFail("Expected cancellation")
        } catch let error as ModelDownloadError {
            XCTAssertEqual(error, .cancelled)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))

        let retry = HuggingFaceModelDownloader(fileDownloader: StubHFFileDownloader(responses: [
            fileURL.absoluteString: .init(data: Data("model".utf8), finalURL: fileURL, statusCode: 200)
        ]))
        try await retry.download(plan: plan, to: root) { _ in }
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("model.gguf")), Data("model".utf8))
    }

    func testURLSessionFileDownloadStateReportsProgressBeforeCompletion() async throws {
        let state = URLSessionFileDownloadState()
        let sessionTask = URLSession.shared.dataTask(with: URL(string: "https://huggingface.co")!)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("mirage-progress-\(UUID().uuidString).gguf")
        defer { try? FileManager.default.removeItem(at: destination) }
        let progress = Progress(totalUnitCount: 10)

        let completionTask = Task {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                do {
                    try state.register(
                        continuation: continuation,
                        task: sessionTask,
                        destinationURL: destination,
                        progress: progress
                    )
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        for _ in 0..<100 where !FileManager.default.fileExists(atPath: destination.path) {
            try await Task.sleep(for: .milliseconds(5))
        }
        state.receiveResponse(sessionTask)
        XCTAssertNil(state.append(sessionTask, data: Data("12345".utf8)))
        XCTAssertEqual(progress.completedUnitCount, 5, "Progress must advance while the transfer is active")

        XCTAssertNil(state.append(sessionTask, data: Data("67890".utf8)))
        state.complete(sessionTask, error: nil)
        _ = try await completionTask.value
        XCTAssertEqual(progress.completedUnitCount, 10)
        XCTAssertEqual(try Data(contentsOf: destination), Data("1234567890".utf8))
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
}

private struct StubHFFileDownloader: HFHubFileDownloading {
    let responses: [String: HFHTTPResponse]

    func downloadFile(
        reference: ModelRepositoryReference,
        revision: String,
        path: String,
        to destinationURL: URL,
        progress: Progress
    ) async throws -> URL {
        let url = "https://huggingface.co/\(reference.id)/resolve/\(revision)/\(path)"
        guard let response = responses[url] else {
            throw ModelDownloadError.transportFailed
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try response.data.write(to: destinationURL)
        progress.totalUnitCount = Int64(response.data.count)
        progress.completedUnitCount = Int64(response.data.count)
        return destinationURL
    }
}

private struct ThrowingHFFileDownloader: HFHubFileDownloading {
    let error: Error

    func downloadFile(
        reference: ModelRepositoryReference,
        revision: String,
        path: String,
        to destinationURL: URL,
        progress: Progress
    ) async throws -> URL {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("part".utf8).write(to: destinationURL)
        progress.completedUnitCount = 4
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
