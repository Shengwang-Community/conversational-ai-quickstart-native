//
//  LogView.swift
//  VoiceAgent
//
//  Created on 2025/12/02.
//

import Cocoa
import SnapKit

/// A simple log view component for displaying log messages
class LogView: NSView {
    
    // MARK: - UI Components
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    
    // MARK: - Configuration
    private let fontSize: CGFloat = 9
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        wantsLayer = true
        
        // ScrollView
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        addSubview(scrollView)
        
        // TextView
        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .secondaryLabelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        
        // Layout
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Public API
    
    /// Add a log message with timestamp
    func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)\n"
        
        textView.textStorage?.append(NSAttributedString(
            string: logLine,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        
        // Auto-scroll to bottom
        textView.scrollToEndOfDocument(nil)
    }
    
    /// Clear all log messages
    func clear() {
        textView.string = ""
    }
}

