// MainFrm.cpp

#include "../general/pch.h"
#include "../general/framework.h"
#include "../general/VoiceAgent.h"
#include "MainFrm.h"
#include "../../resources/Resource.h"
#include "../KeyCenter.h"
#include "../tools/Logger.h"
#include "../tools/StringUtils.h"
#include "../api/TokenGenerator.h"
#include "../api/AgentManager.h"
#include <ctime>
#include <random>

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

#define WM_TOKEN_FAILED       (WM_USER + 1)
#define WM_RTM_LOGIN_SUCCESS  (WM_USER + 2)
#define WM_RTM_LOGIN_FAILED   (WM_USER + 3)
#define WM_AGENT_STARTED      (WM_USER + 4)
#define WM_AGENT_START_FAILED (WM_USER + 5)
#define WM_AGENT_JOINED       (WM_USER + 6)
#define WM_AGENT_LEFT         (WM_USER + 7)
#define WM_TRANSCRIPT_UPDATE  (WM_USER + 8)
#define WM_AGENT_STATE_UPDATE (WM_USER + 9)

#define IDC_BTN_START     2001
#define IDC_BTN_STOP      2002
#define IDC_BTN_MUTE      2003
#define IDC_LIST_MESSAGES 2004
#define IDC_LIST_LOG      2005

IMPLEMENT_DYNAMIC(CMainFrame, CFrameWnd)

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_SIZE()
    ON_BN_CLICKED(IDC_BTN_START, &CMainFrame::OnStartClicked)
    ON_BN_CLICKED(IDC_BTN_STOP, &CMainFrame::OnStopClicked)
    ON_BN_CLICKED(IDC_BTN_MUTE, &CMainFrame::OnMuteClicked)
    ON_MESSAGE(WM_TOKEN_FAILED, &CMainFrame::OnTokenFailed)
    ON_MESSAGE(WM_RTM_LOGIN_SUCCESS, &CMainFrame::OnRTMLoginSuccess)
    ON_MESSAGE(WM_RTM_LOGIN_FAILED, &CMainFrame::OnRTMLoginFailed)
    ON_MESSAGE(WM_AGENT_STARTED, &CMainFrame::OnAgentStarted)
    ON_MESSAGE(WM_AGENT_START_FAILED, &CMainFrame::OnAgentStartFailed)
    ON_MESSAGE(WM_AGENT_JOINED, &CMainFrame::OnAgentJoined)
    ON_MESSAGE(WM_AGENT_LEFT, &CMainFrame::OnAgentLeft)
    ON_MESSAGE(WM_TRANSCRIPT_UPDATE, &CMainFrame::OnTranscriptUpdate)
    ON_MESSAGE(WM_AGENT_STATE_UPDATE, &CMainFrame::OnAgentStateUpdate)
END_MESSAGE_MAP()

// =============================================================================
// Lifecycle
// =============================================================================

CMainFrame::CMainFrame() noexcept
    : m_rtcEngine(nullptr)
    , m_rtmClient(nullptr)
    , m_isActive(false)
    , m_isMuted(false)
    , m_rtcJoined(false)
    , m_rtmLoggedIn(false)
    , m_userUid(GenerateRandomUid())
    , m_agentUid(GenerateRandomUid())
{
    while (m_agentUid == m_userUid) {
        m_agentUid = GenerateRandomUid();
    }
}

CMainFrame::~CMainFrame()
{
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }
    
    if (m_rtmClient) {
        if (m_rtmLoggedIn) {
            uint64_t reqId = 0;
            m_rtmClient->logout(reqId);
        }
        m_rtmClient->release();
        m_rtmClient = nullptr;
    }
    m_rtmHandler.reset();
    
    if (m_rtcEngine) {
        m_rtcEngine->leaveChannel();
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
    }
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    if (!CFrameWnd::PreCreateWindow(cs))
        return FALSE;

    cs.dwExStyle &= ~WS_EX_CLIENTEDGE;
    cs.lpszClass = AfxRegisterWndClass(0);
    cs.style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX);
    cs.cx = 1200;
    cs.cy = 800;
    cs.x = (GetSystemMetrics(SM_CXSCREEN) - cs.cx) / 2;
    cs.y = (GetSystemMetrics(SM_CYSCREEN) - cs.cy) / 2;

    return TRUE;
}

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    if (CFrameWnd::OnCreate(lpCreateStruct) == -1)
        return -1;

    m_normalFont.CreatePointFont(90, _T("Segoe UI"));
    m_smallFont.CreatePointFont(80, _T("Consolas"));
    
    SetupUI();
    SetupSDK();

    return 0;
}

