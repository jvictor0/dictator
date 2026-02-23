import AppKit
import Darwin
import DictatorCore

final class DictatorAppDelegate: NSObject, NSApplicationDelegate {
    private enum DictationState {
        case idle
        case recording
        case thinking
    }

    private enum ShiftLatchState {
        case unpressed
        case pressedWillLatchOnRelease
        case pressedNoLatchOnRelease
        case latched
    }

    private static let backspaceKeyCode: UInt16 = 51
    private static let cancelDebounceSeconds: TimeInterval = 0.15

    private var menuBarController: MenuBarController?
    private var capsLockTriggerController: CapsLockTriggerController?
    private var backspaceGlobalMonitor: Any?
    private var backspaceLocalMonitor: Any?
    private let recordingController = RecordingController()
    private let audioRecorder = AudioRecorder()
    private let activeTargetContextProvider = ActiveTargetContextProvider()
    private lazy var keyboardInjector: KeyboardInjector = KeyboardInjector { [weak self] result in
        DispatchQueue.main.async {
            self?.handleKeyboardDispatchResult(result)
        }
    }
    private let secretStore = KeychainSecretStore()
    private lazy var coreClient: any DictatorCoreClient = PipelineOrchestrator(
        sttEngine: WhisperCPPBridgeSTTEngine(),
        refinementEngine: makeRefinementEngine()
    )
    private lazy var apiClient: APIClient = APIClient(coreClient: coreClient)

    private let sessionID = UUID().uuidString
    private var isHandlingTrigger = false
    private var recordingContext: [String: String]?
    private var lastCancelTimestamp: TimeInterval?
    private var launchpadMIDIManager: LaunchpadMIDIManager?
    private var launchpadPageController: LaunchpadPageController?
    private var launchpadRenderWorker: LaunchpadColorRenderWorker?
    private var launchpadInvalidationBus: RenderInvalidationBus?
    private var managedOllamaProcess: Process?
    private var isRelaunching = false
    private let dictationStateLock = NSLock()
    private var dictationState: DictationState = .idle
    private var activeDictationTask: Task<DictateCallResult, Error>?
    private let shiftLatchStateLock = NSLock()
    private var shiftLatchState: ShiftLatchState = .unpressed

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dotenvValues = DotEnvLoader.loadIntoProcessEnvironment()
        TraceLogger.reset()
        TraceLogger.log("app did finish launching")
        TraceLogger.log("trace file: \(TraceLogger.path)")
        if !dotenvValues.isEmpty {
            TraceLogger.log("dotenv loaded keys=\(dotenvValues.keys.sorted().joined(separator: ","))")
        }

