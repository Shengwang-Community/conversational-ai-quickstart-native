//
//  ConfigBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ConnectionStartView: UIView {
    // MARK: - UI Components
    let startButton = UIButton(type: .system)

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

        startButton.setTitle("Start Agent", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(AppColors.btnDisabledText, for: .disabled)
        startButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        startButton.backgroundColor = AppColors.btnStartBg
        startButton.layer.cornerRadius = 8
        startButton.isEnabled = true
        addSubview(startButton)
    }

    private func setupConstraints() {
        startButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(48)
        }
    }

    // MARK: - Public Methods
    func updateButtonState(isEnabled: Bool) {
        startButton.isEnabled = isEnabled
        startButton.backgroundColor = isEnabled ? AppColors.btnStartBg : AppColors.btnDisabledBg
    }
}
