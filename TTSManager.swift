import AVFoundation
import Cocoa

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var voices: [AVSpeechSynthesisVoice] = []
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var isSpeaking: Bool = false
    @Published var currentUtterance: AVSpeechUtterance?
    @Published var groupedVoices: [(language: String, voices: [AVSpeechSynthesisVoice])] = []
    @Published var speechRate: Float = 0.5

    override init() {
        super.init()
        synthesizer.delegate = self
        loadVoices()
    }

    func loadVoices() {
        voices = AVSpeechSynthesisVoice.speechVoices().sorted { $0.name < $1.name }

        var languageGroups: [String: [AVSpeechSynthesisVoice]] = [:]
        for voice in voices {
            let languageName = standardizeLanguageName(voice.language)
            if languageGroups[languageName] == nil {
                languageGroups[languageName] = []
            }
            languageGroups[languageName]?.append(voice)
        }

        let sortedLanguages = languageGroups.keys.sorted()
        groupedVoices = sortedLanguages.map { language in
            (language: language, voices: languageGroups[language]!.sorted { $0.name < $1.name })
        }

    }

    private func standardizeLanguageName(_ languageCode: String) -> String {
        let code = languageCode.lowercased()

        if code.hasPrefix("zh") {
            if code.contains("tw") || code.contains("hk") {
                return "繁體中文"
            } else {
                return "简体中文"
            }
        }

        if code.hasPrefix("en") {
            return "English"
        }

        if code.hasPrefix("ja") {
            return "日本語"
        }

        if code.hasPrefix("ko") {
            return "한국어"
        }

        if code.hasPrefix("fr") {
            return "Français"
        }

        if code.hasPrefix("de") {
            return "Deutsch"
        }

        if code.hasPrefix("es") {
            return "Español"
        }

        if code.hasPrefix("it") {
            return "Italiano"
        }

        if code.hasPrefix("ru") {
            return "Русский"
        }

        if code.hasPrefix("pt") {
            return "Português"
        }

        if code.hasPrefix("ar") {
            return "العربية"
        }

        if code.hasPrefix("th") {
            return "ไทย"
        }

        if code.hasPrefix("vi") {
            return "Tiếng Việt"
        }

        let locale = Locale(identifier: languageCode)
        if let localizedName = locale.localizedString(forLanguageCode: languageCode) {
            return localizedName
        }

        return languageCode
    }

    func speak(text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}