        let menuBarController = MenuBarController()
        menuBarController.onSetAPIKey = { [weak self] in
            self?.promptForAPIKey(menuBarController: menuBarController)
        }
        menuBarController.onClearAPIKey = { [weak self] in
            self?.clearAPIKey(menuBarController: menuBarController)
        }
        self.menuBarController = menuBarController
        bootstrapOllamaIfNeeded()

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
            menuBarController.setState(startupReadyMessage())
            TraceLogger.log("app ready: caps lock trigger armed")
        } else {
            menuBarController.setState("Failed: Accessibility permission missing")
            TraceLogger.log("app startup failed: caps lock trigger not armed")
        }

        setupLaunchpadIntegration()
    }

    func applicationWillTerminate(_ notification: Notification) {
        disarmBackspaceCancelMonitors()
        managedOllamaProcess?.terminate()
        managedOllamaProcess = nil
        launchpadRenderWorker?.stop()
        launchpadMIDIManager?.stop()
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
            await stopRecordingAndDictate(menuBarController: menuBarController)
        } else {
            await startRecording(menuBarController: menuBarController)
        }
    }

    @MainActor
    private func startRecording(menuBarController: MenuBarController?) async {
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
    private func stopRecordingAndDictate(menuBarController: MenuBarController?) async {
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
            let requestContext = recordingContext
            recordingContext = nil
            TraceLogger.log("recording stopped (bytes=\(capturedAudio.data.count), sampleRate=\(capturedAudio.sampleRate))")
            setDictationState(.thinking)
            menuBarController?.setIndicatorState(.refining)
            menuBarController?.setState("Transcribing + refining...")

            do {
                let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
                let request = DictateRequest(
                    audio_b64: capturedAudio.data.base64EncodedString(),
                    sample_rate: capturedAudio.sampleRate,
                    locale: locale,
                    session_id: sessionID,
                    optional_context: requestContext
                )
                let task = Task { [apiClient] in
                    try await apiClient.dictate(request)
                }
                setActiveDictationTask(task)
                let dictatedCall = try await task.value
                clearActiveDictationTask(task)
                let dictated = dictatedCall.response
                TraceLogger.log(
                    "dictate success (rawChars=\(dictated.raw_transcript.count), revisedChars=\(dictated.revised_text.count), transcribeMs=\(dictatedCall.transcribeMs), refineMs=\(dictatedCall.refineMs), summary=\(dictated.edit_summary))"
                )
                logRefinementMode(context: requestContext)
                TraceLogger.log("dictate raw transcript: \(Self.logSafeText(dictated.raw_transcript))")
                TraceLogger.log("dictate revised text: \(Self.logSafeText(dictated.revised_text))")
                if dictated.revised_text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    setDictationState(.idle)
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("No speech detected")
                    TraceLogger.log("dictate produced empty revised text; skipping insertion")
                    return
                }
                let insertResult = ClipboardInserter.insert(dictated.revised_text)
                switch insertResult {
                case .success:
                    setDictationState(.idle)
                    menuBarController?.setIndicatorState(.idle)
                    menuBarController?.setState("Inserted revised text")
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
                TraceLogger.log("dictate failed: \(error)")
            }
        }
    }

    private func hasOpenAIKey() -> Bool {
        if APIKeyResolver.environmentValue() != nil {
            return true
        }
        return secretStore.hasOpenAIKeyWithoutPrompt()
    }

    private func makeRefinementEngine() -> any RefinementEngine {
        let configuration = LLMRuntimeConfiguration.fromEnvironment()
        let ollama = OllamaRefinementEngine(
            host: configuration.ollamaHost,
            model: configuration.ollamaModel
        )
        let openAI = OpenAIRefinementEngine(
            model: configuration.openAIModel,
            secretStore: secretStore
        )
        return ProviderRoutingRefinementEngine(
            configuration: configuration,
            ollamaEngine: ollama,
            openAIEngine: openAI,
            canUseOpenAI: { [weak self] in
                self?.hasOpenAIKey() ?? false
            }
        )
    }

    private func startupReadyMessage() -> String {
        let base = "Ready (Caps Lock or Launchpad 0,0 toggles recording)"
        let configuration = LLMRuntimeConfiguration.fromEnvironment()
        switch configuration.provider {
        case .openai:
            if hasOpenAIKey() {
                return "\(base) [OpenAI]"
            }
            return "Ready: Set OpenAI key from menu or .env [OpenAI]"
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
        alert.informativeText = "Paste your API key. It will be stored in your macOS Keychain and used for optional fallback."
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
            try secretStore.setOpenAIKey(key)
            menuBarController.setState("Saved OpenAI fallback key")
        } catch {
            menuBarController.setState("Failed: Could not save OpenAI key")
        }
    }

    private func clearAPIKey(menuBarController: MenuBarController) {
        do {
            try secretStore.clearOpenAIKey()
            menuBarController.setState("Cleared OpenAI fallback key")
        } catch {
            menuBarController.setState("Failed: Could not clear OpenAI key")
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
                return "Missing OpenAI key (set from menu or .env)"
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
            }
        }
        if error is APIClientError {
            return "STT returned empty transcript"
        }
        return "Dictation request failed"
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

    private func setupLaunchpadIntegration() {
        if !KeyboardInjector.hasAccessibilityPermission() {
            _ = KeyboardInjector.requestAccessibilityPermissionPrompt()
            menuBarController?.setLaunchpadStatus("Enable Accessibility for keystrokes")
        } else {
            menuBarController?.setLaunchpadStatus("Keystrokes ready")
        }

        let invalidationBus = RenderInvalidationBus()
        let pageController = LaunchpadPageController(invalidationBus: invalidationBus)
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
            onContextualBackspace: { [weak self] in
                Task { @MainActor in
                    await self?.handleLaunchpadContextualBackspace()
                }
            },
            onAppReload: { [weak self] in
                Task { @MainActor in
                    self?.triggerAppReload()
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

        renderWorker.start()
        midiManager.start()
    }

    private func bootstrapOllamaIfNeeded() {
        let configuration = LLMRuntimeConfiguration.fromEnvironment()
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
        switch command {
        case .start:
            if currentDictationState() == .idle && !recordingController.isRecording {
                await startRecording(menuBarController: menuBarController)
            }
        case .stop:
            if currentDictationState() == .recording && recordingController.isRecording {
                await stopRecordingAndDictate(menuBarController: menuBarController)
            }
        case .cancel:
            cancelRecording(menuBarController: menuBarController)
        case .toggle:
            if currentDictationState() == .thinking {
                cancelThinking(menuBarController: menuBarController)
            } else if recordingController.isRecording {
                await stopRecordingAndDictate(menuBarController: menuBarController)
            } else {
                await startRecording(menuBarController: menuBarController)
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

    private func dispatchLaunchpadKeystroke(_ key: KeyboardKey, baseModifiers: Set<KeyboardModifier>) {
        var modifiers = baseModifiers
        modifiers.formUnion(modifiersForKeyPress(key))
        _ = keyboardInjector.send(key, modifiers: modifiers)
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
