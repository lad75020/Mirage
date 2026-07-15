import Foundation
import XCTest
@testable import MirageApp

final class ModelRepositoryReferenceTests: XCTestCase {
    func testNormalizesOwnerRepositoryAndFullHuggingFaceURL() throws {
        XCTAssertEqual(try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS").id, "jc-builds/Z-Image-Turbo-iOS")
        XCTAssertEqual(
            try ModelRepositoryReference("https://huggingface.co/jc-builds/Chroma1-HD-iOS/").id,
            "jc-builds/Chroma1-HD-iOS"
        )
        XCTAssertEqual(try ModelRepositoryReference("private-owner/token-gated-model").id, "private-owner/token-gated-model")
    }

    func testRejectsCredentialsQueryFragmentMalformedPrivateGatedAndNonHuggingFaceReferences() {
        let invalid = [
            "",
            "one-part",
            "https://user:pass@huggingface.co/jc-builds/Z-Image-Turbo-iOS",
            "https://huggingface.co:443/jc-builds/Z-Image-Turbo-iOS",
            "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS?download=1",
            "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS#files",
            "https://example.com/jc-builds/Z-Image-Turbo-iOS",
            "https://www.huggingface.co/jc-builds/Z-Image-Turbo-iOS",
            "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS/tree/main",
            "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS/blob/main/model.gguf",
            "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS/resolve/main/model.gguf",
            "https://huggingface.co/jc-builds%2fZ-Image-Turbo-iOS",
            "https://huggingface.co/jc-builds/Z-Image-Turbo-iOS%2fresolve",
            "https://huggingface.co/jc-builds/%2e%2e"
        ]

        for reference in invalid {
            XCTAssertThrowsError(try ModelRepositoryReference(reference), reference)
        }
    }

    func testResolvedRevisionRequiresImmutableCommitSHA() throws {
        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        XCTAssertNoThrow(try ResolvedModelRevision(
            reference: reference,
            commitSHA: "97ae389b962ee927d83c1911be743c8d82c11674",
            license: "apache-2.0",
            totalSizeBytes: 1
        ))
        XCTAssertThrowsError(try ResolvedModelRevision(
            reference: reference,
            commitSHA: "main",
            license: "apache-2.0",
            totalSizeBytes: 1
        ))
    }
}
