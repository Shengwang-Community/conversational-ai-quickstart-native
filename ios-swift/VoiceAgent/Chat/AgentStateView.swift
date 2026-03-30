//
//  AgentStateView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class AgentStateView: UIView {
    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AppColors.bgCard
        layer.cornerRadius = 12
        layer.borderWidth = 0.5
        layer.borderColor = AppColors.borderDefault.cgColor

        statusLabel.textColor = AppColors.textSubtitle
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
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
        let (text, color): (String, UIColor) = {
            switch state {
            case .idle:     return ("Idle", AppColors.stateIdle)
            case .silent:   return ("Silent", AppColors.stateSilent)
            case .listening: return ("Listening", AppColors.stateListening)
            case .thinking: return ("Thinking", AppColors.stateThinking)
            case .speaking: return ("Speaking", AppColors.stateSpeaking)
            case .unknown:  return ("", AppColors.stateIdle)
            @unknown default: return ("", AppColors.stateIdle)
            }
        }()

        statusLabel.text = text
        backgroundColor = color.withAlphaComponent(0.2)
    }
}
