import SwiftUI

struct ModelSettingsView: View {
    @ObservedObject var whisperPrompt: WhisperPrompt
    @AppStorage("SelectedLanguage") private var selectedLanguage: String = "en"
    @AppStorage("IsTextFormattingEnabled") private var isTextFormattingEnabled = true
    @AppStorage("IsVADEnabled") private var isVADEnabled = true
    @AppStorage("AppendTrailingSpace") private var appendTrailingSpace = true
    @AppStorage("PrewarmModelOnWake") private var prewarmModelOnWake = true
    @State private var customPrompt: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Output Format")
                    .font(.headline)
                
                InfoTip(
                    title: "Output Format Guide",
                    message: "Unlike GPT, Voice Models(whisper) follows the style of your prompt rather than instructions. Use examples of your desired output format instead of commands.",
                    learnMoreURL: "https://cookbook.openai.com/examples/whisper_prompting_guide#comparison-with-gpt-prompting"
                )
                
                Spacer()
                
                Button(action: {
                    if isEditing {
                        // Save changes
                        whisperPrompt.setCustomPrompt(customPrompt, for: selectedLanguage)
                        isEditing = false
                    } else {
                        // Enter edit mode
                        customPrompt = whisperPrompt.getLanguagePrompt(for: selectedLanguage)
                        isEditing = true
                    }
                }) {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.caption)
                }
            }
            
            if isEditing {
                TextEditor(text: $customPrompt)
                    .font(.system(size: 12))
                    .padding(8)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
            } else {
                Text(whisperPrompt.getLanguagePrompt(for: selectedLanguage))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .fill(Color(.windowBackgroundColor).opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }

            Divider().padding(.vertical, 4)

            HStack {
                Toggle(isOn: $appendTrailingSpace) {
                    Text("Add space after paste")
                }
                .toggleStyle(.switch)
                
                InfoTip(
                    title: "Trailing Space",
                    message: "Automatically add a space after pasted text. Useful for space-delimited languages."
                )
            }

            HStack {
                Toggle(isOn: $isTextFormattingEnabled) {
                    Text("Automatic text formatting")
                }
                .toggleStyle(.switch)
                
                InfoTip(
                    title: "Automatic Text Formatting",
                    message: "Apply intelligent text formatting to break large block of text into paragraphs."
                )
            }

            HStack {
                Toggle(isOn: $isVADEnabled) {
                    Text("Voice Activity Detection (VAD)")
                }
                .toggleStyle(.switch)

                InfoTip(
                    title: "Voice Activity Detection",
                    message: "Detect speech segments and filter out silence to improve accuracy of local models."
                )
            }

            HStack {
                Toggle(isOn: $prewarmModelOnWake) {
                    Text("Prewarm model (Experimental)")
                }
                .toggleStyle(.switch)

                InfoTip(
                    title: "Prewarm Model (Experimental)",
                    message: "Turn this on if transcriptions with local models are taking longer than expected. Runs silent background transcription on app launch and wake to trigger optimization."
                )
            }

        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(DesignTokens.cornerRadiusCard)
        // Reset the editor when language changes
        .onChange(of: selectedLanguage) { oldValue, newValue in
            if isEditing {
                customPrompt = whisperPrompt.getLanguagePrompt(for: selectedLanguage)
            }
        }
    }
} 
