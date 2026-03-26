//
//  AgentView.swift
//  VoiceAgent
//

import SwiftUI

struct AgentView: View {
    @StateObject private var viewModel = AgentViewModel()

    var body: some View {
        VStack(spacing: 20) {
            DebugInfoView(debugMessages: viewModel.debugMessages)
                .frame(height: 120)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if viewModel.showConfigView {
                ConfigView(viewModel: viewModel)
            } else {
                ChatView(viewModel: viewModel)
            }
        }
        .background(Color(.systemBackground))
        .alert("错误", isPresented: $viewModel.isError, actions: {
            Button("确定", role: .cancel) { }
        }, message: {
            Text(viewModel.initializationError?.localizedDescription ?? "发生错误")
        })
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(width: 100, height: 100)
                    .background(.ultraThinMaterial)
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
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
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
        textView.textColor = .secondaryLabel
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
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

struct ConfigView: View {
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        VStack {
            Spacer()
            Button(action: { viewModel.startConnection() }) {
                Text("Start Agent")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct ChatView: View {
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        VStack(spacing: 8) {
            TranscriptScrollView(transcripts: viewModel.transcripts)
                .padding(.horizontal, 20)

            AgentStateView(state: viewModel.agentState)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Spacer()
                Button(action: { viewModel.toggleMicrophone() }) {
                    Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                Button(action: { viewModel.endCall() }) {
                    Text("Stop Agent")
                        .foregroundColor(.white)
                        .frame(width: 120, height: 36)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(uiColor: .separator), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct TranscriptScrollView: View {
    let transcripts: [Transcript]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(transcripts.enumerated()), id: \.offset) { _, transcript in
                    TranscriptRow(transcript: transcript)
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
    }
}

struct TranscriptRow: View {
    let transcript: Transcript

    var isAgent: Bool { transcript.type == .agent }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isAgent {
                avatar
            }
            Text(transcript.text)
                .foregroundColor(.primary)
                .padding(12)
                .background(isAgent ? Color.blue.opacity(0.08) : Color.green.opacity(0.12))
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
            .background(isAgent ? Color.blue : Color.green)
            .clipShape(Circle())
    }
}

struct AgentStateView: View {
    let state: AgentState

    var body: some View {
        if state != .unknown {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
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
}
