//
//  TranscriptMessageCell.swift
//  VoiceAgent
//

import Cocoa
import SnapKit

class TranscriptMessageCell: NSTableCellView {}

class MessageCellView: NSTableCellView {
    private let idLabel = NSTextField()
    private let messageLabel = NSTextField()
    private let containerView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 16
        containerView.layer?.backgroundColor = AppColors.bgCard.cgColor

        idLabel.isEditable = false
        idLabel.isBordered = false
        idLabel.backgroundColor = .clear
        idLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        idLabel.textColor = AppColors.textSecondary

        messageLabel.isEditable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = .clear
        messageLabel.font = NSFont.systemFont(ofSize: 14)
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.cell?.wraps = true
        messageLabel.cell?.isScrollable = false
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        messageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        addSubview(containerView)
        containerView.addSubview(idLabel)
        containerView.addSubview(messageLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
        idLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(idLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
    }

    func configure(with transcript: Transcript) {
        let typePrefix = transcript.type == .user ? "User" : "Agent"
        idLabel.stringValue = "\(typePrefix) • ID: \(transcript.userId) • Turn: \(transcript.turnId)"
        messageLabel.stringValue = transcript.text + (transcript.status != .end ? " ..." : "")

        if transcript.type == .user {
            containerView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
            messageLabel.textColor = .white
            idLabel.textColor = NSColor.systemBlue.withAlphaComponent(0.8)
        } else {
            containerView.layer?.backgroundColor = AppColors.bgCard.cgColor
            messageLabel.textColor = NSColor(calibratedRed: 0xF1/255.0, green: 0xF5/255.0, blue: 0xF9/255.0, alpha: 1.0)
            idLabel.textColor = AppColors.textSecondary
        }
    }
}