#ifdef _DEBUG
void CMainFrame::AssertValid() const { CFrameWnd::AssertValid(); }
void CMainFrame::Dump(CDumpContext& dc) const { CFrameWnd::Dump(dc); }
#endif

// =============================================================================
// UI Setup
// =============================================================================

void CMainFrame::SetupUI()
{
    SetupLogPanel();
    SetupTopPanel();
    SetupBottomPanel();
    LayoutPanels();
}

void CMainFrame::SetupTopPanel()
{
    m_topPanel.Create(_T(""), WS_CHILD | WS_VISIBLE, CRect(0, 0, 10, 10), this);
    
    m_listMessages.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_MESSAGES);
    m_listMessages.SetFont(&m_normalFont);
    m_listMessages.SetExtendedStyle(LVS_EX_FULLROWSELECT);
    m_listMessages.InsertColumn(0, _T("Messages"), LVCFMT_LEFT, 500);
    
    m_labelAgentStatus.Create(_T("Agent: Not Started"), WS_CHILD | WS_VISIBLE | SS_RIGHT,
        CRect(0, 0, 10, 10), this);
    m_labelAgentStatus.SetFont(&m_normalFont);
}

void CMainFrame::SetupLogPanel()
{
    m_logPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_ETCHEDFRAME, CRect(0, 0, 10, 10), this);
    
    m_listLog.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_LOG);
    m_listLog.SetFont(&m_smallFont);
    m_listLog.SetExtendedStyle(LVS_EX_FULLROWSELECT);
    m_listLog.InsertColumn(0, _T("Log"), LVCFMT_LEFT, LOG_PANEL_WIDTH - 20);
}

