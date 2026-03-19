import SwiftUI
import AVFoundation
import Cocoa

struct ContentView: View {
    @StateObject private var ttsManager = TTSManager()
    @State private var textToSpeak: String = ""
    @State private var showTextSavePanel: Bool = false
    @State private var showTextOpenPanel: Bool = false
    @State private var saveProgress: Double = 0.0
    @State private var isSaving: Bool = false
    @State private var saveAlert: AlertData?
    @State private var selectedFormat: AudioFormat = .wav
    @State private var selectedLanguage: String = ""
    @State private var lastSetLanguage: String = ""
@State private var fontSize: CGFloat = 14
    @State private var speechRate: Float = 0.5
    @State private var isLoadingSettings: Bool = false
    @State private var countingNumber: Int? = nil
    @State private var isFirstClick: Bool = true
    @FocusState private var isTextEditorFocused: Bool

    private let defaults = UserDefaults.standard
    private let selectedLanguageKey = "selectedLanguage"
    private let selectedVoiceKey = "selectedVoice"
    private let selectedFormatKey = "selectedFormat"
    private let fontSizeKey = "fontSize"

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Button(action: {
                        showTextOpenPanel = true
                    }) {
                        Label("讀取檔案", systemImage: "doc")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        showTextSavePanel = true
                    }) {
                        Label("匯出檔案", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    Divider()
                        .frame(height: 20)

                    HStack(spacing: 4) {
                        Button(action: {
                            if fontSize > 10 {
                                fontSize -= 1
                                defaults.set(fontSize, forKey: fontSizeKey)
                            }
                        }) {
                            Image(systemName: "minus")
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(fontSize))")
                            .frame(width: 20)
                            .font(.system(size: 12))
                            .frame(minWidth: 20)

                        Button(action: {
                            if fontSize < 32 {
                                fontSize += 1
                                defaults.set(fontSize, forKey: fontSizeKey)
                            }
                        }) {
                            Image(systemName: "plus")
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(height: 20)

                    HStack(spacing: 4) {
                        Text("\(Int(speechRate * 200))%")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                        Slider(value: $speechRate, in: 0.025...1.25, step: 0.025)
                            .frame(width: 100)
                            .onChange(of: speechRate) { newValue in
                                ttsManager.speechRate = newValue
                            }
                    }

                    Divider()
                        .frame(height: 20)

                    HStack(spacing: 4) {
                        Text("計數:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)
                        TextField("", text: Binding(
                            get: {
                                if let number = countingNumber {
                                    return "\(number)"
                                } else {
                                    return ""
                                }
                            },
                            set: { newValue in
                                if isFirstClick && newValue.isEmpty {
                                    countingNumber = 1
                                    isFirstClick = false
                                } else if let number = Int(newValue) {
                                    countingNumber = number
                                } else if newValue.isEmpty {
                                    countingNumber = nil
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .font(.system(size: 11))
                        .onTapGesture {
                            if isFirstClick && countingNumber == nil {
                                countingNumber = 1
                                isFirstClick = false
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("語言:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)
                        Picker("", selection: $selectedLanguage) {
                            ForEach(ttsManager.groupedVoices, id: \.language) { group in
                                Text(group.language).tag(group.language)
                            }
                        }
                        .frame(width: 110)
                        .labelsHidden()
                        .onChange(of: selectedLanguage) { newLanguage in
                            guard !isLoadingSettings else { return }
                            
                            guard newLanguage != lastSetLanguage else { return }
                            
                            if let group = ttsManager.groupedVoices.first(where: { $0.language == newLanguage }),
                               let firstVoice = group.voices.first {
                                ttsManager.selectedVoice = firstVoice
                                defaults.set(newLanguage, forKey: selectedLanguageKey)
                                lastSetLanguage = newLanguage
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Text("講述人:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 38, alignment: .trailing)
                        Picker("", selection: $ttsManager.selectedVoice) {
                            ForEach(currentLanguageVoices, id: \.self) { voice in
                                Text(voice.name).tag(voice as AVSpeechSynthesisVoice?)
                            }
                        }
                        .frame(width: 120)
                        .labelsHidden()
                        .onChange(of: ttsManager.selectedVoice) { newVoice in
                            guard !isLoadingSettings else { return }
                            
                            if let voice = newVoice {
                                defaults.set(voice.name, forKey: selectedVoiceKey)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Text("儲存為:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 38, alignment: .trailing)
                        Picker("", selection: $selectedFormat) {
                            ForEach(AudioFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .frame(width: 90)
                        .labelsHidden()
                        .onChange(of: selectedFormat) { newFormat in
                            defaults.set(newFormat.fileExtension, forKey: selectedFormatKey)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            TextEditor(text: $textToSpeak)
                .font(.system(size: fontSize))
                .focused($isTextEditorFocused)
                .frame(minHeight: 300)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        .background(Color(NSColor.textBackgroundColor))
                )
                .cornerRadius(8)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button(action: {
                    if !textToSpeak.isEmpty {
                        if ttsManager.isSpeaking {
                            ttsManager.stopSpeaking()
                        } else {
                            ttsManager.speak(text: textToSpeak)
                        }
                    }
                }) {
                    Label(ttsManager.isSpeaking ? "停止" : "試聽", systemImage: ttsManager.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .disabled(textToSpeak.isEmpty)
                .buttonStyle(.borderedProminent)

                Button(action: {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.audio]
                    savePanel.nameFieldStringValue = generateFilename()
                    savePanel.canCreateDirectories = false
                    
                    if savePanel.runModal() == .OK, let url = savePanel.url {
                        saveToURL(url)
                    }
                }) {
                    Label("匯出音檔", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .disabled(textToSpeak.isEmpty || isSaving)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)

            if isSaving {
                ProgressView(value: saveProgress)
                    .padding(.horizontal, 20)
                    .progressViewStyle(LinearProgressViewStyle())
                Text("正在匯出中，請稍候……   （文本越長匯出速度越慢……")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 1100, minHeight: 700)
        .fileExporter(
            isPresented: $showTextSavePanel,
            document: PlainTextDocument(text: textToSpeak),
            contentType: .plainText,
            defaultFilename: generateTextFilename()
        ) { result in
            switch result {
            case .success(let url):
                saveAlert = AlertData(
                    title: "儲存成功",
                    message: "文本文件已儲存到：\(url.path)"
                )
            case .failure(let error):
                saveAlert = AlertData(
                    title: "儲存失敗",
                    message: "無法儲存文本文件：\(error.localizedDescription)"
                )
            }
        }
        .fileImporter(
            isPresented: $showTextOpenPanel,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadTextFile(url)
                }
            case .failure(let error):
                saveAlert = AlertData(
                    title: "開啟失敗",
                    message: "無法開啟文件：\(error.localizedDescription)"
                )
            }
        }
        .alert(item: $saveAlert) { alertData in
            Alert(
                title: Text(alertData.title),
                message: Text(alertData.message),
                dismissButton: .default(Text("確定"))
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextEditorFocused = true
            }
            loadSavedSettings()
        }
    }

    private func loadSavedSettings() {
        isLoadingSettings = true
        
        let savedVoiceName = defaults.string(forKey: selectedVoiceKey)
        let savedLanguage = defaults.string(forKey: selectedLanguageKey)
        
        if let savedFontSize = defaults.value(forKey: fontSizeKey) as? CGFloat {
            fontSize = savedFontSize
        }

        if let savedFormat = defaults.string(forKey: selectedFormatKey) {
            switch savedFormat {
            case "aiff": selectedFormat = .aiff
            case "wav": selectedFormat = .wav
            case "m4a": selectedFormat = .m4a
            default: break
            }
        }

        var voiceFound = false
        if let savedVoiceName = savedVoiceName, !savedVoiceName.isEmpty {
            if let savedVoice = ttsManager.voices.first(where: { $0.name == savedVoiceName }) {
                ttsManager.selectedVoice = savedVoice
                for group in ttsManager.groupedVoices {
                    if group.voices.contains(where: { $0.identifier == savedVoice.identifier }) {
                        selectedLanguage = group.language
                        lastSetLanguage = group.language
                        voiceFound = true
                        break
                    }
                }
            }
        }

        if !voiceFound {
            if let savedLanguage = savedLanguage, !savedLanguage.isEmpty {
                if ttsManager.groupedVoices.contains(where: { $0.language == savedLanguage }) {
                    selectedLanguage = savedLanguage
                    lastSetLanguage = savedLanguage
                    if let group = ttsManager.groupedVoices.first(where: { $0.language == savedLanguage }),
                       let firstVoice = group.voices.first {
                        ttsManager.selectedVoice = firstVoice
                        voiceFound = true
                    }
                }
            }
        }

        if !voiceFound && !ttsManager.groupedVoices.isEmpty {
            selectedLanguage = ttsManager.groupedVoices[0].language
            lastSetLanguage = ttsManager.groupedVoices[0].language
            if let firstVoice = ttsManager.groupedVoices[0].voices.first {
                ttsManager.selectedVoice = firstVoice
            }
        }
        
        isLoadingSettings = false
    }

    private var currentLanguageVoices: [AVSpeechSynthesisVoice] {
        if let group = ttsManager.groupedVoices.first(where: { $0.language == selectedLanguage }) {
            return group.voices
        }
        return []
    }

    private func loadTextFile(_ url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            textToSpeak = content
        } catch {
            saveAlert = AlertData(
                title: "讀取失敗",
                message: "無法讀取文件內容：\(error.localizedDescription)"
            )
        }
    }

    private func generateTextFilename() -> String {
        let prefix = extractFilenamePrefix()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "\(prefix)_\(timestamp).txt"
    }

    private func extractFilenamePrefix() -> String {
        let text = textToSpeak.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if text.isEmpty {
            return "未命名"
        }
        
        let englishCharCount = text.filter { $0.isASCII && $0.isLetter }.count
        let totalCharCount = text.filter { $0.isLetter }.count
        let isEnglishLike = totalCharCount > 0 && Double(englishCharCount) / Double(totalCharCount) > 0.7
        
        var prefix: String
        
        if isEnglishLike {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            var selectedWords: [String] = []
            
            for word in words.prefix(5) {
                var trimmedWord = word
                if trimmedWord.count > 30 {
                    let index = trimmedWord.index(trimmedWord.startIndex, offsetBy: 30)
                    trimmedWord = String(trimmedWord[..<index])
                }
                selectedWords.append(trimmedWord)
            }
            
            prefix = selectedWords.joined(separator: "_")
        } else {
            let endIndex = text.index(text.startIndex, offsetBy: min(10, text.count))
            prefix = String(text[..<endIndex])
        }
        
        let invalidChars = CharacterSet(charactersIn: "/\\?%*:|\"<>")
        prefix = prefix.components(separatedBy: invalidChars).joined(separator: "_")
        
        if prefix.isEmpty {
            return "未命名"
        }
        
        return prefix
    }

    private func saveToURL(_ url: URL) {
        isSaving = true
        saveProgress = 0.0

        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory
            let tempAiff = tempDir.appendingPathComponent(UUID().uuidString + ".aiff")
            let tempTextFile = tempDir.appendingPathComponent(UUID().uuidString + ".txt")

            defer {
                do {
                    if FileManager.default.fileExists(atPath: tempAiff.path) {
                        try FileManager.default.removeItem(at: tempAiff)
                    }
                    if FileManager.default.fileExists(atPath: tempTextFile.path) {
                        try FileManager.default.removeItem(at: tempTextFile)
                    }
                } catch {
                    print("清理临时文件失败: \(error.localizedDescription)")
                }
            }

            do {
                DispatchQueue.main.async {
                    saveProgress = 0.1
                }

                let voiceName = ttsManager.selectedVoice?.name ?? ""

                try textToSpeak.write(to: tempTextFile, atomically: true, encoding: .utf8)

                DispatchQueue.main.async {
                    saveProgress = 0.3
                }

                var sayCommand = "say"
                if !voiceName.isEmpty {
                    sayCommand += " -v \"\(voiceName)\""
                }
                let sayRate = Int(speechRate * 400)
                sayCommand += " -r \(sayRate)"
                sayCommand += " -f \"\(tempTextFile.path)\" -o \"\(tempAiff.path)\""

                let task = Process()
                task.launchPath = "/bin/bash"
                task.arguments = ["-c", sayCommand]

                try task.run()
                task.waitUntilExit()

                if task.terminationStatus != 0 {
                    throw NSError(domain: "TTS", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "say命令执行失败"])
                }

                DispatchQueue.main.async {
                    saveProgress = 0.7
                }

                var outputFile = url

                let expectedExtension = selectedFormat.fileExtension
                let actualExtension = outputFile.pathExtension.lowercased()

                if actualExtension != expectedExtension {
                    let pathWithoutExtension = outputFile.deletingPathExtension()
                    outputFile = pathWithoutExtension.appendingPathExtension(expectedExtension)
                }

                if FileManager.default.fileExists(atPath: outputFile.path) {
                    try FileManager.default.removeItem(at: outputFile)
                }

                switch selectedFormat {
                case .aiff:
                    try FileManager.default.moveItem(at: tempAiff, to: outputFile)
                case .wav:
                    try self.convertToWAV(inputFile: tempAiff, outputFile: outputFile)
                case .m4a:
                    try self.convertToM4A(inputFile: tempAiff, outputFile: outputFile)
                }

                DispatchQueue.main.async {
                    saveProgress = 0.9
                }

                DispatchQueue.main.async {
                    isSaving = false
                    saveProgress = 1.0
                    if countingNumber != nil {
                        countingNumber! += 1
                    }
                    saveAlert = AlertData(
                        title: "儲存成功",
                        message: "音訊文件已儲存到：\(url.path)"
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    isSaving = false
                    saveProgress = 0.0
                    saveAlert = AlertData(
                        title: "儲存失敗",
                        message: "無法儲存音訊文件：\(error.localizedDescription)"
                    )
                }
            }
        }
    }

    private func convertToM4A(inputFile: URL, outputFile: URL) throws {
        let asset = AVAsset(url: inputFile)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
        }

        exportSession.outputURL = outputFile
        exportSession.outputFileType = .m4a

        let group = DispatchGroup()
        group.enter()

        exportSession.exportAsynchronously {
            group.leave()
        }

        group.wait()

        switch exportSession.status {
        case .completed:
            return
        case .failed:
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频转换失败: \(exportSession.error?.localizedDescription ?? "未知错误")"])
        case .cancelled:
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频转换已取消"])
        default:
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频转换失败: 未知状态"])
        }
    }

    private func convertToWAV(inputFile: URL, outputFile: URL) throws {
        let asset = AVAsset(url: inputFile)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
        }

        exportSession.outputURL = outputFile
        exportSession.outputFileType = .wav

        let group = DispatchGroup()
        group.enter()

        exportSession.exportAsynchronously {
            group.leave()
        }

        group.wait()

        switch exportSession.status {
        case .completed:
            return
        case .failed:
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频转换失败: \(exportSession.error?.localizedDescription ?? "未知错误")"])
        case .cancelled:
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频转换已取消"])
        default:
            throw NSError(domain: "TTS", code: 1, userInfo: [NSLocalizedDescriptionKey: "音频转换失败: 未知状态"])
        }
    }

    private func generateFilename() -> String {
        let prefix = extractFilenamePrefix()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        if let count = countingNumber {
            return "\(count)_\(prefix)_\(timestamp).\(selectedFormat.fileExtension)"
        } else {
            return "\(prefix)_\(timestamp).\(selectedFormat.fileExtension)"
        }
    }
}

struct AlertData: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        self.text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

enum AudioFormat: CaseIterable {
    case aiff
    case wav
    case m4a

    var fileExtension: String {
        switch self {
        case .aiff:
            return "aiff"
        case .wav:
            return "wav"
        case .m4a:
            return "m4a"
        }
    }

    var displayName: String {
        switch self {
        case .aiff:
            return "AIFF"
        case .wav:
            return "WAV"
        case .m4a:
            return "M4A (AAC)"
        }
    }

    var utType: UTType {
        switch self {
        case .aiff:
            return UTType(filenameExtension: "aiff") ?? UTType("public.audio")!
        case .wav:
            return UTType(filenameExtension: "wav") ?? UTType("public.audio")!
        case .m4a:
            return UTType(filenameExtension: "m4a") ?? UTType("public.audio")!
        }
    }
}
