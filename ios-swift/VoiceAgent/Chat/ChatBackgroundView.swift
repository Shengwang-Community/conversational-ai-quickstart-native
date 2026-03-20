//
//  ChatBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ChatBackgroundView: UIView {
    // MARK: - UI Components
    let tableView = UITableView()
    let statusView = AgentStateView()
    private let controlBarView = UIView()
    let micButton = UIButton(type: .custom)
    let endCallButton = UIButton(type: .custom)

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear

        // TableView
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(TranscriptCell.self, forCellReuseIdentifier: "TranscriptCell")
        addSubview(tableView)

        // Status View
        addSubview(statusView)

        // Control Bar
        controlBarView.backgroundColor = AppColors.bgControlBar
        controlBarView.layer.cornerRadius = 12
        controlBarView.layer.borderWidth = 0.5
        controlBarView.layer.borderColor = AppColors.borderDefault.cgColor
        addSubview(controlBarView)

        // Mic Button
        micButton.setImage(UIImage(systemName: "mic.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        micButton.tintColor = AppColors.micNormalIcon
        micButton.backgroundColor = AppColors.micNormalBg
        micButton.layer.cornerRadius = 22
        controlBarView.addSubview(micButton)

        // End Call Button
        endCallButton.setImage(UIImage(systemName: "phone.down.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        endCallButton.tintColor = .white
        endCallButton.backgroundColor = AppColors.btnStopBg
        endCallButton.layer.cornerRadius = 22
        controlBarView.addSubview(endCallButton)
    }

    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(statusView.snp.top).offset(-8)
        }

        statusView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(controlBarView.snp.top).offset(-16)
            make.height.equalTo(36)
        }

        controlBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(60)
        }

        micButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(endCallButton.snp.left).offset(-24)
            make.width.height.equalTo(44)
        }

        endCallButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(44)
        }
    }

    // MARK: - Public Methods
    func updateMicButtonState(isMuted: Bool) {
        let imageName = isMuted ? "mic.slash.fill" : "mic.fill"
        micButton.setImage(UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        micButton.tintColor = isMuted ? AppColors.micMutedIcon : AppColors.micNormalIcon
        micButton.backgroundColor = isMuted ? AppColors.micMutedBg : AppColors.micNormalBg
    }

    func updateStatusView(state: AgentState) {
        statusView.updateState(state)
    }
}

// MARK: - TranscriptCell
class TranscriptCell: UITableViewCell {
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    private var bubbleLeading: Constraint?
    private var bubbleTrailing: Constraint?
    private var avatarLeading: Constraint?
    private var avatarTrailing: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Avatar
        avatarView.layer.cornerRadius = 16
        contentView.addSubview(avatarView)

        avatarLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)

        // Bubble
        bubbleView.layer.cornerRadius = 16
        contentView.addSubview(bubbleView)

        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        bubbleView.addSubview(messageLabel)

        // Avatar constraints (will toggle leading/trailing)
        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.width.height.equalTo(32)
            avatarLeading = make.left.equalToSuperview().offset(16).constraint
            avatarTrailing = make.right.equalToSuperview().offset(-16).constraint
        }
        avatarTrailing?.deactivate()

        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // Bubble constraints (will toggle leading/trailing)
        bubbleView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.75)
            bubbleLeading = make.left.equalTo(avatarView.snp.right).offset(8).constraint
            bubbleTrailing = make.right.equalTo(avatarView.snp.left).offset(-8).constraint
        }
        bubbleTrailing?.deactivate()

        messageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }

    func configure(with transcript: Transcript) {
        let isAgent = transcript.type == .agent

        // Avatar
        avatarView.backgroundColor = isAgent ? AppColors.avatarAgent : AppColors.avatarUser
        avatarLabel.text = isAgent ? "AI" : "Me"

        // Bubble
        bubbleView.backgroundColor = isAgent ? AppColors.bubbleAgentBg : AppColors.bubbleUserBg
        messageLabel.textColor = isAgent ? AppColors.bubbleAgentText : AppColors.bubbleUserText
        messageLabel.text = transcript.text

        // Bubble corner masking: agent top-left small, user top-right small
        let smallCorner: CGFloat = 2
        let bigCorner: CGFloat = 16
        if isAgent {
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            bubbleView.layer.cornerRadius = bigCorner
            // Use mask for the small top-left corner
            applyBubbleCorners(topLeft: smallCorner, topRight: bigCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
        } else {
            bubbleView.layer.cornerRadius = bigCorner
            applyBubbleCorners(topLeft: bigCorner, topRight: smallCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
        }

        // Layout direction
        if isAgent {
            avatarLeading?.activate()
            avatarTrailing?.deactivate()
            bubbleLeading?.activate()
            bubbleTrailing?.deactivate()
        } else {
            avatarLeading?.deactivate()
            avatarTrailing?.activate()
            bubbleLeading?.deactivate()
            bubbleTrailing?.activate()
        }
    }

    private func applyBubbleCorners(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        let path = UIBezierPath()
        // We apply this in layoutSubviews would be ideal, but for simplicity use a fixed approach
        // The layer.cornerRadius is set to 16 as default, we override with a mask
        bubbleView.layoutIfNeeded()
        let bounds = bubbleView.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 200, height: 40) : bubbleView.bounds

        path.move(to: CGPoint(x: topLeft, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - topRight, y: 0))
        path.addArc(withCenter: CGPoint(x: bounds.width - topRight, y: topRight), radius: topRight, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottomRight))
        path.addArc(withCenter: CGPoint(x: bounds.width - bottomRight, y: bounds.height - bottomRight), radius: bottomRight, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: bottomLeft, y: bounds.height))
        path.addArc(withCenter: CGPoint(x: bottomLeft, y: bounds.height - bottomLeft), radius: bottomLeft, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        path.addArc(withCenter: CGPoint(x: topLeft, y: topLeft), radius: topLeft, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        bubbleView.layer.mask = mask
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-apply bubble corners after layout
        if let text = avatarLabel.text {
            let isAgent = text == "AI"
            let smallCorner: CGFloat = 2
            let bigCorner: CGFloat = 16
            if isAgent {
                applyBubbleCorners(topLeft: smallCorner, topRight: bigCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
            } else {
                applyBubbleCorners(topLeft: bigCorner, topRight: smallCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
            }
        }
    }
}
