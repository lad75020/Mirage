import XCTest
@testable import MirageApp

final class ImageGenerationPerformanceTests: XCTestCase {
    func testCatalogAndPromptPolicyStayLightweight() {
        measure {
            for _ in 0..<1_000 {
                _ = ModelCatalog.descriptor(for: .ernieImageTurbo)
                _ = try? PromptSafetyPolicy.current.validatedPrompt("A studio portrait made of folded paper")
            }
        }
    }
}
