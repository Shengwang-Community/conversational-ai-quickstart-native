//
//  VoiceAgentRootView.swift
//  VoiceAgent
//

import SwiftUI

private extension Color {
    static let appBgPrimary = Color(hex: 0x0F172A)
    static let appBgSecondary = Color(hex: 0x1E293B)
    static let appBgCard = Color(hex: 0x1E293B, opacity: 0.5)
    static let appBgControlBar = Color(hex: 0x1E293B, opacity: 0.8)
    static let appBgLog = Color(hex: 0x020617, opacity: 0.5)
    static let appBorder = Color(hex: 0x334155, opacity: 0.5)
    static let appTextSecondary = Color(hex: 0x94A3B8)
    static let appTextSubtitle = Color(hex: 0xCBD5E1)
    static let appAvatarAgent = Color(hex: 0x3B82F6)
    static let appAvatarUser = Color(hex: 0x10B981)
    static let appBubbleAgent = Color(hex: 0x334155)
    static let appBubbleUser = Color(hex: 0x2563EB)
    static let appMicNormalBg = Color(hex: 0x334155)
    static let appMicNormalIcon = Color(hex: 0xCBD5E1)
    static let appMicMutedBg = Color(hex: 0xEF4444, opacity: 0.2)
    static let appMicMutedIcon = Color(hex: 0xF87171)
    static let appButtonStart = Color(hex: 0x2563EB)
    static let appButtonStop = Color(hex: 0xDC2626)
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

struct VoiceAgentRootView: View {
    @StateObject private var viewModel = ChatSessionViewModel()

    var body: some View {
        VStack(spacing: 20) {
            DebugInfoView(debugMessages: viewModel.debugMessages)
                .frame(height: 120)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if viewModel.isShowingConnectionStartView {
                ConnectionStartView(viewModel: viewModel)
            } else {
                ChatSessionView(viewModel: viewModel)
            }
        }
        .background(Color.appBgPrimary.ignoresSafeArea())
        .alert("错误", isPresented: $viewModel.isError, actions: {
            Button("确定", role: .cancel) { }
        }, message: {
            Text(viewModel.initializationError?.localizedDescription ?? "发生错误")
        })
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(width: 100, height: 100)
                    .background(Color.appBgSecondary.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appBorder, lineWidth: 0.5)
                    )
                    .cornerRadius(12)
            }
        }
    }
}

struct DebugInfoView: View {
    let debugMessages: String

    var body: some View {
        ScrollViewReader { _ in
            UITextViewWrapper(text: debugMessages)
                .background(Color.appBgLog)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }
}

struct UITextViewWrapper: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = UIColor(Color.appTextSecondary)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.indicatorStyle = .white
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        if !text.isEmpty {
            let bottom = NSRange(location: max(text.count - 1, 0), length: 1)
            uiView.scrollRangeToVisible(bottom)
        }
    }
}

struct ConnectionStartView: View {
    @ObservedObject var viewModel: ChatSessionViewModel

    var body: some View {
        VStack {
            Spacer()
            Button(action: { viewModel.startConnection() }) {
                Text("Start Agent")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appButtonStart)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.clear)
    }
}

struct ChatSessionView: View {
    @ObservedObject var viewModel: ChatSessionViewModel

    var body: some View {
        VStack(spacing: 8) {
            TranscriptListView(transcripts: viewModel.transcripts)
                .padding(.horizontal, 20)

            AgentStateView(state: viewModel.agentState)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Spacer()
                Button(action: { viewModel.toggleMicrophone() }) {
                    Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundColor(viewModel.isMicMuted ? Color.appMicMutedIcon : Color.appMicNormalIcon)
                        .frame(width: 44, height: 44)
                        .background(viewModel.isMicMuted ? Color.appMicMutedBg : Color.appMicNormalBg)
                        .clipShape(Circle())
                }
                Button(action: { viewModel.endCall() }) {
                    Text("Stop Agent")
                        .foregroundColor(.white)
                        .frame(width: 120, height: 36)
                        .background(Color.appButtonStop)
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.appBgControlBar)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct TranscriptListView: View {
    let transcripts: [Transcript]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(transcripts.enumerated()), id: \.offset) { _, transcript in
                    TranscriptMessageRow(transcript: transcript)
                }
            }
            .padding(16)
        }
        .background(Color.appBgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
    }
}

struct TranscriptMessageRow: View {
    let transcript: Transcript

    var isAgent: Bool { transcript.type == .agent }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isAgent {
                avatar
            }
            Text(transcript.text)
                .foregroundColor(isAgent ? Color(hex: 0xF1F5F9) : .white)
                .padding(12)
                .background(isAgent ? Color.appBubbleAgent : Color.appBubbleUser)
                .cornerRadius(16)
                .frame(maxWidth: .infinity, alignment: isAgent ? .leading : .trailing)
            if !isAgent {
                avatar
            }
        }
    }

    var avatar: some View {
        Text(isAgent ? "AI" : "Me")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(isAgent ? Color.appAvatarAgent : Color.appAvatarUser)
            .clipShape(Circle())
    }
}

struct AgentStateView: View {
    let state: AgentState

    var body: some View {
        if state != .unknown {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.appTextSubtitle)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(backgroundColor)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
        }
    }

    var title: String {
        switch state {
        case .idle: return "Idle"
        case .silent: return "Silent"
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .speaking: return "Speaking"
        default: return ""
        }
    }

    var backgroundColor: Color {
        switch state {
        case .idle: return Color(hex: 0x64748B, opacity: 0.25)
        case .silent: return Color(hex: 0x475569, opacity: 0.25)
        case .listening: return Color(hex: 0x10B981, opacity: 0.2)
        case .thinking: return Color(hex: 0xF59E0B, opacity: 0.2)
        case .speaking: return Color(hex: 0x3B82F6, opacity: 0.2)
        default: return Color.appBgCard
        }
    }
}
