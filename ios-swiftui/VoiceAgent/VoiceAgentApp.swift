//
//  VoiceAgentApp.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import SwiftUI

@main
struct VoiceAgentApp: App {
    init() {
        print("[VoiceAgentApp] App initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            AgentView()
        }
    }
}
