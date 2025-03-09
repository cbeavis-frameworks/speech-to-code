import Foundation
import AVFoundation
import Speech

/// A protocol that defines the delegate methods for VoiceProcessor
protocol VoiceProcessorDelegate: AnyObject {
    func voiceProcessor(_ processor: VoiceProcessor, didCaptureTranscription text: String)
    func voiceProcessor(_ processor: VoiceProcessor, didDetectVoiceActivity active: Bool)
    func voiceProcessor(_ processor: VoiceProcessor, didChangeAudioLevel level: Float)
}

/// A class that handles voice processing using macOS Speech Recognition framework
@available(macOS 10.15, *)
class VoiceProcessor: NSObject, ObservableObject, @unchecked Sendable {
    enum VoiceProcessorState: Equatable {
        case inactive
        case recording
        case processing
        case speaking
        case error(String)
        
        static func == (lhs: VoiceProcessorState, rhs: VoiceProcessorState) -> Bool {
            switch (lhs, rhs) {
            case (.inactive, .inactive):
                return true
            case (.recording, .recording):
                return true
            case (.processing, .processing):
                return true
            case (.speaking, .speaking):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    // MARK: - Published Properties
    @Published var state: VoiceProcessorState = .inactive
    @Published var audioLevel: Float = 0.0
    @Published var isVADActive: Bool = false
    @Published var transcription: String = ""
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private let audioPlayer = AVAudioPlayerNode()
    private var audioMixer: AVAudioMixerNode?
    private var audioFormat: AVAudioFormat?
    
    // Voice activity detection
    private var vadThreshold: Float = 0.05
    private var silenceTimer: Timer?
    private var silenceDuration: TimeInterval = 1.0
    private var vadActive: Bool = false
    
    // Callback closures
    private var transcriptionHandler: ((String) -> Void)?
    private var vadActivationHandler: ((Bool) -> Void)?
    private var audioLevelHandler: ((Float) -> Void)?
    
    override init() {
        super.init()
        setupSpeechRecognition()
        setupAudioEngine()
    }
    
    // MARK: - Setup
    
    /// Sets up the speech recognition
    private func setupSpeechRecognition() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            state = .error("Speech recognition not available")
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorization granted")
                case .denied:
                    self.state = .error("Speech recognition authorization denied")
                case .restricted:
                    self.state = .error("Speech recognition is restricted on this device")
                case .notDetermined:
                    self.state = .error("Speech recognition authorization not determined")
                @unknown default:
                    self.state = .error("Unknown speech recognition authorization status")
                }
            }
        }
    }
    
    /// Sets up the audio engine for recording and monitoring
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            state = .error("Failed to create audio engine")
            return
        }
        
        // Get the input node for microphone access
        let inputNode = audioEngine.inputNode
        
        // Add a mixer node for audio level monitoring
        audioMixer = AVAudioMixerNode()
        guard let audioMixer = audioMixer else {
            state = .error("Failed to create audio mixer")
            return
        }
        
        // Standard audio format for speech recognition
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        guard let audioFormat = audioFormat else {
            state = .error("Failed to create audio format")
            return
        }
        
        // Connect input to mixer
        audioEngine.attach(audioMixer)
        audioEngine.connect(inputNode, to: audioMixer, format: audioFormat)
        
        // Setup audio player for synthesized speech
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFormat)
        
        // Install a tap on the mixer to monitor audio levels
        audioMixer.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Calculate audio level for visualization/VAD
            let channelData = buffer.floatChannelData?[0]
            if let channelData = channelData {
                let frameLength = UInt(buffer.frameLength)
                
                // Calculate RMS of audio signal
                var sum: Float = 0
                for i in 0..<Int(frameLength) {
                    sum += channelData[i] * channelData[i]
                }
                
                let rms = sqrt(sum / Float(frameLength))
                
                // Update audio level on main thread
                DispatchQueue.main.async {
                    self.audioLevel = rms
                    self.audioLevelHandler?(rms)
                    self.checkVoiceActivityDetection(level: rms)
                }
            }
        }
    }
    
    // MARK: - Voice Activation Detection
    
    /// Checks if voice is present in the audio by comparing against threshold
    /// - Parameter level: Current audio level
    private func checkVoiceActivityDetection(level: Float) {
        if level > vadThreshold && !vadActive {
            // Voice detected - start of utterance
            vadActive = true
            isVADActive = true
            vadActivationHandler?(true)
            
            // Cancel any pending silence timer
            silenceTimer?.invalidate()
            
        } else if level <= vadThreshold && vadActive {
            // Potential silence - start timer
            silenceTimer?.invalidate()
            silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDuration, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                // Silence long enough - end of utterance
                self.vadActive = false
                self.isVADActive = false
                self.vadActivationHandler?(false)
                
                // If we're in recording state, finish recognition
                if case .recording = self.state {
                    self.stopRecording()
                }
            }
        }
    }
    
    /// Detects if voice activity is present in the audio
    /// - Parameter level: Current audio level
    /// - Returns: Boolean indicating if voice is active
    func detectVoiceActivity(level: Float) -> Bool {
        return level > vadThreshold
    }
    
    /// Returns whether voice is currently active
    /// - Returns: Boolean indicating if voice is active
    func isVoiceActive() -> Bool {
        return vadActive
    }
    
    // MARK: - Public Methods
    
    /// Starts the speech recognition process
    /// - Returns: Boolean indicating success
    func startRecording() -> Bool {
        // Cancel any existing recognition task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        guard let audioEngine = audioEngine, state == .inactive,
              let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return false
        }
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            state = .error("Unable to create speech recognition request")
            return false
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                // Update the transcription
                let transcribedString = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcription = transcribedString
                    self.transcriptionHandler?(transcribedString)
                }
                
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // Stop audio engine and recognition
                audioEngine.stop()
                
                audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.state = .inactive
                }
            }
        }
        
        // Feed audio from the engine to the recognition request
        
        do {
            try audioEngine.start()
            state = .recording
            return true
        } catch {
            state = .error("Could not start audio engine: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Stops the speech recognition process
    func stopRecording() {
        // Stop audio engine
        if let audioEngine = audioEngine, audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        
        // End the recognition request
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.state = .inactive
        }
    }
    
    /// Processes the recorded speech to get the final transcription
    /// - Returns: The transcribed text
    func processRecordedSpeech() -> String {
        // End recognition and get final result
        stopRecording()
        return transcription
    }
    
    /// Plays synthesized speech for AI responses
    /// - Parameter text: The text to be spoken
    /// - Returns: Boolean indicating success
    func playSpeech(_ text: String) -> Bool {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        DispatchQueue.main.async {
            self.state = .speaking
        }
        
        synthesizer.speak(utterance)
        
        DispatchQueue.main.async {
            self.state = .inactive
        }
        
        return true
    }
    
    // MARK: - Registration Methods
    
    /// Register a callback for transcription updates
    /// - Parameter handler: The callback closure
    func onTranscription(_ handler: @escaping (String) -> Void) {
        transcriptionHandler = handler
    }
    
    /// Register a callback for voice activation changes
    /// - Parameter handler: The callback closure
    func onVoiceActivation(_ handler: @escaping (Bool) -> Void) {
        vadActivationHandler = handler
    }
    
    /// Register a callback for audio level updates
    /// - Parameter handler: The callback closure
    func onAudioLevel(_ handler: @escaping (Float) -> Void) {
        audioLevelHandler = handler
    }
}
