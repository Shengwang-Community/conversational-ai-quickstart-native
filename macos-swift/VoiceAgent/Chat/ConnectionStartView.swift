//
//  ConnectionStartView.swift
//  VoiceAgent
//

import Cocoa
import SnapKit

class ConnectionStartView: NSView {
    let startButton = NSButton(title: "Start Agent", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        startButton.bezelStyle = .rounded
        startButton.font = .systemFont(ofSize: 12, weight: .medium)
        addSubview(startButton)
        startButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(44)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateButtonState(isEnabled: Bool) {
        startButton.isEnabled = isEnabled
    }
}
