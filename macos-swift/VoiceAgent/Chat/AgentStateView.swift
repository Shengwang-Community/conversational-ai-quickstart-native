//
//  AgentStateView.swift
//  VoiceAgent
//

import Cocoa
import SnapKit

class AgentStateView: NSView {
    private let statusLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupConstraints()
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = AppColors.bgCard.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 0.5
        layer?.borderColor = AppColors.borderDefault.cgColor

        statusLabel.alignment = .center
        statusLabel.textColor = AppColors.textSecondary
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.backgroundColor = .clear
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        addSubview(statusLabel)
    }

    private func setupConstraints() {
        statusLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }

    func updateState(_ state: AgentState) {
        if state == .unknown {
            isHidden = true
            return
        }

        isHidden = false
        let (text, color): (String, NSColor) = {
            switch state {
            case .idle: return ("Idle", NSColor(calibratedRed: 0x64/255.0, green: 0x74/255.0, blue: 0x8B/255.0, alpha: 1.0))
            case .silent: return ("Silent", NSColor(calibratedRed: 0x47/255.0, green: 0x55/255.0, blue: 0x69/255.0, alpha: 1.0))
            case .listening: return ("Listening", NSColor(calibratedRed: 0x10/255.0, green: 0xB9/255.0, blue: 0x81/255.0, alpha: 1.0))
            case .thinking: return ("Thinking", NSColor(calibratedRed: 0xF5/255.0, green: 0x9E/255.0, blue: 0x0B/255.0, alpha: 1.0))
            case .speaking: return ("Speaking", NSColor(calibratedRed: 0x3B/255.0, green: 0x82/255.0, blue: 0xF6/255.0, alpha: 1.0))
            case .unknown: return ("", NSColor.systemGray)
            @unknown default: return ("", NSColor.systemGray)
            }
        }()

        statusLabel.stringValue = text
        layer?.backgroundColor = color.withAlphaComponent(0.2).cgColor
    }
}