void CMainFrame::SetupBottomPanel()
{
    m_bottomPanel.Create(_T(""), WS_CHILD | WS_VISIBLE, CRect(0, 0, 10, 10), this);
    
    m_btnStart.Create(_T("Start Agent"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_START);
    m_btnStart.SetFont(&m_normalFont);
    
    m_btnMute.Create(_T("Mute"), WS_CHILD | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_MUTE);
    m_btnMute.SetFont(&m_normalFont);
    
    m_btnStop.Create(_T("Stop Agent"), WS_CHILD | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_STOP);
    m_btnStop.SetFont(&m_normalFont);
}

void CMainFrame::LayoutPanels()
{
    CRect rc;
    GetClientRect(&rc);
    if (rc.Width() <= 0 || rc.Height() <= 0) return;
    
    int logLeft = rc.right - LOG_PANEL_WIDTH;
    int bottomTop = rc.bottom - BOTTOM_PANEL_HEIGHT;
    int contentWidth = logLeft - PADDING;
    int msgWidth = contentWidth - PADDING * 2;
    int btnY = bottomTop + (BOTTOM_PANEL_HEIGHT - BUTTON_HEIGHT) / 2;
    int halfWidth = msgWidth / 2;
    
    m_logPanel.MoveWindow(logLeft, 0, LOG_PANEL_WIDTH, rc.Height());
    m_listLog.MoveWindow(logLeft, 0, LOG_PANEL_WIDTH, rc.Height());
    m_listLog.SetColumnWidth(0, LOG_PANEL_WIDTH - 20);
    
    m_topPanel.MoveWindow(0, 0, contentWidth, bottomTop);
    m_listMessages.MoveWindow(PADDING, PADDING, msgWidth, bottomTop - PADDING - 30);
    m_listMessages.SetColumnWidth(0, msgWidth - 20);
    m_labelAgentStatus.MoveWindow(PADDING, bottomTop - 25, msgWidth, 20);
    
    m_bottomPanel.MoveWindow(0, bottomTop, contentWidth, BOTTOM_PANEL_HEIGHT);
    m_btnStart.MoveWindow(PADDING, btnY, msgWidth, BUTTON_HEIGHT);
    m_btnMute.MoveWindow(PADDING, btnY, halfWidth, BUTTON_HEIGHT);
    m_btnStop.MoveWindow(PADDING + halfWidth, btnY, halfWidth, BUTTON_HEIGHT);
}

void CMainFrame::OnSize(UINT nType, int cx, int cy)
{
    CFrameWnd::OnSize(nType, cx, cy);
    if (cx > 0 && cy > 0 && ::IsWindow(m_listMessages.GetSafeHwnd())) {
        LayoutPanels();
    }
}

// =============================================================================
// UI Helpers
// =============================================================================

void CMainFrame::UpdateAgentStatus(const CString& status)
{
    CString text;
    text.Format(_T("Agent: %s"), status);
    m_labelAgentStatus.SetWindowText(text);
}

void CMainFrame::ShowIdleButtons()
{
    m_btnMute.ShowWindow(SW_HIDE);
    m_btnStop.ShowWindow(SW_HIDE);
    m_btnStart.ShowWindow(SW_SHOW);
    m_btnStart.EnableWindow(TRUE);
}

void CMainFrame::ShowActiveButtons()
{
    m_btnStart.ShowWindow(SW_HIDE);
    m_btnMute.ShowWindow(SW_SHOW);
    m_btnMute.EnableWindow(TRUE);
    m_btnStop.ShowWindow(SW_SHOW);
    m_btnStop.EnableWindow(TRUE);
}

void CMainFrame::UpdateTranscripts()
{
    m_listMessages.DeleteAllItems();
    for (size_t i = 0; i < m_transcripts.size(); ++i) {
        const Transcript& t = m_transcripts[i];
        CString prefix = (t.type == TranscriptType::Agent) ? _T("[Agent] ") : _T("[User] ");
        m_listMessages.InsertItem((int)i, prefix + StringUtils::Utf8ToCString(t.text));
    }
    if (!m_transcripts.empty()) {
        m_listMessages.EnsureVisible((int)m_transcripts.size() - 1, FALSE);
    }
}

void CMainFrame::LogToView(const CString& message)
{
    time_t now = time(nullptr);
    struct tm t;
    localtime_s(&t, &now);
    
    CString line;
    line.Format(_T("[%02d:%02d:%02d] %s"), t.tm_hour, t.tm_min, t.tm_sec, message);
    
    int idx = m_listLog.GetItemCount();
    m_listLog.InsertItem(idx, line);
    m_listLog.EnsureVisible(idx, FALSE);
    
    LOG_INFO(std::string(CT2A(message)));
}

// =============================================================================
// SDK Setup
// =============================================================================

void CMainFrame::SetupSDK()
{
    m_listLog.DeleteAllItems();
    InitializeRTC();
    InitializeRTM();
    UpdateAgentStatus(_T("Not Started"));
}

void CMainFrame::InitializeRTC()
{
    m_rtcEngine = createAgoraRtcEngine();
    if (!m_rtcEngine) {
        LogToView(_T("RTC init FAIL"));
        return;
    }
    
    agora::rtc::RtcEngineContext ctx;
    ctx.appId = KeyCenter::AGORA_APP_ID;
    ctx.eventHandler = this;
    ctx.audioScenario = agora::rtc::AUDIO_SCENARIO_DEFAULT;
    
    if (m_rtcEngine->initialize(ctx) != 0) {
        LogToView(_T("RTC init FAIL"));
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
        return;
    }
    
    m_rtcEngine->setChannelProfile(agora::CHANNEL_PROFILE_LIVE_BROADCASTING);
    m_rtcEngine->setClientRole(agora::rtc::CLIENT_ROLE_BROADCASTER);
    m_rtcEngine->enableAudio();
    m_rtcEngine->disableVideo();
    m_rtcEngine->enableLocalAudio(true);
    
    CString msg;
    msg.Format(_T("RTC init OK, v%S"), m_rtcEngine->getVersion(nullptr));
    LogToView(msg);
}

void CMainFrame::InitializeRTM()
{
    m_rtmHandler = std::make_unique<RtmEventHandler>(this);
    std::string userIdStr = std::to_string(m_userUid);
    
    agora::rtm::RtmConfig cfg;
    cfg.appId = KeyCenter::AGORA_APP_ID;
    cfg.userId = userIdStr.c_str();
    cfg.eventHandler = m_rtmHandler.get();
    cfg.presenceTimeout = 30;
    cfg.useStringUserId = true;
    cfg.areaCode = agora::rtm::RTM_AREA_CODE_GLOB;
    
    int err = 0;
    m_rtmClient = createAgoraRtmClient(cfg, err);
    
    if (m_rtmClient && err == 0) {
        LogToView(_T("RTM init OK"));
    } else {
        CString msg;
        msg.Format(_T("RTM init FAIL, code=%d"), err);
        LogToView(msg);
    }
}

void CMainFrame::InitializeConvoAI()
{
    if (!m_convoAIAPI) {
        m_convoAIAPI = std::make_unique<ConversationalAIAPI>();
        m_convoAIAPI->AddHandler(this);
    }
}

// =============================================================================
// Button Actions
// =============================================================================

void CMainFrame::OnStartClicked()
{
    m_btnStart.EnableWindow(FALSE);
    StartSession();
}

void CMainFrame::OnStopClicked()
{
    m_btnStop.EnableWindow(FALSE);
    StopSession();
}

void CMainFrame::OnMuteClicked()
{
    m_isMuted = !m_isMuted;
    m_btnMute.SetWindowText(m_isMuted ? _T("Unmute") : _T("Mute"));
    if (m_rtcEngine) {
        m_rtcEngine->adjustRecordingSignalVolume(m_isMuted ? 0 : 100);
    }
}

// =============================================================================
// Session Management
// =============================================================================

void CMainFrame::StartSession()
{
    m_channelName = GenerateRandomChannelName();
    m_transcripts.clear();
    m_rtcJoined = false;
    m_rtmLoggedIn = false;
    m_listMessages.DeleteAllItems();
    UpdateAgentStatus(_T("Generating token..."));
    
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    TokenGenerator::GenerateToken("", std::to_string(m_userUid), 86400, types,
        [this](bool ok, const std::string& token, const std::string&) {
            if (!GetSafeHwnd()) return;
            if (!ok) {
                LogToView(_T("Token FAIL"));
                PostMessage(WM_TOKEN_FAILED, 0, 0);
                return;
            }
            LogToView(_T("Token OK"));
            m_userToken = token;
            UpdateAgentStatus(_T("Joining..."));
            JoinRTCChannel(token);
            LoginRTM(token);
        });
}

void CMainFrame::StopSession()
{
    UpdateAgentStatus(_T("Stopping..."));
    
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }
    
    if (!m_agentId.empty() && !m_authToken.empty()) {
        AgentManager::StopAgent(m_agentId, m_authToken, [](bool, const std::string&) {});
    }
    
    if (m_rtmLoggedIn && m_rtmClient) {
        uint64_t reqId = 0;
        m_rtmClient->logout(reqId);
        m_rtmLoggedIn = false;
    }
    
    if (m_rtcEngine) {
        m_rtcEngine->leaveChannel();
    }
    
    m_channelName.clear();
    m_userToken.clear();
    m_agentToken.clear();
    m_authToken.clear();
    m_agentId.clear();
    m_isActive = false;
    m_isMuted = false;
    m_rtcJoined = false;
    m_transcripts.clear();
    
    m_listMessages.DeleteAllItems();
    m_btnMute.SetWindowText(_T("Mute"));
    ShowIdleButtons();
    UpdateAgentStatus(_T("Not Started"));
}

