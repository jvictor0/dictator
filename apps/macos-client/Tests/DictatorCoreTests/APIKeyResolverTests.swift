import XCTest
@testable import DictatorCore

final class APIKeyResolverTests: XCTestCase {
    func testResolvePrefersDictatorEnvKey() {
        let key = APIKeyResolver.resolve(
            environment: [
                "DICTATOR_OPENAI_API_KEY": "dictator-key",
                "OPENAI_API_KEY": "openai-key"
            ],
            fallback: {
                XCTFail("Fallback should not run when env key is present")
                return nil
            }
        )

        XCTAssertEqual(key, "dictator-key")
    }

    func testResolveUsesOpenAIEnvKeyWhenDictatorMissing() {
        let key = APIKeyResolver.resolve(
            environment: ["OPENAI_API_KEY": "openai-key"],
            fallback: {
                XCTFail("Fallback should not run when env key is present")
                return nil
            }
        )

        XCTAssertEqual(key, "openai-key")
    }

    func testResolveFallsBackWhenEnvironmentMissing() {
        let key = APIKeyResolver.resolve(
            environment: [:],
            fallback: { "keychain-key" }
        )

        XCTAssertEqual(key, "keychain-key")
    }
}
