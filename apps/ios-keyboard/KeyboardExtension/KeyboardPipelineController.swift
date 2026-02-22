import Foundation

final class KeyboardPipelineController {
    enum PipelineError: Error {
        case notImplemented
    }

    func runDictation(audioData: Data, sampleRate: Int, locale: String, sessionID: String) async throws -> String {
        _ = (audioData, sampleRate, locale, sessionID)
        throw PipelineError.notImplemented
    }
}