void CMainFrame::JoinRTCChannel(const std::string& token)
{
    if (!m_rtcEngine) {
        LogToView(_T("joinChannel FAIL"));
        return;
    }
    
    agora::rtc::ChannelMediaOptions opt;
    opt.clientRoleType = agora::rtc::CLIENT_ROLE_BROADCASTER;
    opt.publishMicrophoneTrack = true;
    opt.publishCameraTrack = false;
    opt.autoSubscribeAudio = true;
    opt.autoSubscribeVideo = false;
    
    int ret = m_rtcEngine->joinChannel(token.c_str(), m_channelName.c_str(), m_userUid, opt);
    
    CString msg;
    msg.Format(_T("joinChannel ret=%d"), ret);
    LogToView(msg);
}

void CMainFrame::LoginRTM(const std::string& token)
{
    if (!m_rtmClient) {
        LogToView(_T("RTM login FAIL: nil"));
        PostMessage(WM_RTM_LOGIN_FAILED, 0, 0);
        return;
    }
    
    LogToView(_T("RTM login..."));
    uint64_t reqId = 0;
    m_rtmClient->login(token.c_str(), reqId);
}

void CMainFrame::StartAgent()
{
    UpdateAgentStatus(_T("Starting agent..."));
    
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    TokenGenerator::GenerateToken(m_channelName, std::to_string(m_agentUid), 86400, types,
        [this](bool ok, const std::string& token, const std::string&) {
            if (!GetSafeHwnd()) return;
            if (!ok) {
                LogToView(_T("Agent token FAIL"));
                PostMessage(WM_AGENT_START_FAILED, 0, 0);
                return;
            }
            LogToView(_T("Agent token OK"));
            m_agentToken = token;

            TokenGenerator::GenerateToken(m_channelName, std::to_string(m_agentUid), 86400, types,
                [this, token](bool authOk, const std::string& authToken, const std::string&) {
                    if (!GetSafeHwnd()) return;
                    if (!authOk) {
                        LogToView(_T("Auth token FAIL"));
                        PostMessage(WM_AGENT_START_FAILED, 0, 0);
                        return;
                    }

                    LogToView(_T("Auth token OK"));
                    m_authToken = authToken;

                    AgentManager::StartAgent(m_channelName, std::to_string(m_agentUid), token, authToken,
                        [this](bool ok, const std::string& result) {
                            if (!GetSafeHwnd()) return;
                            if (!ok) {
                                LogToView(_T("Agent start FAIL"));
                                PostMessage(WM_AGENT_START_FAILED, 0, 0);
                                return;
                            }
                            LogToView(_T("Agent start OK"));
                            m_agentId = result;
                            m_isActive = true;
                            PostMessage(WM_AGENT_STARTED, 0, 0);
                        });
                });
        });
}

