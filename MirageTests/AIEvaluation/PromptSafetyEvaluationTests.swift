import Foundation
import XCTest
@testable import MirageApp

final class PromptSafetyEvaluationTests: XCTestCase {
    private struct FixtureFile: Decodable {
        let version: String
        let policyVersion: String
        let cases: [Fixture]
    }

    private struct Fixture: Decodable {
        let id: String
        let category: String
        let prompt: String
        let expected: String
    }

    func testVersionedPromptSafetyCorpus() throws {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(
            forResource: "PromptSafetyFixtures",
            withExtension: "json",
            subdirectory: "AIEvaluation"
        ) ?? bundle.url(forResource: "PromptSafetyFixtures", withExtension: "json")
        let fixtureURL = try XCTUnwrap(url)
        let fixture = try JSONDecoder().decode(FixtureFile.self, from: Data(contentsOf: fixtureURL))
        XCTAssertEqual(fixture.policyVersion, PromptSafetyPolicy.version)
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 8)

        for testCase in fixture.cases {
            let allowed = (try? PromptSafetyPolicy.current.validatedPrompt(testCase.prompt)) != nil
            XCTAssertEqual(
                allowed,
                testCase.expected == "allow",
                "Prompt safety fixture failed: \(testCase.id) [\(testCase.category)]"
            )
        }
    }
}
