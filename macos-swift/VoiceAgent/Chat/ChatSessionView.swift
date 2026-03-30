//
//  ChatSessionView.swift
//  VoiceAgent
//

import Cocoa
import SnapKit

class ChatSessionView: NSView {
    private var transcripts: [Transcript] = []
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MessageColumn"))
    let statusView = AgentStateView()
    private let controlBarView = NSView()
    let micButton = NSButton(title: "", target: nil, action: nil)
    let endCallButton = NSButton(title: "Stop Agent", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        tableColumn.title = "Messages"
        tableView.addTableColumn(tableColumn)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.usesAutomaticRowHeights = true
        tableView.selectionHighlightStyle = .none
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let messageCardView = NSView()
        messageCardView.wantsLayer = true
        messageCardView.layer?.backgroundColor = AppColors.bgCard.cgColor
        messageCardView.layer?.cornerRadius = 12
        messageCardView.layer?.borderWidth = 0.5
        messageCardView.layer?.borderColor = AppColors.borderDefault.cgColor
        addSubview(messageCardView)
        messageCardView.addSubview(scrollView)

        statusView.isHidden = true
        addSubview(statusView)

        controlBarView.wantsLayer = true
        controlBarView.layer?.backgroundColor = AppColors.bgCard.withAlphaComponent(0.8).cgColor
        controlBarView.layer?.cornerRadius = 12
        controlBarView.layer?.borderWidth = 0.5
        controlBarView.layer?.borderColor = AppColors.borderDefault.cgColor
        addSubview(controlBarView)

        micButton.bezelStyle = .rounded
        micButton.title = "Mute"
        micButton.contentTintColor = AppColors.textSecondary
        controlBarView.addSubview(micButton)

        endCallButton.bezelStyle = .rounded
        endCallButton.contentTintColor = .white
        controlBarView.addSubview(endCallButton)
    }

    private func setupConstraints() {
        controlBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(60)
        }

        endCallButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
            make.width.equalTo(120)
        }

        micButton.snp.makeConstraints { make in
            make.right.equalTo(endCallButton.snp.left).offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
            make.width.equalTo(80)
        }

        statusView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(controlBarView.snp.top).offset(-8)
            make.height.equalTo(40)
        }

        if let messageCardView = scrollView.superview {
            messageCardView.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.left.right.equalToSuperview().inset(20)
                make.bottom.equalTo(statusView.snp.top).offset(-8)
            }
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.bottom.equalToSuperview()
        }
    }

    func updateMicButtonState(isMuted: Bool) {
        micButton.title = isMuted ? "Unmute" : "Mute"
    }

    func updateStatusView(state: AgentState) {
        statusView.updateState(state)
    }

    func updateTranscripts(_ transcripts: [Transcript]) {
        self.transcripts = transcripts
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if !self.transcripts.isEmpty {
                self.tableView.scrollRowToVisible(self.transcripts.count - 1)
            }
        }
    }
}

class LogView: NSView {
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private let fontSize: CGFloat = 9

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        addSubview(scrollView)

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

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

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
        textView.scrollToEndOfDocument(nil)
    }

    func clear() {
        textView.string = ""
    }
}

extension ChatSessionView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { transcripts.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("MessageCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? MessageCellView) ?? {
            let view = MessageCellView()
            view.identifier = identifier
            return view
        }()
        cell.configure(with: transcripts[row])
        return cell
    }
}
