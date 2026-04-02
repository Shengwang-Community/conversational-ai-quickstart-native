#pragma once

#ifndef __AFXWIN_H__
    #error "Include 'pch.h' before including this file for PCH"
#endif

#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include <AgoraRtmBase.h>
#include <IAgoraRtcEngine.h>
#include <IAgoraRtmClient.h>

#include "../Chat/ChatSessionView.h"
#include "../Chat/ConnectionStartView.h"
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
    using UITask = std::function<void()>;

    enum class StatusTone {
        Hidden,
        Neutral,
        Success,
        Warning,
        Info,
        Error
    };

    class RtmEventHandler;

    // Main controller UI
    CListBox m_debugInfoList;
    int m_debugLogHorizontalExtent;
    CConnectionStartView m_connectionStartView;
    CChatSessionView m_chatSessionView;
    CFont m_normalFont;
    CFont m_smallFont;
    CBrush m_brushWindow;
    CBrush m_brushCard;
    CBrush m_brushLogSurface;
    CBrush m_brushStatus;
    COLORREF m_statusTextColor;
    StatusTone m_statusTone;
    CString m_statusText;
    bool m_isChatSessionVisible;

    // Runtime state
    std::string m_channelName;
    std::string m_userToken;
    std::string m_agentToken;
    std::string m_agentId;
    bool m_isSessionActive;
    bool m_isMicMuted;
    unsigned long long m_sessionGeneration;
    unsigned int m_userUid;
    unsigned int m_agentUid;
    AgentState m_currentAgentState;
    std::vector<Transcript> m_transcripts;
    std::function<void(bool)> m_onRTMLoginCompletion;

    // SDK
    agora::rtc::IRtcEngine* m_rtcEngine;
    agora::rtm::IRtmClient* m_rtmClient;
    std::unique_ptr<RtmEventHandler> m_rtmHandler;
    std::unique_ptr<ConversationalAIAPI> m_convoAIAPI;

    static const int BOTTOM_PANEL_HEIGHT = 62;
    static const int LOG_PANEL_WIDTH = 256;
    static const int PADDING = 12;

    // UI composition
    void setupUI();
    void setupDebugInfoPanel();
    void setupChatViews();
    void layoutViews();
    CRect getMessagesCardRect() const;
    CRect getStatusRect() const;
    CRect getControlBarRect() const;
    CRect getLogCardRect() const;
    CRect getLogListRect() const;
    void drawRoundedCard(CDC& dc, const CRect& rect, COLORREF fillColor, COLORREF borderColor, int) const;
    void refreshStatusBrush();
    void switchToConnectionStartView();
    void switchToChatSessionView();

    // UI helpers
    void updateAgentStatus(const CString& status, StatusTone tone);
    void updateTranscripts();
    void appendDebugMessage(const CString& message);
    void postUITask(UITask task);
    void handleStartFailure(const CString& status);
    CString buildTranscriptHeader(const Transcript& transcript) const;
    int measureTranscriptItemHeight(CDC& dc, const Transcript& transcript, int availableWidth) const;

    // SDK setup
    void setupSDK();
    void initializeRTC();
    void initializeRTM();
    void initializeConvoAIAPI();

    // Session flow
    void startSession();
    void stopSession();
    void generateUserToken(unsigned long long sessionGeneration, const std::function<void(bool)>& completion);
    void loginRTM(unsigned long long sessionGeneration, const std::function<void(bool)>& completion);
    void joinRTCChannel();
    void subscribeConvoAIMessage(const std::function<void(bool)>& completion);
    void generateAgentToken(unsigned long long sessionGeneration, const std::function<void(bool)>& completion);
    void startAgent(unsigned long long sessionGeneration, const std::function<void(bool)>& completion);
    void resetSessionState();
    static unsigned int generateRandomUserUid();
    static unsigned int generateRandomAgentUid();
    std::string generateRandomChannelName() const;

    // RTC / RTM callbacks
    void onJoinChannelSuccess(const char* channel, agora::rtc::uid_t uid, int elapsed) override;
    void onLeaveChannel(const agora::rtc::RtcStats& stats) override;
    void onUserJoined(agora::rtc::uid_t uid, int elapsed) override;
    void onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE reason) override;
    void onAudioVolumeIndication(const agora::rtc::AudioVolumeInfo* speakers, unsigned int speakerNumber, int totalVolume) override;
    void onLocalAudioStateChanged(agora::rtc::LOCAL_AUDIO_STREAM_STATE state, agora::rtc::LOCAL_AUDIO_STREAM_REASON reason) override;
    void onTokenPrivilegeWillExpire(const char* token) override;
    void onError(int err, const char* msg) override;
    void onRTMLoginResult(int errorCode);
    void onRTMMessage(const char* message, const char* publisher);

    // ConvoAI callbacks
    void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) override;
    void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) override;
    void OnAgentError(const std::string& agentUserId, const ModuleError& error) override;
    void OnMessageError(const std::string& agentUserId, const MessageError& error) override;
    void OnDebugLog(const std::string& log) override;

protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnSize(UINT nType, int cx, int cy);
    afx_msg void OnPaint();
    afx_msg BOOL OnEraseBkgnd(CDC* pDC);
    afx_msg HBRUSH OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor);
    afx_msg void OnDrawItem(int nIDCtl, LPDRAWITEMSTRUCT lpDrawItemStruct);
    afx_msg void OnMeasureItem(int nIDCtl, LPMEASUREITEMSTRUCT lpMeasureItemStruct);
    afx_msg void OnStartClicked();
    afx_msg void OnStopClicked();
    afx_msg void OnMuteClicked();
    afx_msg LRESULT OnExecuteUITask(WPARAM wParam, LPARAM lParam);

    DECLARE_MESSAGE_MAP()
};

class CMainFrame::RtmEventHandler : public agora::rtm::IRtmEventHandler {
public:
    explicit RtmEventHandler(CMainFrame* frame) : m_frame(frame) {}

    void onLoginResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) override;
    void onMessageEvent(const MessageEvent& event) override;
    void onPresenceEvent(const PresenceEvent& event) override;
    void onLinkStateEvent(const LinkStateEvent& event) override;
    void onPublishResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) override;
    void onSubscribeResult(const uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode) override;
    void onUnsubscribeResult(const uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode) override;

    void onTopicEvent(const TopicEvent& event) override {}
    void onLockEvent(const LockEvent& event) override {}
    void onStorageEvent(const StorageEvent& event) override {}
    void onJoinResult(const uint64_t, const char*, const char*, agora::rtm::RTM_ERROR_CODE) override {}
    void onLeaveResult(const uint64_t, const char*, const char*, agora::rtm::RTM_ERROR_CODE) override {}

private:
    CMainFrame* m_frame;
};
