import DictatorCore
import Foundation

final class KeyboardPipelineController {
    private let coreClient: any DictatorCoreClient

    init(coreClient: any DictatorCoreClient) {
        self.coreClient = coreClient
    }

    func runDictation(audioData: Data, sampleRate: Int, locale: String, sessionID: String) async throws -> DictateCallResult {
        try await coreClient.dictate(
            DictateRequest(
                audio_b64: audioData.base64EncodedString(),
                sample_rate: sampleRate,
                locale: locale,
                session_id: sessionID
            )
        )
    }
}
