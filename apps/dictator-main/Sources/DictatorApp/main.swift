import AppKit
import Darwin
import DictatorAppShared
import DictatorCore

final class DictatorAppDelegate: NSObject, NSApplicationDelegate {
    private enum DictationState {
        case idle
        case recording
        case thinking
    }

    private enum InteractionMode {
        case standard
        case talonLite
    }

    private enum ShiftLatchState {
        case unpressed
        case pressedWillLatchOnRelease
        case pressedNoLatchOnRelease
        case latched
    }

    private static let backspaceKeyCode: UInt16 = 51
    private static let upArrowKeyCode: UInt16 = 126
    private static let downArrowKeyCode: UInt16 = 125
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let cancelDebounceSeconds: TimeInterval = 0.15
    private static let arrowCycleDebounceSeconds: TimeInterval = 0.03

    private var menuBarController: MenuBarController?
    private var capsLockTriggerController: CapsLockTriggerController?
    private var backspaceGlobalMonitor: Any?
    private var backspaceLocalMonitor: Any?
    private var launchpadArrowGlobalMonitor: Any?
    private var launchpadArrowLocalMonitor: Any?
    private var launchpadArrowInterceptionLifecycle = LaunchpadArrowCycleInterceptionLifecycle()
    private let recordingController = RecordingController()
    private let audioRecorder = AudioRecorder()
    private let activeTargetContextProvider = ActiveTargetContextProvider()
    private lazy var keyboardInjector: KeyboardInjector = KeyboardInjector { [weak self] result in
        DispatchQueue.main.async {
            self?.handleKeyboardDispatchResult(result)
        }
    }
    private lazy var runtimeConfigStore: RuntimeConfigStore = RuntimeConfigStore(
        fileURL: RuntimeConfigStore.defaultFileURL()
    )
    private lazy var safeRuntimeConfigStore: RuntimeConfigStore = RuntimeConfigStore(
        fileURL: RuntimeConfigStore.defaultSafeFileURL()
    )
    private lazy var secretsFileStore: SecretsStore = SecretsStore()
    private let inMemorySecretStore = InMemorySecretStore()
    private lazy var secretStore: any SecretStore = inMemorySecretStore
    private lazy var runtimeConfigProvider: RuntimeConfigProvider = RuntimeConfigProvider(
        store: runtimeConfigStore,
        defaultStore: safeRuntimeConfigStore
    )
    private lazy var sttEngine: WhisperCPPBridgeSTTEngine = {
        let startupConfig = try? runtimeConfigStore.load()
        let fallbackConfig = try? safeRuntimeConfigStore.load()
        let resolved = startupConfig ?? fallbackConfig ?? RuntimeConfigFile.bootstrap()
        return WhisperCPPBridgeSTTEngine(
            configuration: .init(
                modelPath: resolved.resolvedSTTModelPath(),
                language: resolved.sttLanguage
            )
        )
    }()
    private lazy var coreClient: any DictatorCoreClient = PipelineOrchestrator(
        sttEngine: sttEngine,
        refinementEngine: makeRefinementEngine()
    )
    private lazy var apiClient: APIClient = APIClient(coreClient: coreClient)
    private lazy var talonLiteCorrectionEngine: TalonLiteLLMCorrectionEngine = RuntimeConfigTalonLiteLLMCorrectionEngine(
        runtimeConfigProvider: runtimeConfigProvider,
        secretStore: secretStore,
        canUseOpenAI: { [weak self] in
            self?.hasOpenAIKey() ?? false
        }
    )
    private lazy var talonLiteOrchestrator: TalonLitePipelineOrchestrator = TalonLitePipelineOrchestrator(
        sttEngine: sttEngine,
        correctionEngine: talonLiteCorrectionEngine,
        trace: { message in
            TraceLogger.log(message)
        }
    )

    private let sessionID = UUID().uuidString
    private var isHandlingTrigger = false
    private var recordingContext: [String: String]?
    private var lastCancelTimestamp: TimeInterval?
    private var launchpadMIDIManager: LaunchpadMIDIManager?
    private var launchpadPageController: LaunchpadPageController?
    private var launchpadRenderWorker: LaunchpadColorRenderWorker?
    private var launchpadInvalidationBus: RenderInvalidationBus?
    private var launchpadOverlayController: LaunchpadFullscreenOverlayController?
    private var launchpadOverlayTabSlotCoordinator: LaunchpadOverlayTabSlotCoordinator?
    private var launchpadAppCycleState = LaunchpadAppCycleState()
    private var lastArrowCycleDispatch: (keyCode: UInt16, timestamp: TimeInterval)?
    private lazy var launchpadArrowEventTapController = LaunchpadArrowCycleEventTapController(
        isHoldCycleSessionActive: { [weak self] in
            guard let self else {
                return false
            }
            return self.launchpadAppCycleState.isActive && self.launchpadArrowInterceptionLifecycle.path == .eventTap
        },
        onArrowKeyDown: { [weak self] keyCode, timestamp in
            DispatchQueue.main.async {
                self?.handleLaunchpadArrowCycleKeyDown(keyCode: keyCode, timestamp: timestamp, source: "event_tap")
            }
        }
    )
    private var managedOllamaProcess: Process?
    private var isRelaunching = false
    private let dictationStateLock = NSLock()
    private var dictationState: DictationState = .idle
    private var activeDictationTask: Task<DictateCallResult, Error>?
    private var activeInteractionMode: InteractionMode = .standard
    private let shiftLatchStateLock = NSLock()
    private var shiftLatchState: ShiftLatchState = .unpressed
    private var runtimeConfigurationManager: RuntimeConfigurationManager?
    private let interactionBuffer = DictationInteractionBuffer()
    private var interactionStore: InteractionHistoryStore?
    private var interactionStoreSetupTask: Task<Void, Never>?
    private var interactionsOverlayTab: LaunchpadInteractionsOverlayTab?
    private var secretsLoadError: String?
    private var dictationServer: DictationHTTPServer?

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        TraceLogger.reset()
        TraceLogger.log("app did finish launching")
        TraceLogger.log("trace file: \(TraceLogger.path)")
        bootstrapSecretsInMemory()

        let menuBarController = MenuBarController()
        menuBarController.onSetAPIKey = { [weak self] in
            self?.promptForAPIKey(menuBarController: menuBarController)
        }
        menuBarController.onClearAPIKey = { [weak self] in
            self?.clearAPIKey(menuBarController: menuBarController)
        }
        self.menuBarController = menuBarController
        Task { @MainActor in
            await self.bootstrapOllamaIfNeeded()
        }

        let triggerController = CapsLockTriggerController { [weak menuBarController, weak self] in
            guard let self else {
                return
            }
            Task { @MainActor in
                await self.handleCapsTrigger(menuBarController: menuBarController)
            }
        }

        self.capsLockTriggerController = triggerController
        armBackspaceCancelMonitors()
        if triggerController.start() {
            Task { @MainActor in
                menuBarController.setState(await startupReadyMessage())
            }
            TraceLogger.log("app ready: caps lock trigger armed")
        } else {
            menuBarController.setState("Failed: Accessibility permission missing")
            TraceLogger.log("app startup failed: caps lock trigger not armed")
        }

        Task { @MainActor in
            self.setupLaunchpadIntegration()
        }

        Task { @MainActor in
            do {
                _ = try await self.runtimeConfigurationManagerInstance()
                await self.setupInteractionStoreIfNeeded()
            } catch {
                TraceLogger.log("runtime configuration manager startup failed: \(error)")
            }
        }

