#pragma once

#ifndef __AFXWIN_H__
    #error "Include 'pch.h' before including this file for PCH"
#endif

#include <memory>
#include <string>
#include <vector>
#include <map>
#include <functional>

#include <IAgoraRtcEngine.h>
#include <IAgoraRtmClient.h>
#include <AgoraRtmBase.h>
#include "../ConversationalAIAPI/ConversationalAIAPI.h"

class CMainFrame : public CFrameWnd, 
                   public agora::rtc::IRtcEngineEventHandler,
                   public IConversationalAIAPIEventHandler
{
    DECLARE_DYNAMIC(CMainFrame)
    
public:
    CMainFrame() noexcept;
    virtual ~CMainFrame();
    virtual BOOL PreCreateWindow(CREATESTRUCT& cs);
    
#ifdef _DEBUG
    virtual void AssertValid() const;
    virtual void Dump(CDumpContext& dc) const;
#endif

private:
    // UI Components
    CStatic m_topPanel;
    CStatic m_logPanel;
    CStatic m_bottomPanel;
    CListCtrl m_listMessages;
    CListCtrl m_listLog;
    CStatic m_labelAgentStatus;
    CButton m_btnStart;
    CButton m_btnStop;
    CButton m_btnMute;
    CFont m_normalFont;
    CFont m_smallFont;
    
    // Agora SDK (direct management like macOS)
    agora::rtc::IRtcEngine* m_rtcEngine;
    agora::rtm::IRtmClient* m_rtmClient;
    std::unique_ptr<ConversationalAIAPI> m_convoAIAPI;
    
    // RTM Event Handler (internal class)
    class RtmEventHandler;
    std::unique_ptr<RtmEventHandler> m_rtmHandler;
    
    // State
    std::string m_channelName;
    std::string m_userToken;
    std::string m_agentToken;
    std::string m_authToken;
    std::string m_agentId;
    bool m_isActive;
    bool m_isMuted;
    bool m_rtcJoined;
    bool m_rtmLoggedIn;
    std::vector<Transcript> m_transcripts;
    std::map<uint64_t, std::function<void(int, const std::string&)>> m_rtmCallbacks;
    
    // Constants
    unsigned int m_userUid;
    unsigned int m_agentUid;
    static const int BOTTOM_PANEL_HEIGHT = 70;
    static const int LOG_PANEL_WIDTH = 200;
    static const int PADDING = 20;
    static const int BUTTON_HEIGHT = 44;
    
    // UI Setup
    void SetupUI();
    void SetupTopPanel();
    void SetupLogPanel();
    void SetupBottomPanel();
    void LayoutPanels();
    
    // UI Helpers
    void UpdateAgentStatus(const CString& message);
    void ShowIdleButtons();
    void ShowActiveButtons();
    void UpdateTranscripts();
    void LogToView(const CString& message);
    
    // SDK Setup (direct like macOS)
    void SetupSDK();
    void InitializeRTC();
    void InitializeRTM();
    void InitializeConvoAI();
    
    // Session Management
    void StartSession();
    void StopSession();
    void JoinRTCChannel(const std::string& token);
    void LoginRTM(const std::string& token);
    void StartAgent();
    void CheckJoinAndLoginComplete();
    std::string GenerateRandomChannelName();
    static unsigned int GenerateRandomUid();
    
    // RTC Callbacks (IRtcEngineEventHandler)
    void onJoinChannelSuccess(const char* channel, agora::rtc::uid_t uid, int elapsed) override;
    void onLeaveChannel(const agora::rtc::RtcStats& stats) override;
    void onUserJoined(agora::rtc::uid_t uid, int elapsed) override;
    void onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE reason) override;
    void onTokenPrivilegeWillExpire(const char* token) override;
    void onError(int err, const char* msg) override;
    
    // RTM Callbacks (called by internal handler)
    void OnRtmLoginResult(int errorCode);
    void OnRtmMessage(const char* message, const char* publisher);
    
    // ConvoAI Callbacks
    void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) override;
    void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) override;
    void OnAgentError(const std::string& agentUserId, const ModuleError& error) override;
    void OnMessageError(const std::string& agentUserId, const MessageError& error) override;
    void OnDebugLog(const std::string& log) override;
    
protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnSize(UINT nType, int cx, int cy);
    afx_msg void OnStartClicked();
    afx_msg void OnStopClicked();
    afx_msg void OnMuteClicked();
    
    afx_msg LRESULT OnTokenFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTMLoginSuccess(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTMLoginFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStarted(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStartFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentJoined(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentLeft(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnTranscriptUpdate(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStateUpdate(WPARAM wParam, LPARAM lParam);
    
    DECLARE_MESSAGE_MAP()
};

// Internal RTM Event Handler
class CMainFrame::RtmEventHandler : public agora::rtm::IRtmEventHandler {
public:
    explicit RtmEventHandler(CMainFrame* frame) : m_frame(frame) {}
    
    void onLoginResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) override;
    void onMessageEvent(const MessageEvent& event) override;
    void onPresenceEvent(const PresenceEvent& event) override;
    void onLinkStateEvent(const LinkStateEvent& event) override;
    void onSubscribeResult(const uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode) override;
    
    // Empty implementations for unused callbacks
    void onTopicEvent(const TopicEvent& event) override {}
    void onLockEvent(const LockEvent& event) override {}
    void onStorageEvent(const StorageEvent& event) override {}
    void onJoinResult(const uint64_t, const char*, const char*, agora::rtm::RTM_ERROR_CODE) override {}
    void onLeaveResult(const uint64_t, const char*, const char*, agora::rtm::RTM_ERROR_CODE) override {}
    void onPublishResult(const uint64_t, agora::rtm::RTM_ERROR_CODE) override {}
    void onUnsubscribeResult(const uint64_t, const char*, agora::rtm::RTM_ERROR_CODE) override {}
    
private:
    CMainFrame* m_frame;
};
