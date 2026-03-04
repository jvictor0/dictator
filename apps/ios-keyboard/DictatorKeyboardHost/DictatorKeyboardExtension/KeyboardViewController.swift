import AVFoundation
import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum DictationState {
        case idle
        case recording
        case waitingForServer
        case error(String)
    }

    private struct DictateAudioResponse: Decodable {
        let raw_transcript: String
        let revised_text: String
        let edit_summary: String
        let uncertainty_flags: [String]
        let transcribe_ms: Int
        let refine_ms: Int
    }

    private let recorder = AudioSnippetRecorder()
    private let nextKeyboardButton = UIButton(type: .system)
    private let dictationButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var state: DictationState = .idle {
        didSet {
            renderState()
        }
    }
    private let sessionID = UUID().uuidString

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        renderState()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
    }

    @objc
    private func handleDictationTap() {
        switch state {
        case .idle, .error:
            startRecording()
        case .recording:
            Task {
                await finishRecordingAndSend()
            }
        case .waitingForServer:
            return
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemGray6

        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for globe button"), for: .normal)
        nextKeyboardButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.textColor = .secondaryLabel

        dictationButton.translatesAutoresizingMaskIntoConstraints = false
        dictationButton.setTitle("Start Dictation", for: .normal)
        dictationButton.titleLabel?.font = .boldSystemFont(ofSize: 22)
        dictationButton.layer.cornerRadius = 18
        dictationButton.layer.borderWidth = 2
        dictationButton.layer.borderColor = UIColor.systemGray3.cgColor
        dictationButton.addTarget(self, action: #selector(handleDictationTap), for: .touchUpInside)

        view.addSubview(nextKeyboardButton)
        view.addSubview(statusLabel)
        view.addSubview(dictationButton)

        NSLayoutConstraint.activate([
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            statusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            dictationButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            dictationButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dictationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dictationButton.heightAnchor.constraint(equalToConstant: 68),
            dictationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func startRecording() {
        do {
            try recorder.start()
            state = .recording
        } catch {
            state = .error(microphoneErrorMessage(error))
        }
    }

    @MainActor
    private func finishRecordingAndSend() async {
        state = .waitingForServer
        let wavData: Data
        do {
            wavData = try recorder.stopAndBuildWAV()
        } catch {
            state = .error("Mic stop failed: \(error.localizedDescription)")
            return
        }

        let baseURL = loadBaseURL()

        do {
            let response = try await uploadSnippet(wavData: wavData, baseURL: baseURL)
            if response.revised_text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state = .error("Server returned empty revised text.")
                return
            }
            textDocumentProxy.insertText(response.revised_text)
            state = .idle
        } catch {
            state = .error("Request failed: \(error.localizedDescription)")
        }
    }

    private func uploadSnippet(wavData: Data, baseURL: URL) async throws -> DictateAudioResponse {
        var endpoint = baseURL
        endpoint.appendPathComponent("v1")
        endpoint.appendPathComponent("dictate-audio")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.setValue("16000", forHTTPHeaderField: "X-Sample-Rate")
        request.setValue("en-US", forHTTPHeaderField: "X-Locale")
        request.setValue(sessionID, forHTTPHeaderField: "X-Session-Id")
        request.httpBodyStream = InputStream(data: wavData)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "DictatorKeyboard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "DictatorKeyboard", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
        }
        return try JSONDecoder().decode(DictateAudioResponse.self, from: data)
    }

    private func loadBaseURL() -> URL {
        let resolved = SharedConfig.resolvedServerURLString(bundle: .main)
        return URL(string: resolved) ?? URL(string: SharedConfig.fallbackServerURL)!
    }

    private func microphoneErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain {
            return "Mic unavailable in keyboard extension (OSStatus \(nsError.code)). iOS may block microphone capture for custom keyboards."
        }
        return "Mic start failed: \(nsError.localizedDescription)"
    }

    private func renderState() {
        switch state {
        case .idle:
            statusLabel.text = "Ready"
            dictationButton.isEnabled = true
            dictationButton.setTitle("Start Dictation", for: .normal)
            dictationButton.backgroundColor = .white
            dictationButton.setTitleColor(.black, for: .normal)
        case .recording:
            statusLabel.text = "Recording..."
            dictationButton.isEnabled = true
            dictationButton.setTitle("Stop Recording", for: .normal)
            dictationButton.backgroundColor = .systemRed
            dictationButton.setTitleColor(.white, for: .normal)
        case .waitingForServer:
            statusLabel.text = "Waiting for Dictator server..."
            dictationButton.isEnabled = false
            dictationButton.setTitle("Processing...", for: .normal)
            dictationButton.backgroundColor = .systemBlue
            dictationButton.setTitleColor(.white, for: .normal)
        case let .error(message):
            statusLabel.text = message
            dictationButton.isEnabled = true
            dictationButton.setTitle("Retry Dictation", for: .normal)
            dictationButton.backgroundColor = .white
            dictationButton.setTitleColor(.black, for: .normal)
        }
    }
}

private final class AudioSnippetRecorder {
    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private let lock = NSLock()
    private var pcmData = Data()
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var isRecording = false

    func start() throws {
        guard !isRecording else {
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: [])

        let inputNode = engine.inputNode
        let sourceFormat = inputNode.outputFormat(forBus: 0)
        guard let destinationFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "DictatorKeyboard", code: 100, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio format"])
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            throw NSError(domain: "DictatorKeyboard", code: 101, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio converter"])
        }
        self.converter = converter
        inputFormat = sourceFormat
        lock.lock()
        pcmData.removeAll(keepingCapacity: true)
        lock.unlock()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: sourceFormat) { [weak self] buffer, _ in
            self?.capture(buffer: buffer, converter: converter, destinationFormat: destinationFormat)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stopAndBuildWAV() throws -> Data {
        guard isRecording else {
            throw NSError(domain: "DictatorKeyboard", code: 102, userInfo: [NSLocalizedDescriptionKey: "Recorder is not running"])
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRecording = false

        lock.lock()
        let pcm = pcmData
        lock.unlock()
        guard !pcm.isEmpty else {
            throw NSError(domain: "DictatorKeyboard", code: 103, userInfo: [NSLocalizedDescriptionKey: "No audio captured"])
        }
        return Self.makeWAV(pcm16MonoData: pcm, sampleRate: Int(targetSampleRate))
    }

    private func capture(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, destinationFormat: AVAudioFormat) {
        let expectedFrames = AVAudioFrameCount((Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate).rounded(.up))
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: destinationFormat,
            frameCapacity: max(expectedFrames, 1)
        ) else {
            return
        }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            } else {
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }
        }

        guard conversionError == nil, status == .haveData else {
            return
        }
        guard let channelData = converted.int16ChannelData else {
            return
        }

        let frameLength = Int(converted.frameLength)
        let byteCount = frameLength * MemoryLayout<Int16>.size
        let pointer = UnsafeRawPointer(channelData.pointee)
        lock.lock()
        pcmData.append(pointer.assumingMemoryBound(to: UInt8.self), count: byteCount)
        lock.unlock()
    }

    private static func makeWAV(pcm16MonoData: Data, sampleRate: Int) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let blockAlign = UInt16(channels * (bitsPerSample / 8))
        let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
        let dataSize = UInt32(pcm16MonoData.count)
        let riffSize = UInt32(36) + dataSize

        var data = Data(capacity: Int(riffSize) + 8)
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        data.append(contentsOf: riffSize.littleEndianBytes)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        data.append(contentsOf: UInt32(16).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes) // PCM
        data.append(contentsOf: channels.littleEndianBytes)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: byteRate.littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        data.append(contentsOf: dataSize.littleEndianBytes)
        data.append(pcm16MonoData)
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian, Array.init)
    }
}