        startDictationServerIfEnabled()
    }

    func applicationWillTerminate(_ notification: Notification) {
        disarmBackspaceCancelMonitors()
        disarmLaunchpadArrowCycleInterception()
        managedOllamaProcess?.terminate()
        managedOllamaProcess = nil
        launchpadRenderWorker?.stop()
        launchpadMIDIManager?.stop()
        if let dictationServer {
            Task {
                await dictationServer.stop()
            }
        }
    }

    private func startDictationServerIfEnabled() {
        let startupConfig = (try? runtimeConfigStore.load()) ?? (try? safeRuntimeConfigStore.load()) ?? RuntimeConfigFile.bootstrap()
        guard startupConfig.dictatorServerEnabled else {
            TraceLogger.log("dictation HTTP server disabled by config")
            return
        }

        let server = DictationHTTPServer(
            host: startupConfig.dictatorServerHost,
            port: startupConfig.dictatorServerPort,
            coreClient: coreClient,
            onSuccessRecord: { [weak self] record in
                guard let self else {
                    return
                }
                await self.appendAPIInteraction(record)
            },
            onFailureRecord: { [weak self] record in
                guard let self else {
                    return
                }
                await self.appendAPIFailedInteraction(record)
            }
        )
        dictationServer = server
        Task {
            do {
                try await server.start()
                TraceLogger.log("dictation HTTP server listening on \(server.bindDescription)")
            } catch {
                TraceLogger.log("dictation HTTP server failed to start: \(error)")
            }
        }
    }

    @MainActor
    private func handleCapsTrigger(menuBarController: MenuBarController?) async {
        if isHandlingTrigger {
            TraceLogger.log("caps-trigger ignored: previous trigger still in progress")
            menuBarController?.setState("Busy: finishing previous action")
            return
        }

        isHandlingTrigger = true
        defer { isHandlingTrigger = false }

        TraceLogger.log("caps-trigger callback started")

        if recordingController.isRecording {
            await stopRecordingAndProcess(menuBarController: menuBarController)
        } else {
            await startRecording(menuBarController: menuBarController, mode: .standard)
        }
    }

    @MainActor
    private func startRecording(menuBarController: MenuBarController?, mode: InteractionMode) async {
        menuBarController?.setState("Starting recording...")
        switch await audioRecorder.start() {
        case .success:
            var context = activeTargetContextProvider.captureContext() ?? [:]

            switch ClipboardInserter.captureSelectedText() {
            case let .success(selectedText):
                if let selectedText {
                    context["selected_text"] = selectedText
                    TraceLogger.log("captured selected text (chars=\(selectedText.count))")
                } else {
                    TraceLogger.log("captured selected text: <none>")
                }
            case let .failure(error):
                TraceLogger.log("selected text capture failed: \(error)")
            }

            recordingContext = context.isEmpty ? nil : context
            activeInteractionMode = mode
            if let dictationContext = recordingContext?["dictation_context"] {
                TraceLogger.log("captured recording context: \(dictationContext)")
            } else {
                TraceLogger.log("captured recording context: unavailable")
            }
            _ = recordingController.toggle()
            setDictationState(.recording)
            menuBarController?.setIndicatorState(.recording)
            menuBarController?.setState("Recording")
            TraceLogger.log("recording started")
        case let .failure(error):
            recordingContext = nil
            activeInteractionMode = .standard
            setDictationState(.idle)
            menuBarController?.setIndicatorState(.idle)
            menuBarController?.setState("Failed: \(Self.recordingFailureMessage(for: error))")
            TraceLogger.log("recording start failed: \(error)")
        }
    }

    @MainActor
    private func cancelRecording(menuBarController: MenuBarController?) {
        guard recordingController.isRecording else {
            return
        }

        _ = recordingController.toggle()
        recordingContext = nil
        activeInteractionMode = .standard
        _ = audioRecorder.stop()
        cancelActiveDictationTask()
        setDictationState(.idle)
        menuBarController?.setIndicatorState(.idle)
        menuBarController?.setState("Recording canceled")
        TraceLogger.log("recording canceled via backspace")
    }

    private func armBackspaceCancelMonitors() {
        backspaceGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleBackspaceCancel(event: event, source: "global")
        }
        backspaceLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleBackspaceCancel(event: event, source: "local")
            return event
        }
        TraceLogger.log(
            "backspace-cancel monitors armed (global=\(backspaceGlobalMonitor != nil), local=\(backspaceLocalMonitor != nil))"
        )
    }

    private func disarmBackspaceCancelMonitors() {
        if let backspaceGlobalMonitor {
            NSEvent.removeMonitor(backspaceGlobalMonitor)
            self.backspaceGlobalMonitor = nil
        }
        if let backspaceLocalMonitor {
            NSEvent.removeMonitor(backspaceLocalMonitor)
            self.backspaceLocalMonitor = nil
        }
        TraceLogger.log("backspace-cancel monitors removed")
    }

    private func handleBackspaceCancel(event: NSEvent, source: String) {
        guard event.type == .keyDown, event.keyCode == Self.backspaceKeyCode else {
            return
        }
        guard recordingController.isRecording else {
            return
        }
        if let lastCancelTimestamp, (event.timestamp - lastCancelTimestamp) <= Self.cancelDebounceSeconds {
            return
        }
        lastCancelTimestamp = event.timestamp
        TraceLogger.log("recording cancel trigger fired via backspace (source=\(source))")
        Task { @MainActor in
            self.cancelRecording(menuBarController: self.menuBarController)
        }
    }

    @MainActor
    private func stopRecordingAndProcess(menuBarController: MenuBarController?) async {
        _ = recordingController.toggle()
        menuBarController?.setIndicatorState(.idle)
        menuBarController?.setState("Stopping recording...")

        let stopResult = audioRecorder.stop()
        switch stopResult {
        case let .failure(error):
            setDictationState(.idle)
            menuBarController?.setState("Failed: \(Self.recordingFailureMessage(for: error))")
            TraceLogger.log("recording stop failed: \(error)")
            return
        case let .success(capturedAudio):
            let interactionMode = activeInteractionMode
            let requestContext = recordingContext
            recordingContext = nil
            activeInteractionMode = .standard
            let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
            TraceLogger.log("recording stopped (bytes=\(capturedAudio.data.count), sampleRate=\(capturedAudio.sampleRate))")
            setDictationState(.thinking)
            menuBarController?.setIndicatorState(.refining)
            switch interactionMode {
            case .standard:
                menuBarController?.setState("Transcribing + refining...")
            case .talonLite:
                menuBarController?.setState("Transcribing Talon command...")
            }

            do {
                let runtimeConfiguration = await runtimeConfigProvider.currentConfiguration()
                let runtimeConfig = await runtimeConfigProvider.currentRuntimeConfig()
                let pipelineStart = Date()
                let task = Task { [apiClient, talonLiteOrchestrator] in
                    switch interactionMode {
                    case .standard:
                        let request = DictateRequest(
                            audio_b64: capturedAudio.data.base64EncodedString(),
                            sample_rate: capturedAudio.sampleRate,
                            locale: locale,
                            session_id: sessionID,
                            optional_context: requestContext
                        )
                        return try await apiClient.dictate(request)
                    case .talonLite:
                        let transcribeRequest = TranscribeRequest(
                            audio_b64: capturedAudio.data.base64EncodedString(),
                            sample_rate: capturedAudio.sampleRate,
                            locale: locale,
                            session_id: sessionID
                        )
                        let processed = try await talonLiteOrchestrator.process(transcribeRequest)
                        let summary: String
                        let flags: [String]
                        if processed.wasLLMCorrected {
                            summary = "Talon-lite pipeline rendered after LLM correction."
                            flags = ["talon_lite_llm_corrected"]
                            TraceLogger.log("talon-lite corrected transcript: \(Self.logSafeText(processed.grammarTranscript))")
                        } else {
                            summary = "Talon-lite pipeline rendered without LLM correction."
                            flags = []
                        }
                        return DictateCallResult(
                            response: DictateResponse(
                                raw_transcript: processed.rawTranscript,
                                revised_text: processed.outputText,
                                edit_summary: summary,
                                uncertainty_flags: flags
                            ),
                            transcribeMs: processed.transcribeMs,
                            refineMs: max(0, processed.pipelineMs - processed.transcribeMs)
                        )
                    }
                }
                setActiveDictationTask(task)
                let dictatedCall = try await task.value
                clearActiveDictationTask(task)
                let dictated = dictatedCall.response
                let modeTag = interactionMode == .talonLite ? "talon-lite" : "dictate"
                TraceLogger.log(
                    "\(modeTag) success (rawChars=\(dictated.raw_transcript.count), revisedChars=\(dictated.revised_text.count), transcribeMs=\(dictatedCall.transcribeMs), refineMs=\(dictatedCall.refineMs), summary=\(dictated.edit_summary))"
                )
                if interactionMode == .standard {
                    logRefinementMode(context: requestContext)
                }
                TraceLogger.log("dictate raw transcript: \(Self.logSafeText(dictated.raw_transcript))")
                TraceLogger.log("dictate revised text: \(Self.logSafeText(dictated.revised_text))")
                let totalPipelineMs = Self.elapsedMs(since: pipelineStart)
                if dictated.revised_text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await appendInteraction(
                        dictatedCall: dictatedCall,
                        optionalContext: requestContext,
                        runtimeConfiguration: runtimeConfiguration,
                        runtimeConfig: runtimeConfig,
                        insertMs: 0,
                        totalPipelineMs: totalPipelineMs
                    )
                    setDictationState(.idle)
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("No speech detected")
                    TraceLogger.log("dictate produced empty revised text; skipping insertion")
                    return
                }
                let insertStart = Date()
                let insertResult = ClipboardInserter.insert(dictated.revised_text)
                let insertMs = Self.elapsedMs(since: insertStart)
                await appendInteraction(
                    dictatedCall: dictatedCall,
                    optionalContext: requestContext,
                    runtimeConfiguration: runtimeConfiguration,
                    runtimeConfig: runtimeConfig,
                    insertMs: insertMs,
                    totalPipelineMs: totalPipelineMs
                )
                switch insertResult {
                case .success:
                    setDictationState(.idle)
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState(interactionMode == .talonLite ? "Inserted Talon text" : "Inserted revised text")
                case let .failure(error):
                    setDictationState(.idle)
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("Failed: \(Self.failureMessage(for: error))")
                    TraceLogger.log("revised text insert failed: \(error)")
                }
            } catch {
                cancelActiveDictationTask()
                setDictationState(.idle)
                if error is CancellationError {
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("Thinking canceled")
                    TraceLogger.log("dictate canceled")
                    return
                }
                menuBarController?.setIndicatorState(.idle)
                menuBarController?.setState("Failed: \(Self.dictationFailureMessage(for: error))")
                TraceLogger.log("\(interactionMode == .talonLite ? "talon-lite" : "dictate") failed: \(error)")
                await appendFailedInteraction(
                    error: error,
                    mode: interactionMode,
                    optionalContext: requestContext,
                    audioData: capturedAudio.data,
                    sampleRate: capturedAudio.sampleRate,
                    locale: locale
                )
            }
        }
    }

    private func hasOpenAIKey() -> Bool {
        do {
            return try inMemorySecretStore.getOpenAIKey() != nil
        } catch {
            TraceLogger.log("in-memory secret read failed: \(error)")
            return false
        }
    }

    private func makeRefinementEngine() -> any RefinementEngine {
        RuntimeConfigRefinementEngine(
            runtimeConfigProvider: runtimeConfigProvider,
            secretStore: secretStore,
            canUseOpenAI: { [weak self] in
                self?.hasOpenAIKey() ?? false
            }
        )
    }

    private func startupReadyMessage() async -> String {
        let base = "Ready (Caps Lock or Launchpad 0,0 toggles recording)"
        let configuration = await runtimeConfigProvider.currentConfiguration()
        switch configuration.provider {
        case .openai:
            if let secretsLoadError {
                return "Ready: secrets file error (\(secretsLoadError)) [OpenAI]"
            }
            if hasOpenAIKey() {
                return "\(base) [OpenAI]"
            }
            return "Ready: Configure OpenAI key via Config/secrets.json or in-memory menu [OpenAI]"
        case .ollama:
            if configuration.fallback == .openai {
                if hasOpenAIKey() {
                    return "\(base) [Ollama primary, OpenAI fallback]"
                }
                return "\(base) [Ollama primary, OpenAI fallback unavailable: key missing]"
            }
            return "\(base) [Ollama]"
        }
    }

    private func promptForAPIKey(menuBarController: MenuBarController) {
        let alert = NSAlert()
        alert.messageText = "Set OpenAI API Key (Fallback)"
        alert.informativeText = "Paste your API key. It will be stored in memory for this app session only."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        textField.placeholderString = "sk-..."
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        let key = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            menuBarController.setState("Failed: API key cannot be empty")
            return
        }

        do {
            try inMemorySecretStore.setOpenAIKey(key)
            menuBarController.setState("Saved OpenAI key in memory (session only)")
        } catch {
            menuBarController.setState("Failed: Could not save OpenAI key")
        }
    }

    private func clearAPIKey(menuBarController: MenuBarController) {
        do {
            try inMemorySecretStore.clearOpenAIKey()
            menuBarController.setState("Cleared in-memory OpenAI key")
        } catch {
            menuBarController.setState("Failed: Could not clear OpenAI key")
        }
    }

    private func bootstrapSecretsInMemory() {
        do {
            if let key = try secretsFileStore.getOpenAIKey() {
                try inMemorySecretStore.setOpenAIKey(key)
                TraceLogger.log("loaded OpenAI key from secrets.json into memory")
            } else {
                TraceLogger.log("no OpenAI key found in secrets.json")
            }
        } catch {
            secretsLoadError = String(describing: error)
            TraceLogger.log("failed to load secrets file: \(error)")
        }
    }

    private static func failureMessage(for error: ClipboardInserter.InsertError) -> String {
        switch error {
        case .accessibilityPermissionMissing:
            return "Accessibility permission missing"
        case .clipboardWriteFailed:
            return "Could not write to clipboard"
        case .keyEventSynthesisFailed:
            return "Could not synthesize Cmd+V"
        }
    }

    private static func recordingFailureMessage(for error: AudioRecorder.RecorderError) -> String {
        switch error {
        case .microphonePermissionMissing:
            return "Microphone permission missing"
        case .recorderSetupFailed:
            return "Recorder setup failed"
        case .startFailed:
            return "Could not start recording"
        case .notRecording:
            return "No active recording"
        case .readFailed:
            return "Could not read captured audio"
        }
    }

    private static func dictationFailureMessage(for error: Error) -> String {
        if let dictatorError = error as? DictatorError {
            switch dictatorError {
            case .missingApiKey:
                return "Missing OpenAI key (set from menu or Config/secrets.json)"
            case .invalidApiKey:
                return "Invalid OpenAI key"
            case .networkUnavailable:
                return "Network unavailable"
            case let .refinementFailed(reason):
                return "Refinement failed: \(String(reason.prefix(60)))"
            case let .sttFailed(reason):
                return "Speech recognition failed: \(String(reason.prefix(60)))"
            case let .permissionsDenied(scope):
                return "Permission denied: \(scope)"
            case let .configUpdateFailed(reason):
                return "Config update failed: \(String(reason.prefix(60)))"
            case .configInteractionUnavailable:
                return "Config interaction unavailable"
            case let .talonPipelineFailed(reason):
                return "Talon pipeline failed: \(String(reason.prefix(60)))"
            }
        }
        if error is APIClientError {
            return "STT returned empty transcript"
        }
        return "Dictation request failed"
    }

    private static func dictationFailureDetail(for error: Error) -> String {
        if let dictatorError = error as? DictatorError {
            switch dictatorError {
            case .missingApiKey:
                return "Missing OpenAI key (set from menu or Config/secrets.json)"
            case .invalidApiKey:
                return "Invalid OpenAI key"
            case .networkUnavailable:
                return "Network unavailable"
            case let .refinementFailed(reason):
                return "Refinement failed: \(reason)"
            case let .sttFailed(reason):
                return "Speech recognition failed: \(reason)"
            case let .permissionsDenied(scope):
                return "Permission denied: \(scope)"
            case let .configUpdateFailed(reason):
                return "Config update failed: \(reason)"
            case .configInteractionUnavailable:
                return "Config interaction unavailable"
            case let .talonPipelineFailed(reason):
                return "Talon pipeline failed: \(reason)"
            }
        }
        if error is APIClientError {
            return "STT returned empty transcript"
        }
        return "Dictation request failed: \(String(describing: error))"
    }

    private func logRefinementMode(context: [String: String]?) {
        let selected = context?["selected_text"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if selected.isEmpty {
            TraceLogger.log("refinement mode: transcript-refinement")
            return
        }

        TraceLogger.log("refinement mode: selected-text-transform (selectedChars=\(selected.count))")
        TraceLogger.log("selected text for transform: \(Self.logSafeText(selected))")
    }

    private static func logSafeText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func lettersOnlyTranscript(_ input: String) -> String {
        let mapped = input.map { ch -> Character in
            if ch.isLetter || ch.isWhitespace {
                return ch
            }
            return " "
        }
        return String(mapped).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    @MainActor
    private func setupLaunchpadIntegration() {
        if !KeyboardInjector.hasAccessibilityPermission() {
            _ = KeyboardInjector.requestAccessibilityPermissionPrompt()
            menuBarController?.setLaunchpadStatus("Enable Accessibility for keystrokes")
        } else {
            menuBarController?.setLaunchpadStatus("Keystrokes ready")
        }

        let invalidationBus = RenderInvalidationBus()
        let pageController = LaunchpadPageController(invalidationBus: invalidationBus)
        let configTab = LaunchpadConfigOverlayTab(
            listConfigs: { [weak self] in
                guard let self else {
                    throw DictatorError.configInteractionUnavailable
                }
                let manager = try await self.runtimeConfigurationManagerInstance()
                return try await manager.list()
            },
            getOptionsForConfig: { [weak self] name in
                guard let self else {
                    throw DictatorError.configInteractionUnavailable
                }
                let manager = try await self.runtimeConfigurationManagerInstance()
                return try await manager.getOptions(name: name)
            },
            setConfig: { [weak self] name, value in
                guard let self else {
                    throw DictatorError.configInteractionUnavailable
                }
                let manager = try await self.runtimeConfigurationManagerInstance()
                try await manager.set(name: name, value: value)
            }
        )
        let systemPromptsTab = LaunchpadSystemPromptsOverlayTab(
            listDirectoryEntries: { [weak self] relativeDirectory in
                guard let self else {
                    throw DictatorError.configInteractionUnavailable
                }
                let runtimeConfig = await self.runtimeConfigProvider.currentRuntimeConfig()
                let promptCatalog = SystemPromptCatalog(
                    directoryURL: runtimeConfig.resolvedSystemPromptsDirectoryURL()
                )
                return try promptCatalog
                    .listEntries(in: relativeDirectory)
                    .map { entry in
                        LaunchpadSystemPromptsOverlayTab.DirectoryEntry(
                            name: entry.name,
                            relativePath: entry.relativePath,
                            isDirectory: entry.kind == .directory
                        )
                    }
            },
            loadPromptBody: { [weak self] relativePath in
                guard let self else {
                    throw DictatorError.configInteractionUnavailable
                }
                let runtimeConfig = await self.runtimeConfigProvider.currentRuntimeConfig()
                return try SystemPromptCatalog(
                    directoryURL: runtimeConfig.resolvedSystemPromptsDirectoryURL()
                ).loadPrompt(named: relativePath)
            },
            getSelectedPromptPath: { [weak self] in
                guard let self else {
                    return SystemPromptCatalog.defaultPromptFile
                }
                let runtimeConfig = await self.runtimeConfigProvider.currentRuntimeConfig()
                return runtimeConfig.systemPrompt
            },
            setSelectedPromptPath: { [weak self] relativePath in
                guard let self else {
                    throw DictatorError.configInteractionUnavailable
                }
                let manager = try await self.runtimeConfigurationManagerInstance()
                try await manager.set(name: "System Prompt", value: .string(relativePath))
            }
        )
        let interactionsTab = LaunchpadInteractionsOverlayTab(
            loadInteractions: { [weak self] in
                self?.interactionBuffer.snapshot() ?? []
            }
        )
        self.interactionsOverlayTab = interactionsTab
        let overlayController = LaunchpadFullscreenOverlayController(
            tabs: [
                configTab,
                systemPromptsTab,
                interactionsTab
            ]
        )
        let overlayTabSlotCoordinator = LaunchpadOverlayTabSlotCoordinator(
            invalidationBus: invalidationBus,
            pageController: pageController,
            tabCount: overlayController.tabCount,
            onSelectTab: { [weak self] index in
                Task { @MainActor in
                    self?.selectLaunchpadOverlayTab(index: index)
                }
            }
        )
        overlayController.onStateChanged = { [weak overlayTabSlotCoordinator] state in
            overlayTabSlotCoordinator?.sync(with: state)
        }
        let pageFactory = LaunchpadPageFactory(
            invalidationBus: invalidationBus,
            onKeystroke: { [weak self] key, baseModifiers in
                self?.dispatchLaunchpadKeystroke(key, baseModifiers: baseModifiers)
            },
            onDictationCommand: { [weak self] command in
                Task { @MainActor in
                    await self?.handleLaunchpadDictationCommand(command)
                }
            },
            onTalonLiteDictationCommand: { [weak self] command in
                Task { @MainActor in
                    await self?.handleLaunchpadTalonLiteDictationCommand(command)
                }
            },
            onContextualBackspace: { [weak self] in
                Task { @MainActor in
                    await self?.handleLaunchpadContextualBackspace()
                }
            },
            onNextWindowSwitchPress: { [weak self] in
                Task { @MainActor in
                    self?.handleLaunchpadNextWindowSwitchPress()
                }
            },
            onNextWindowSwitchRelease: { [weak self] in
                Task { @MainActor in
                    self?.handleLaunchpadNextWindowSwitchRelease()
                }
            },
            onAppReload: { [weak self] in
                Task { @MainActor in
                    self?.triggerAppReload()
                }
            },
            onLoadSafeRuntimeConfig: { [weak self] in
                Task { @MainActor in
                    await self?.handleLaunchpadLoadSafeRuntimeConfig()
                }
            },
            onToggleFullscreenOverlay: { [weak self] in
                Task { @MainActor in
                    self?.toggleLaunchpadOverlay()
                }
            },
            recordStatusColorProvider: { [weak self] in
                self?.recordStatusColor() ?? .off
            },
            shiftLatchColorProvider: { [weak self] in
                self?.shiftLatchColor() ?? PadColor(r: 50, g: 50, b: 0)
            },
            onModifierPress: { [weak self] modifier in
                self?.handleModifierPress(modifier)
            },
            onModifierRelease: { [weak self] modifier in
                self?.handleModifierRelease(modifier)
            }
        )

        do {
            let config = try LaunchpadLayoutLoader.loadDefault()
            TraceLogger.log(
                "launchpad layout loaded pages=\(config.pages.count) initial=\(config.initialPageID ?? "<none>")"
            )
            for page in config.pages {
                TraceLogger.log("launchpad layout page id=\(page.id) pads=\(page.pads.count)")
            }
            let pages = pageFactory.makePages(from: config)
            pageController.setPages(pages, initialPageID: config.initialPageID)
        } catch {
            TraceLogger.log("launchpad layout load failed: \(error)")
            return
        }

        let midiManager = LaunchpadMIDIManager()
        let renderWorker = LaunchpadColorRenderWorker(
            invalidationBus: invalidationBus,
            colorProvider: pageController,
            transport: midiManager
        )

        midiManager.onPadEvent = { [weak pageController] event in
            pageController?.handle(event)
        }
        midiManager.onConnectionStateChanged = { [weak self, weak renderWorker] state in
            guard let self else {
                return
            }
            switch state {
            case .searching:
                TraceLogger.log("launchpad state: searching")
                self.menuBarController?.setLaunchpadStatus("Searching for Launchpad Pro Mk3")
            case let .connected(name):
                TraceLogger.log("launchpad state: connected (\(name))")
                if KeyboardInjector.hasAccessibilityPermission() {
                    self.menuBarController?.setLaunchpadStatus("Connected: \(name)")
                } else {
                    self.menuBarController?.setLaunchpadStatus("Connected: \(name) (needs Accessibility)")
                }
                renderWorker?.invalidateAll()
            }
        }
        midiManager.onSleepStateChanged = { [weak self, weak renderWorker] sleeping in
            guard let self else {
                return
            }
            if sleeping {
                TraceLogger.log("launchpad state: sleeping")
                self.menuBarController?.setLaunchpadStatus("Launchpad sleeping (touch to wake)")
                return
            }

            TraceLogger.log("launchpad state: awake")
            renderWorker?.invalidateAll()
            if KeyboardInjector.hasAccessibilityPermission() {
                self.menuBarController?.setLaunchpadStatus("Connected: Launchpad Pro Mk3")
            } else {
                self.menuBarController?.setLaunchpadStatus("Connected: Launchpad Pro Mk3 (needs Accessibility)")
            }
        }

        launchpadInvalidationBus = invalidationBus
        launchpadPageController = pageController
        launchpadMIDIManager = midiManager
        launchpadRenderWorker = renderWorker
        launchpadOverlayController = overlayController
        launchpadOverlayTabSlotCoordinator = overlayTabSlotCoordinator

        renderWorker.start()
        midiManager.start()
    }

    @MainActor
    private func toggleLaunchpadOverlay() {
        guard let launchpadOverlayController else {
            TraceLogger.log("launchpad overlay toggle ignored: controller unavailable")
            return
        }

        let isVisible = launchpadOverlayController.toggle()
        let status = isVisible ? "Overlay visible" : "Overlay hidden"
        menuBarController?.setLaunchpadStatus(status)
        TraceLogger.log("launchpad overlay toggled visible=\(isVisible)")
    }

    @MainActor
    private func selectLaunchpadOverlayTab(index: Int) {
        guard let launchpadOverlayController else {
            TraceLogger.log("launchpad overlay tab select ignored: controller unavailable")
            return
        }
        guard launchpadOverlayController.isVisible else {
            TraceLogger.log("launchpad overlay tab select ignored: overlay hidden")
            return
        }

        guard launchpadOverlayController.selectTab(index: index, showIfHidden: false) else {
            TraceLogger.log("launchpad overlay tab select ignored: index out of range index=\(index)")
            return
        }

        menuBarController?.setLaunchpadStatus("Overlay tab \(index) selected")
        TraceLogger.log("launchpad overlay tab selected index=\(index)")
    }

    @MainActor
    private func bootstrapOllamaIfNeeded() async {
        let configuration = await runtimeConfigProvider.currentConfiguration()
        switch OllamaBootstrapper.ensureRunningIfNeeded(configuration: configuration) {
        case .notRequired:
            TraceLogger.log("ollama bootstrap skipped (provider=\(configuration.provider.rawValue), host=\(configuration.ollamaHost))")
        case .alreadyRunning:
            TraceLogger.log("ollama bootstrap: already running")
        case let .started(process):
            managedOllamaProcess = process
            TraceLogger.log("ollama bootstrap: started local serve process")
        case let .startFailed(reason):
            TraceLogger.log("ollama bootstrap failed: \(reason)")
        }
    }

    @MainActor
    private func handleLaunchpadDictationCommand(_ command: LaunchpadActionConfig.DictationCommand) async {
        await handleLaunchpadDictationCommand(command, mode: .standard)
    }

    @MainActor
    private func handleLaunchpadTalonLiteDictationCommand(_ command: LaunchpadActionConfig.DictationCommand) async {
        await handleLaunchpadDictationCommand(command, mode: .talonLite)
    }

    @MainActor
    private func handleLaunchpadDictationCommand(_ command: LaunchpadActionConfig.DictationCommand, mode: InteractionMode) async {
        switch command {
        case .start:
            if currentDictationState() == .idle && !recordingController.isRecording {
                await startRecording(menuBarController: menuBarController, mode: mode)
            }
        case .stop:
            if currentDictationState() == .recording && recordingController.isRecording {
                await stopRecordingAndProcess(menuBarController: menuBarController)
            }
        case .cancel:
            cancelRecording(menuBarController: menuBarController)
        case .toggle:
            if currentDictationState() == .thinking {
                cancelThinking(menuBarController: menuBarController)
            } else if recordingController.isRecording {
                await stopRecordingAndProcess(menuBarController: menuBarController)
            } else {
                await startRecording(menuBarController: menuBarController, mode: mode)
            }
        }
    }

    @MainActor
    private func handleLaunchpadContextualBackspace() async {
        if currentDictationState() == .recording {
            cancelRecording(menuBarController: menuBarController)
            return
        }

        if currentDictationState() == .thinking {
            cancelThinking(menuBarController: menuBarController)
            return
        }

        let modifiers = modifiersForKeyPress(.backspace)
        _ = keyboardInjector.send(.backspace, modifiers: modifiers)
    }

    @MainActor
    private func handleLaunchpadNextWindowSwitchPress() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            TraceLogger.log("launchpad next_window no-op: frontmost application unavailable")
            endLaunchpadAppCycleSession(reason: "frontmost_unavailable")
            return
        }

        let frontmostPID = frontmost.processIdentifier
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let excludedPIDs: Set<pid_t> = [frontmostPID, selfPID]
        let frozenCandidatePIDs = frozenNextWindowCandidatePIDs(excluding: excludedPIDs)

        guard !frozenCandidatePIDs.isEmpty else {
            TraceLogger.log("launchpad next_window no-op: no eligible app candidate")
            endLaunchpadAppCycleSession(reason: "no_candidates")
            return
        }

        var activatedPID: pid_t?
        for pid in frozenCandidatePIDs {
            if activateApplicationForNextWindow(pid: pid) {
                activatedPID = pid
                let appName = applicationName(pid: pid)
                TraceLogger.log("launchpad next_window activated app=\(appName) pid=\(pid)")
                menuBarController?.setLaunchpadStatus("Switched: \(appName)")
                break
            }
            TraceLogger.log("launchpad next_window activation failed pid=\(pid)")
        }

        guard let activatedPID else {
            TraceLogger.log("launchpad next_window no-op: activation failed for all candidates")
            endLaunchpadAppCycleSession(reason: "activation_failed")
            return
        }

        guard launchpadAppCycleState.start(with: frozenCandidatePIDs, currentPID: activatedPID) else {
            TraceLogger.log("launchpad next_window hold session not started: empty snapshot")
            endLaunchpadAppCycleSession(reason: "session_start_failed")
            return
        }

        armLaunchpadArrowCycleInterception()
        TraceLogger.log(
            "launchpad next_window hold session started candidates=\(frozenCandidatePIDs.count) currentPID=\(activatedPID)"
        )
    }

    @MainActor
    private func handleLaunchpadNextWindowSwitchRelease() {
        endLaunchpadAppCycleSession(reason: "pad_release")
    }

    @MainActor
    private func endLaunchpadAppCycleSession(reason: String) {
        disarmLaunchpadArrowCycleInterception()
        launchpadAppCycleState.stop()
        lastArrowCycleDispatch = nil
        TraceLogger.log("launchpad next_window hold session ended reason=\(reason)")
    }

    @MainActor
    private func handleLaunchpadArrowCycleKeyDown(keyCode: UInt16, timestamp: TimeInterval, source: String) {
        guard let direction = directionForArrowKeyCode(keyCode) else {
            return
        }
        guard launchpadAppCycleState.isActive else {
            return
        }

        if let lastArrowCycleDispatch,
           lastArrowCycleDispatch.keyCode == keyCode,
           (timestamp - lastArrowCycleDispatch.timestamp) <= Self.arrowCycleDebounceSeconds {
            return
        }
        lastArrowCycleDispatch = (keyCode, timestamp)

        let attempts = launchpadAppCycleState.candidateCount
        guard attempts > 0 else {
            endLaunchpadAppCycleSession(reason: "empty_active_session")
            return
        }

        for _ in 0..<attempts {
            let runtimeCurrentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            guard let nextPID = launchpadAppCycleState.step(direction, currentPID: runtimeCurrentPID) else {
                return
            }
            if activateApplicationForNextWindow(pid: nextPID) {
                let appName = applicationName(pid: nextPID)
                TraceLogger.log(
                    "launchpad next_window hold cycle source=\(source) direction=\(direction == .forward ? "forward" : "backward") app=\(appName) pid=\(nextPID)"
                )
                menuBarController?.setLaunchpadStatus("Switched: \(appName)")
                return
            }
            TraceLogger.log("launchpad next_window hold cycle skipped pid=\(nextPID)")
        }

        TraceLogger.log("launchpad next_window hold cycle no-op: no activatable app")
    }

    private func armLaunchpadArrowCycleInterception() {
        disarmLaunchpadArrowCycleInterception()
        let eventTapArmed = launchpadArrowEventTapController.arm()
        launchpadArrowInterceptionLifecycle.arm(eventTapAvailable: eventTapArmed)
        guard !eventTapArmed else {
            return
        }

        TraceLogger.log("launchpad next_window event tap unavailable; using monitor fallback")
        armLaunchpadArrowCycleMonitors()
    }

    private func disarmLaunchpadArrowCycleInterception() {
        disarmLaunchpadArrowCycleMonitors()
        launchpadArrowEventTapController.disarm()
        launchpadArrowInterceptionLifecycle.disarm()
    }

    private func armLaunchpadArrowCycleMonitors() {
        disarmLaunchpadArrowCycleMonitors()
        launchpadArrowGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                guard let self else {
                    return
                }
                let shouldHandle = LaunchpadArrowCycleInterceptionRouting.shouldHandleArrowKeyEvent(
                    source: .globalMonitor,
                    path: self.launchpadArrowInterceptionLifecycle.path,
                    isArrowKey: self.directionForArrowKeyCode(event.keyCode) != nil,
                    isHoldCycleSessionActive: self.launchpadAppCycleState.isActive
                )
                guard shouldHandle else {
                    return
                }
                self.handleLaunchpadArrowCycleKeyDown(
                    keyCode: event.keyCode,
                    timestamp: event.timestamp,
                    source: "global"
                )
            }
        }
        launchpadArrowLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            let shouldConsume = LaunchpadArrowCycleLocalEventConsumption.shouldConsume(
                eventType: event.type,
                isArrowKey: self.directionForArrowKeyCode(event.keyCode) != nil,
                isHoldCycleSessionActive: self.launchpadAppCycleState.isActive
            )
            let shouldHandle = LaunchpadArrowCycleInterceptionRouting.shouldHandleArrowKeyEvent(
                source: .localMonitor,
                path: self.launchpadArrowInterceptionLifecycle.path,
                isArrowKey: self.directionForArrowKeyCode(event.keyCode) != nil,
                isHoldCycleSessionActive: self.launchpadAppCycleState.isActive
            )
            if shouldConsume && shouldHandle {
                Task { @MainActor in
                    self.handleLaunchpadArrowCycleKeyDown(
                        keyCode: event.keyCode,
                        timestamp: event.timestamp,
                        source: "local"
                    )
                }
                return nil
            }
            return event
        }
        TraceLogger.log(
            "launchpad next_window hold monitors armed (global=\(launchpadArrowGlobalMonitor != nil), local=\(launchpadArrowLocalMonitor != nil))"
        )
    }

    private func disarmLaunchpadArrowCycleMonitors() {
        if let launchpadArrowGlobalMonitor {
            NSEvent.removeMonitor(launchpadArrowGlobalMonitor)
            self.launchpadArrowGlobalMonitor = nil
        }
        if let launchpadArrowLocalMonitor {
            NSEvent.removeMonitor(launchpadArrowLocalMonitor)
            self.launchpadArrowLocalMonitor = nil
        }
    }

    private func directionForArrowKeyCode(_ keyCode: UInt16) -> LaunchpadAppCycleDirection? {
        switch keyCode {
        case Self.leftArrowKeyCode, Self.upArrowKeyCode:
            return .backward
        case Self.rightArrowKeyCode, Self.downArrowKeyCode:
            return .forward
        default:
            return nil
        }
    }

    private func frozenNextWindowCandidatePIDs(excluding excludedPIDs: Set<pid_t>) -> [pid_t] {
        let orderedWindowPIDs = orderedWindowOwnerPIDs(excluding: excludedPIDs)
        var frozenCandidates: [pid_t] = []
        var seen = Set<pid_t>()

        for pid in orderedWindowPIDs {
            guard let app = NSRunningApplication(processIdentifier: pid),
                  isEligibleNextWindowTarget(app: app, excludedPIDs: excludedPIDs),
                  !seen.contains(pid) else {
                continue
            }
            seen.insert(pid)
            frozenCandidates.append(pid)
        }

        for app in NSWorkspace.shared.runningApplications where isEligibleNextWindowTarget(app: app, excludedPIDs: excludedPIDs) {
            let pid = app.processIdentifier
            guard !seen.contains(pid) else {
                continue
            }
            seen.insert(pid)
            frozenCandidates.append(pid)
        }

        return frozenCandidates
    }

    private func isEligibleNextWindowTarget(app: NSRunningApplication, excludedPIDs: Set<pid_t>) -> Bool {
        let pid = app.processIdentifier
        return !excludedPIDs.contains(pid) &&
            app.activationPolicy == .regular &&
            !app.isHidden &&
            !app.isTerminated
    }

    private func activateApplicationForNextWindow(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        guard app.activationPolicy == .regular, !app.isHidden, !app.isTerminated else {
            return false
        }
        return app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func applicationName(pid: pid_t) -> String {
        NSRunningApplication(processIdentifier: pid)?.localizedName ?? "<unknown>"
    }

    private func orderedWindowOwnerPIDs(excluding excludedPIDs: Set<pid_t>) -> [pid_t] {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var ordered: [pid_t] = []
        var seen = Set<pid_t>()
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? NSNumber else {
                continue
            }
            let pid = ownerPID.int32Value
            guard !excludedPIDs.contains(pid), !seen.contains(pid) else {
                continue
            }
            seen.insert(pid)
            ordered.append(pid)
        }
        return ordered
    }

    private func dispatchLaunchpadKeystroke(_ key: KeyboardKey, baseModifiers: Set<KeyboardModifier>) {
        if isOverlayNavigationKey(key) {
            Task { @MainActor in
                let handledByOverlay = await launchpadOverlayController?.handleOverlayKey(key) ?? false
                if handledByOverlay {
                    TraceLogger.log("overlay handled launchpad key=\(key.rawValue)")
                    return
                }

                var modifiers = baseModifiers
                modifiers.formUnion(self.modifiersForKeyPress(key))
                _ = self.keyboardInjector.send(key, modifiers: modifiers)
            }
            return
        }

        var modifiers = baseModifiers
        modifiers.formUnion(modifiersForKeyPress(key))
        _ = keyboardInjector.send(key, modifiers: modifiers)
    }

    private func isOverlayNavigationKey(_ key: KeyboardKey) -> Bool {
        key == .up || key == .down || key == .left || key == .right || key == .enter
    }

    @MainActor
    private func handleLaunchpadLoadSafeRuntimeConfig() async {
        // Do not mutate runtime memory when in unstable operational states.
        guard currentDictationState() == .idle, !recordingController.isRecording else {
            menuBarController?.setState("Skipped safe restore: app busy")
            TraceLogger.log("safe runtime restore skipped (state=\(currentDictationState()), recording=\(recordingController.isRecording))")
            return
        }

        do {
            let manager = try await runtimeConfigurationManagerInstance()
            try await manager.resetToDefaults()
            let loaded = await runtimeConfigProvider.currentRuntimeConfig()
            let mode = loaded.useCloud ? "cloud" : "local"
            menuBarController?.setState("Safe config loaded: \(mode) (\(loaded.model))")
            TraceLogger.log("safe runtime defaults applied in memory (model=\(loaded.model), use_cloud=\(loaded.useCloud))")
        } catch {
            menuBarController?.setState("Failed: \(Self.dictationFailureMessage(for: error))")
            TraceLogger.log("safe runtime restore failed: \(error)")
        }
    }

    @MainActor
    private func runtimeConfigurationManagerInstance() async throws -> RuntimeConfigurationManager {
        if let runtimeConfigurationManager {
            return runtimeConfigurationManager
        }

        guard let defaultConfig = try safeRuntimeConfigStore.load() else {
            throw DictatorError.configUpdateFailed("safe runtime config file is missing")
        }
        let currentConfig = await runtimeConfigProvider.currentRuntimeConfig()
        let configuration = await runtimeConfigProvider.currentConfiguration()
        let promptCatalog = SystemPromptCatalog(
            directoryURL: currentConfig.resolvedSystemPromptsDirectoryURL()
        )

        let manager = RuntimeConfigurationManager(
            configurations: [
                RuntimeModelConfiguration(
                    name: "Cloud Model",
                    currentValue: currentConfig.cloudModel,
                    defaultValue: defaultConfig.cloudModel,
                    target: .cloud,
                    optionsSource: .openAI(secretStore: secretStore),
                    runtimeConfigProvider: runtimeConfigProvider,
                    host: configuration.ollamaHost
                ),
                RuntimeBooleanConfiguration(
                    name: "Use Cloud",
                    currentValue: currentConfig.useCloud,
                    defaultValue: defaultConfig.useCloud,
                    runtimeConfigProvider: runtimeConfigProvider
                ),
                RuntimeModelConfiguration(
                    name: "Local Model",
                    currentValue: currentConfig.localModel,
                    defaultValue: defaultConfig.localModel,
                    target: .local,
                    optionsSource: .ollama,
                    runtimeConfigProvider: runtimeConfigProvider,
                    host: configuration.ollamaHost
                ),
                RuntimeSystemPromptConfiguration(
                    name: "System Prompt",
                    currentValue: currentConfig.systemPrompt,
                    defaultValue: defaultConfig.systemPrompt,
                    runtimeConfigProvider: runtimeConfigProvider,
                    promptCatalog: promptCatalog
                ),
                RuntimeInteractionsBufferConfiguration(
                    name: "Interactions Buffer",
                    currentValueBytes: currentConfig.interactionsBufferBytes,
                    defaultValueBytes: defaultConfig.interactionsBufferBytes,
                    runtimeConfigProvider: runtimeConfigProvider,
                    onBytesUpdated: { [weak self] bytes in
                        self?.interactionBuffer.setMaxBytes(bytes)
                        Task { [weak self] in
                            await self?.interactionStore?.setMaxBytes(bytes)
                        }
                    }
                )
            ]
        )
        runtimeConfigurationManager = manager
        return manager
    }

    private func handleKeyboardDispatchResult(_ result: KeyboardInjector.DispatchResult) {
        if result.success {
            menuBarController?.setLaunchpadStatus("Sent key: \(result.key.rawValue)")
            return
        }

        switch result.failureReason {
        case .accessibilityPermissionMissing:
            _ = KeyboardInjector.requestAccessibilityPermissionPrompt()
            menuBarController?.setLaunchpadStatus("Permission required for key: \(result.key.rawValue)")
        case .eventConstructionFailed:
            menuBarController?.setLaunchpadStatus("Key dispatch failed: \(result.key.rawValue)")
        case .none:
            menuBarController?.setLaunchpadStatus("Key dispatch failed: \(result.key.rawValue)")
        }
    }

    @MainActor
    private func cancelThinking(menuBarController: MenuBarController?) {
        guard currentDictationState() == .thinking else {
            return
        }
        cancelActiveDictationTask()
        setDictationState(.idle)
        menuBarController?.setIndicatorState(.idle)
        menuBarController?.setState("Thinking canceled")
        TraceLogger.log("thinking canceled via contextual backspace")
    }

    private func setDictationState(_ newState: DictationState) {
        dictationStateLock.lock()
        dictationState = newState
        dictationStateLock.unlock()
        launchpadInvalidationBus?.markDirty(reason: "dictation_state")
    }

    private func currentDictationState() -> DictationState {
        dictationStateLock.lock()
        let state = dictationState
        dictationStateLock.unlock()
        return state
    }

    private func setActiveDictationTask(_ task: Task<DictateCallResult, Error>) {
        dictationStateLock.lock()
        activeDictationTask = task
        dictationStateLock.unlock()
    }

    private func clearActiveDictationTask(_ task: Task<DictateCallResult, Error>) {
        dictationStateLock.lock()
        _ = task
        activeDictationTask = nil
        dictationStateLock.unlock()
    }

    @MainActor
    private func setupInteractionStoreIfNeeded() async {
        if let interactionStoreSetupTask {
            await interactionStoreSetupTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let currentConfig = await runtimeConfigProvider.currentRuntimeConfig()
            interactionBuffer.setMaxBytes(currentConfig.interactionsBufferBytes)
            let dataDirectoryURL = InteractionDataPathResolver.defaultDataDirectory(
                runtimeConfig: currentConfig
            )
            let store = InteractionHistoryStore(
                buffer: interactionBuffer,
                dataDirectoryURL: dataDirectoryURL,
                initialLoadBytes: currentConfig.interactionsBufferBytes,
                onChanged: { [weak self] in
                    self?.interactionsOverlayTab?.reloadInteractions()
                }
            )
            interactionStore = store
            await store.setMaxBytes(currentConfig.interactionsBufferBytes)
            await store.startInitialLoadIfNeeded()
        }
        interactionStoreSetupTask = task
        await task.value
    }

    @MainActor
    private func ensureInteractionStoreReady() async {
        await setupInteractionStoreIfNeeded()
        if let interactionStore {
            await interactionStore.waitUntilReady()
        }
    }

    @MainActor
    private func syncInteractionBufferLimitFromRuntimeConfig() async {
        let current = await runtimeConfigProvider.currentRuntimeConfig()
        interactionBuffer.setMaxBytes(current.interactionsBufferBytes)
        await interactionStore?.setMaxBytes(current.interactionsBufferBytes)
    }

    @MainActor
    private func appendInteraction(
        dictatedCall: DictateCallResult,
        optionalContext: [String: String]?,
        runtimeConfiguration: LLMRuntimeConfiguration,
        runtimeConfig: RuntimeConfigFile,
        insertMs: Int,
        totalPipelineMs: Int,
        errorMessage: String? = nil
    ) async {
        let response = dictatedCall.response
        let effectiveProvider: String
        if response.edit_summary.localizedCaseInsensitiveContains("OpenAI") {
            effectiveProvider = "openai"
        } else if response.edit_summary.localizedCaseInsensitiveContains("Ollama") {
            effectiveProvider = "ollama"
        } else {
            effectiveProvider = runtimeConfiguration.provider.rawValue
        }

        let effectiveModel = effectiveProvider == LLMRuntimeConfiguration.Provider.openai.rawValue
            ? runtimeConfiguration.openAIModel
            : runtimeConfiguration.ollamaModel
        let mode = Self.interactionMode(
            rawTranscript: response.raw_transcript,
            revisedText: response.revised_text,
            editSummary: response.edit_summary,
            context: optionalContext
        )
        let interaction = DictationInteraction(
            whisperOutput: response.raw_transcript,
            finalOutput: response.revised_text,
            mode: mode,
            systemPromptPath: runtimeConfig.systemPrompt,
            systemPromptBody: SystemPromptCatalog(
                directoryURL: runtimeConfig.resolvedSystemPromptsDirectoryURL()
            ).resolvePrompt(named: runtimeConfig.systemPrompt),
            model: effectiveModel,
            provider: effectiveProvider,
            optionalContext: optionalContext ?? [:],
            editSummary: response.edit_summary,
            uncertaintyFlags: response.uncertainty_flags,
            errorMessage: errorMessage,
            timings: DictationInteractionTimings(
                transcribeMs: dictatedCall.transcribeMs,
                refineMs: dictatedCall.refineMs,
                insertMs: insertMs,
                totalPipelineMs: totalPipelineMs
            )
        )
        await ensureInteractionStoreReady()
        if let interactionStore {
            await interactionStore.append(interaction)
        } else {
            interactionBuffer.append(interaction)
            interactionsOverlayTab?.reloadInteractions()
        }
    }

    @MainActor
    private func appendFailedInteraction(
        error: Error,
        mode: InteractionMode,
        optionalContext: [String: String]?,
        audioData: Data,
        sampleRate: Int,
        locale: String
    ) async {
        let runtimeConfiguration = await runtimeConfigProvider.currentConfiguration()
        let runtimeConfig = await runtimeConfigProvider.currentRuntimeConfig()
        let provider = runtimeConfiguration.provider.rawValue
        let model = provider == LLMRuntimeConfiguration.Provider.openai.rawValue
            ? runtimeConfiguration.openAIModel
            : runtimeConfiguration.ollamaModel
        let errorText = Self.dictationFailureDetail(for: error)
        var whisperOutput = ""
        var revisionOutput = ""
        var transcribeMs = 0
        var refineMs = 0

        let transcribeStart = Date()
        do {
            let transcribed = try await sttEngine.transcribe(
                TranscribeRequest(
                    audio_b64: audioData.base64EncodedString(),
                    sample_rate: sampleRate,
                    locale: locale,
                    session_id: sessionID
                )
            )
            transcribeMs = Self.elapsedMs(since: transcribeStart)
            whisperOutput = transcribed.raw_transcript
        } catch {
            TraceLogger.log("failed-interaction fallback transcribe failed: \(error)")
        }

        if !whisperOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let refineStart = Date()
            do {
                switch mode {
                case .standard:
                    let refined = try await makeRefinementEngine().refine(
                        RefineRequest(raw_transcript: whisperOutput, optional_context: optionalContext)
                    )
                    revisionOutput = refined.revised_text
                case .talonLite:
                    let normalized = Self.lettersOnlyTranscript(whisperOutput)
                    revisionOutput = try await talonLiteCorrectionEngine.correctToGrammar(normalized)
                }
                refineMs = Self.elapsedMs(since: refineStart)
            } catch {
                TraceLogger.log("failed-interaction fallback revision failed: \(error)")
            }
        }

        let summary = mode == .talonLite
            ? "Talon-lite pipeline failed."
            : "Dictation pipeline failed."
        let interaction = DictationInteraction(
            whisperOutput: whisperOutput,
            finalOutput: revisionOutput.isEmpty ? errorText : revisionOutput,
            mode: mode == .talonLite ? .talonLite : .revision,
            systemPromptPath: runtimeConfig.systemPrompt,
            systemPromptBody: SystemPromptCatalog(
                directoryURL: runtimeConfig.resolvedSystemPromptsDirectoryURL()
            ).resolvePrompt(named: runtimeConfig.systemPrompt),
            model: model,
            provider: provider,
            optionalContext: optionalContext ?? [:],
            editSummary: summary,
            uncertaintyFlags: ["pipeline_error"],
            errorMessage: errorText,
            timings: DictationInteractionTimings(
                transcribeMs: transcribeMs,
                refineMs: refineMs,
                insertMs: 0,
                totalPipelineMs: transcribeMs + refineMs
            )
        )
        await ensureInteractionStoreReady()
        if let interactionStore {
            await interactionStore.append(interaction)
        } else {
            interactionBuffer.append(interaction)
            interactionsOverlayTab?.reloadInteractions()
        }
    }

    private static func interactionMode(
        rawTranscript: String,
        revisedText: String,
        editSummary: String,
        context: [String: String]?
    ) -> DictationInteractionMode {
        if editSummary.localizedCaseInsensitiveContains("Talon-lite") {
            return .talonLite
        }
        let selectedText = context?["selected_text"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !selectedText.isEmpty {
            return .textReplacement
        }
        let normalizedRaw = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRevised = revisedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedRaw == normalizedRevised {
            return .rawDictation
        }
        return .revision
    }

    @MainActor
    private func appendAPIInteraction(_ record: DictationHTTPSuccessRecord) async {
        let runtimeConfiguration = await runtimeConfigProvider.currentConfiguration()
        let runtimeConfig = await runtimeConfigProvider.currentRuntimeConfig()
        var context = record.optionalContext ?? [:]
        if context["request_source"] == nil {
            context["request_source"] = "dictation_http_api"
        }
        await appendInteraction(
            dictatedCall: DictateCallResult(
                response: record.response,
                transcribeMs: record.transcribeMs,
                refineMs: record.refineMs
            ),
            optionalContext: context,
            runtimeConfiguration: runtimeConfiguration,
            runtimeConfig: runtimeConfig,
            insertMs: 0,
            totalPipelineMs: record.totalPipelineMs
        )
    }

    @MainActor
    private func appendAPIFailedInteraction(_ record: DictationHTTPFailureRecord) async {
        var context = record.optionalContext ?? [:]
        if context["request_source"] == nil {
            context["request_source"] = "dictation_http_api"
        }
        let error = NSError(
            domain: "DictationHTTPServer",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: record.errorMessage]
        )
        await appendFailedInteraction(
            error: error,
            mode: .standard,
            optionalContext: context,
            audioData: record.audioData,
            sampleRate: record.sampleRate,
            locale: record.locale
        )
    }

    private static func elapsedMs(since start: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(start) * 1000))
    }

    private func cancelActiveDictationTask() {
        dictationStateLock.lock()
        let task = activeDictationTask
        activeDictationTask = nil
        dictationStateLock.unlock()
        task?.cancel()
    }

    private func recordStatusColor() -> PadColor {
        switch currentDictationState() {
        case .idle:
            return PadColor(r: 255, g: 255, b: 255)
        case .recording:
            return PadColor(r: 255, g: 0, b: 0)
        case .thinking:
            return PadColor(r: 0, g: 0, b: 255)
        }
    }

    private func handleModifierPress(_ modifier: LaunchpadActionConfig.ModifierType) {
        guard modifier == .shift else {
            return
        }

        shiftLatchStateLock.lock()
        defer { shiftLatchStateLock.unlock() }

        switch shiftLatchState {
        case .latched:
            shiftLatchState = .pressedNoLatchOnRelease
        case .unpressed, .pressedWillLatchOnRelease, .pressedNoLatchOnRelease:
            shiftLatchState = .pressedWillLatchOnRelease
        }
        launchpadInvalidationBus?.markDirty(reason: "shift_state")
    }

    private func handleModifierRelease(_ modifier: LaunchpadActionConfig.ModifierType) {
        guard modifier == .shift else {
            return
        }

        shiftLatchStateLock.lock()
        defer { shiftLatchStateLock.unlock() }

        switch shiftLatchState {
        case .pressedWillLatchOnRelease:
            shiftLatchState = .latched
        case .pressedNoLatchOnRelease:
            shiftLatchState = .unpressed
        case .latched, .unpressed:
            break
        }
        launchpadInvalidationBus?.markDirty(reason: "shift_state")
    }

    private func modifiersForKeyPress(_ key: KeyboardKey) -> Set<KeyboardModifier> {
        let isArrow = (key == .up || key == .down || key == .left || key == .right)

        shiftLatchStateLock.lock()
        defer { shiftLatchStateLock.unlock() }

        switch shiftLatchState {
        case .unpressed:
            return []
        case .pressedWillLatchOnRelease:
            if !isArrow {
                shiftLatchState = .pressedNoLatchOnRelease
                launchpadInvalidationBus?.markDirty(reason: "shift_state")
            }
            return [.shift]
        case .pressedNoLatchOnRelease:
            return [.shift]
        case .latched:
            if isArrow {
                return [.shift]
            }
            shiftLatchState = .unpressed
            launchpadInvalidationBus?.markDirty(reason: "shift_state")
            return []
        }
    }

    private func shiftLatchColor() -> PadColor {
        shiftLatchStateLock.lock()
        let state = shiftLatchState
        shiftLatchStateLock.unlock()

        switch state {
        case .unpressed:
            return PadColor(r: 50, g: 50, b: 0)
        case .pressedWillLatchOnRelease, .pressedNoLatchOnRelease, .latched:
            return PadColor(r: 255, g: 220, b: 0)
        }
    }

    @MainActor
    private func triggerAppReload() {
        guard !isRelaunching else {
            TraceLogger.log("reload ignored: relaunch already in progress")
            return
        }
        isRelaunching = true

        guard let executablePath = Bundle.main.executablePath ?? CommandLine.arguments.first else {
            TraceLogger.log("reload failed: executable path unavailable")
            menuBarController?.setLaunchpadStatus("Reload failed: no executable path")
            isRelaunching = false
            return
        }

        let currentPID = getpid()
        let launchArgs = Array(CommandLine.arguments.dropFirst())
        let spawned = AppRelaunchHelper.spawnRelaunchHelper(
            currentPID: currentPID,
            executablePath: executablePath,
            arguments: launchArgs
        )

        guard spawned else {
            menuBarController?.setLaunchpadStatus("Reload failed: helper spawn")
            isRelaunching = false
            return
        }

        menuBarController?.setLaunchpadStatus("Reloading...")
        TraceLogger.log("reload requested from launchpad")
        NSApplication.shared.terminate(nil)
    }
}

if !AppRelaunchHelper.maybeRunFromCommandLine(arguments: CommandLine.arguments) {
    let app = NSApplication.shared
    let delegate = DictatorAppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
