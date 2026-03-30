//
//  ChatBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ChatSessionView: UIView {
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

        // TableView — card appearance (rounded corners, border, background)
        tableView.separatorStyle = .none
        tableView.backgroundColor = AppColors.bgCard
        tableView.layer.cornerRadius = 12
        tableView.layer.borderWidth = 0.5
        tableView.layer.borderColor = AppColors.borderDefault.cgColor
        tableView.clipsToBounds = true
        tableView.register(TranscriptMessageCell.self, forCellReuseIdentifier: TranscriptMessageCell.reuseIdentifier)
        addSubview(tableView)

        // Agent status — between tableView and control bar (matches Android layout)
        statusView.isHidden = true
        addSubview(statusView)

        // Control Bar — horizontal strip at bottom
        controlBarView.backgroundColor = AppColors.bgControlBar
        controlBarView.layer.cornerRadius = 12
        controlBarView.layer.borderWidth = 0.5
        controlBarView.layer.borderColor = AppColors.borderDefault.cgColor
        addSubview(controlBarView)

        // Mic Button (right side)
        micButton.setImage(UIImage(systemName: "mic.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        micButton.tintColor = AppColors.micNormalIcon
        micButton.backgroundColor = AppColors.micNormalBg
        micButton.layer.cornerRadius = 22
        controlBarView.addSubview(micButton)

        // Stop Button — wide pill shape
        endCallButton.setTitle("Stop Agent", for: .normal)
        endCallButton.setTitleColor(.white, for: .normal)
        endCallButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        endCallButton.backgroundColor = AppColors.btnStopBg
        endCallButton.layer.cornerRadius = 8
        endCallButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        controlBarView.addSubview(endCallButton)
    }

    private func setupConstraints() {
        // Control bar at bottom
        controlBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(60)
        }

        // Stop button — right side of control bar
        endCallButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
        }

        // Mic button — left of stop button
        micButton.snp.makeConstraints { make in
            make.right.equalTo(endCallButton.snp.left).offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }

        // Agent status — between tableView and control bar
        statusView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(controlBarView.snp.top).offset(-8)
            make.height.equalTo(40)
        }

        // TableView fills the space above status view
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(statusView.snp.top).offset(-8)
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

    // UIKit may reset the table background color to a system dynamic color during layout.
    // Apply it from the parent controller after the table has been attached to the final view hierarchy.
    func applyTableBackgroundWorkaround() {
        tableView.backgroundColor = UIColor(hex: 0x1E293B, alpha: 0.5)
    }
}