std::string CMainFrame::GenerateRandomChannelName()
{
    return "channel_windows_" + std::to_string(GenerateRandomUid());
}

unsigned int CMainFrame::GenerateRandomUid()
{
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_int_distribution<unsigned int> dist(100000, 999999);
    return dist(gen);
}

void CMainFrame::CheckJoinAndLoginComplete()
{
    if (!m_rtcJoined || !m_rtmLoggedIn) {
        return;
    }

    UpdateAgentStatus(_T("Starting agent..."));
    InitializeConvoAI();
    StartAgent();
}

// =============================================================================
// RTC Callbacks
// =============================================================================

void CMainFrame::onJoinChannelSuccess(const char*, agora::rtc::uid_t uid, int)
{
    m_rtcJoined = true;
    CString msg;
    msg.Format(_T("onJoinSuccess uid=%u"), uid);
    LogToView(msg);
    CheckJoinAndLoginComplete();
}

void CMainFrame::onLeaveChannel(const agora::rtc::RtcStats&)
{
    LogToView(_T("onLeaveChannel"));
}

void CMainFrame::onUserJoined(agora::rtc::uid_t uid, int)
{
    CString msg;
    msg.Format(_T("onUserJoined uid=%u"), uid);
    LogToView(msg);
    
    if (uid == m_agentUid && m_isActive) {
        PostMessage(WM_AGENT_JOINED, 0, 0);
    }
}

void CMainFrame::onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE)
{
    CString msg;
    msg.Format(_T("onUserOffline uid=%u"), uid);
    LogToView(msg);
    
    if (uid == m_agentUid && m_isActive) {
        PostMessage(WM_AGENT_LEFT, 0, 0);
    }
}

void CMainFrame::onTokenPrivilegeWillExpire(const char*)
{
    LogToView(_T("Token expiring"));
}

void CMainFrame::onError(int err, const char*)
{
    CString msg;
    msg.Format(_T("onError code=%d"), err);
    LogToView(msg);
}

// =============================================================================
// RTM Callbacks
// =============================================================================

void CMainFrame::OnRtmLoginResult(int errorCode)
{
    if (errorCode == 0) {
        m_rtmLoggedIn = true;
        LogToView(_T("RTM login OK"));
        CheckJoinAndLoginComplete();
        PostMessage(WM_RTM_LOGIN_SUCCESS, 0, 0);
    } else {
        LogToView(_T("RTM login FAIL"));
        PostMessage(WM_RTM_LOGIN_FAILED, 0, 0);
    }
}

void CMainFrame::OnRtmMessage(const char* message, const char* publisher)
{
    if (m_convoAIAPI) {
        m_convoAIAPI->HandleMessage(message, publisher);
    }
}

void CMainFrame::RtmEventHandler::onLoginResult(const uint64_t, agora::rtm::RTM_ERROR_CODE err)
{
    m_frame->OnRtmLoginResult(err);
}

void CMainFrame::RtmEventHandler::onMessageEvent(const MessageEvent& e)
{
    if (e.message && e.messageLength > 0) {
        std::string msg(e.message, e.messageLength);
        std::string pub = e.publisher ? e.publisher : "";
        m_frame->OnRtmMessage(msg.c_str(), pub.c_str());
    }
}

