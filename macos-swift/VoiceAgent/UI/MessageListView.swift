//
//  MessageListView.swift
//  VoiceAgent
//
//  Created by HeZhengQing on 2025/11/17.
//

import Cocoa
import SnapKit

// MARK: - Message List View
/// Custom view for displaying transcript messages with NSTableView
class MessageListView: NSView {
    
    // MARK: - Properties
    private var transcripts: [Transcript] = []
    
    // UI Components
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MessageColumn"))
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Configure table column
        tableColumn.title = "Messages"
        tableColumn.width = 400
        tableView.addTableColumn(tableColumn)
        
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil // Hide header
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.rowSizeStyle = .default
        tableView.usesAutomaticRowHeights = true
        tableView.selectionHighlightStyle = .none
        
        // Configure scroll view
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        
        addSubview(scrollView)
        
        // Layout
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    
    /// Update the message list with new transcripts
    /// - Parameter transcripts: Array of Transcript objects
    func updateTranscripts(_ transcripts: [Transcript]) {
        self.transcripts = transcripts
        
        // Ensure UI updates on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            
            // Auto-scroll to bottom
            if !self.transcripts.isEmpty {
                let lastRow = self.transcripts.count - 1
                self.tableView.scrollRowToVisible(lastRow)
            }
        }
    }
    
    /// Clear all messages
    func clearMessages() {
        transcripts.removeAll()
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    /// Get current message count
    var messageCount: Int {
        return transcripts.count
    }
}

// MARK: - NSTableViewDataSource
extension MessageListView: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return transcripts.count
    }
}

// MARK: - NSTableViewDelegate
extension MessageListView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("MessageCell")
        
        // Reuse or create cell
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? MessageCellView
        if cellView == nil {
            cellView = MessageCellView()
            cellView?.identifier = identifier
        }
        
        // Configure cell with transcript data
        let transcript = transcripts[row]
        cellView?.configure(with: transcript)
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // Dynamic height based on content (minimum 44pt)
        return max(60, CGFloat(transcripts[row].text.count / 30 * 20 + 44))
    }
}

// MARK: - Message Cell View
/// Custom cell view for displaying a single transcript message
class MessageCellView: NSTableCellView {
    
    // MARK: - UI Components
    private let idLabel = NSTextField()
    private let messageLabel = NSTextField()
    private let containerView = NSView()
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        wantsLayer = true
        
        // Configure container view
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Configure ID label
        idLabel.isEditable = false
        idLabel.isBordered = false
        idLabel.backgroundColor = .clear
        idLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        idLabel.textColor = .secondaryLabelColor
        idLabel.lineBreakMode = .byTruncatingMiddle
        
        // Configure message label
        messageLabel.isEditable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = .clear
        messageLabel.font = NSFont.systemFont(ofSize: 13)
        messageLabel.textColor = .labelColor
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        
        // Add subviews
        addSubview(containerView)
        containerView.addSubview(idLabel)
        containerView.addSubview(messageLabel)
        
        // Layout constraints
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
        
        idLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(16)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(idLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-8)
        }
    }
    
    // MARK: - Configuration
    
    /// Configure cell with transcript data
    /// - Parameter transcript: Transcript object to display
    func configure(with transcript: Transcript) {
        // Format ID based on type
        let typePrefix = transcript.type == .user ? "User" : "Agent"
        let idText = "\(typePrefix) • ID: \(transcript.userId) • Turn: \(transcript.turnId)"
        idLabel.stringValue = idText
        
        // Set message text
        messageLabel.stringValue = transcript.text
        
        // Style based on type
        switch transcript.type {
        case .user:
            containerView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
            messageLabel.textColor = .systemBlue
            idLabel.textColor = NSColor.systemBlue.withAlphaComponent(0.7)
            
        case .agent:
            containerView.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1).cgColor
            messageLabel.textColor = .systemGreen
            idLabel.textColor = NSColor.systemGreen.withAlphaComponent(0.7)
            
        @unknown default:
            break
        }
        
        // Add badge for incomplete transcripts
        if transcript.status != .end {
            messageLabel.stringValue += " ..."
        }
    }
}
