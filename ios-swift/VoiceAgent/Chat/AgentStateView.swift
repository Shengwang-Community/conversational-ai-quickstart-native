//
//  AgentStateView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class AgentStateView: UIView {
    private let dotView = UIView()
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

        dotView.layer.cornerRadius = 5
        dotView.backgroundColor = AppColors.stateIdle
        addSubview(dotView)

        statusLabel.textColor = AppColors.textSubtitle
        statusLabel.font = .systemFont(ofSize: 14)
        addSubview(statusLabel)
    }

    private func setupConstraints() {
        dotView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(10)
        }

        statusLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(dotView.snp.right).offset(8)
            make.right.equalToSuperview().offset(-16)
        }
    }

    func updateState(_ state: AgentState) {
        if state == .unknown {
            isHidden = true
            stopPulse()
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
        dotView.backgroundColor = color

        if state == .listening || state == .thinking || state == .speaking {
            startPulse()
        } else {
            stopPulse()
        }
    }

    private func startPulse() {
        guard dotView.layer.animation(forKey: "pulse") == nil else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.4
        anim.duration = 1.0
        anim.autoreverses = true
        anim.repeatCount = .infinity
        dotView.layer.add(anim, forKey: "pulse")
    }

    private func stopPulse() {
        dotView.layer.removeAnimation(forKey: "pulse")
    }
}