void CMainFrame::RtmEventHandler::onPresenceEvent(const PresenceEvent& e)
{
    if (e.stateItemCount == 0 || !e.stateItems) return;
    
    std::string state, turnId;
    for (size_t i = 0; i < e.stateItemCount; ++i) {
        std::string k = e.stateItems[i].key ? e.stateItems[i].key : "";
        std::string v = e.stateItems[i].value ? e.stateItems[i].value : "";
        if (k == "state") state = v;
        else if (k == "turn_id") turnId = v;
    }
    
    if (!state.empty()) {
        std::string json = "{\"object\":\"message.state\",\"state\":\"" + state + 
            "\",\"turn_id\":" + (turnId.empty() ? "0" : turnId) +
            ",\"timestamp\":" + std::to_string(e.timestamp) + ",\"reason\":\"\"}";
        std::string pub = e.publisher ? e.publisher : "";
        m_frame->OnRtmMessage(json.c_str(), pub.c_str());
    }
}

void CMainFrame::RtmEventHandler::onLinkStateEvent(const LinkStateEvent&) {}
void CMainFrame::RtmEventHandler::onSubscribeResult(const uint64_t, const char*, agora::rtm::RTM_ERROR_CODE) {}

// =============================================================================
// ConvoAI Callbacks
// =============================================================================

void CMainFrame::OnTranscriptUpdated(const std::string&, const Transcript& transcript)
{
    auto it = std::find_if(m_transcripts.begin(), m_transcripts.end(), [&](const Transcript& t) {
        return t.turnId == transcript.turnId && t.type == transcript.type && t.userId == transcript.userId;
    });
    
    if (it != m_transcripts.end()) {
        *it = transcript;
    } else {
        m_transcripts.push_back(transcript);
    }
    
    PostMessage(WM_TRANSCRIPT_UPDATE, 0, 0);
}

void CMainFrame::OnAgentStateChanged(const std::string&, const StateChangeEvent& event)
{
    PostMessage(WM_AGENT_STATE_UPDATE, (WPARAM)event.state, 0);
}

// =============================================================================
// Async Message Handlers
// =============================================================================

LRESULT CMainFrame::OnTokenFailed(WPARAM, LPARAM)
{
    UpdateAgentStatus(_T("Token failed"));
    ShowIdleButtons();
    return 0;
}

LRESULT CMainFrame::OnRTMLoginSuccess(WPARAM, LPARAM)
{
    if (m_rtmClient) {
        agora::rtm::SubscribeOptions opt;
        opt.withMessage = true;
        opt.withPresence = true;
        opt.withMetadata = false;
        opt.withLock = false;
        
        uint64_t reqId = 0;
        m_rtmClient->subscribe(m_channelName.c_str(), opt, reqId);
    }
    return 0;
}

LRESULT CMainFrame::OnRTMLoginFailed(WPARAM, LPARAM)
{
    UpdateAgentStatus(_T("RTM login failed"));
    ShowIdleButtons();
    return 0;
}

LRESULT CMainFrame::OnAgentStarted(WPARAM, LPARAM)
{
    ShowActiveButtons();
    UpdateAgentStatus(_T("Launching..."));
    return 0;
}

LRESULT CMainFrame::OnAgentStartFailed(WPARAM, LPARAM)
{
    UpdateAgentStatus(_T("Start failed"));
    StopSession();
    return 0;
}

LRESULT CMainFrame::OnAgentJoined(WPARAM, LPARAM)
{
    if (m_isActive) UpdateAgentStatus(_T("Connected"));
    return 0;
}

LRESULT CMainFrame::OnAgentLeft(WPARAM, LPARAM)
{
    if (m_isActive) UpdateAgentStatus(_T("Disconnected"));
    return 0;
}

LRESULT CMainFrame::OnTranscriptUpdate(WPARAM, LPARAM)
{
    UpdateTranscripts();
    return 0;
}

LRESULT CMainFrame::OnAgentStateUpdate(WPARAM wParam, LPARAM)
{
    static const TCHAR* states[] = { _T("Idle"), _T("Silent"), _T("Listening"), _T("Thinking"), _T("Speaking"), _T("Unknown") };
    int idx = (int)wParam;
    UpdateAgentStatus(idx >= 0 && idx < 5 ? states[idx] : states[5]);
    return 0;
}
