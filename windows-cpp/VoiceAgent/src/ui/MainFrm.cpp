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

namespace {
constexpr COLORREF kWindowBg = RGB(15, 23, 42);
constexpr COLORREF kCardBg = RGB(30, 41, 59);
constexpr COLORREF kCardBorder = RGB(51, 65, 85);
constexpr COLORREF kTextPrimary = RGB(241, 245, 249);
constexpr COLORREF kTextSecondary = RGB(148, 163, 184);
constexpr COLORREF kUserBubble = RGB(37, 99, 235);
constexpr COLORREF kStatusNeutral = RGB(71, 85, 105);
constexpr COLORREF kStatusSuccess = RGB(16, 185, 129);
constexpr COLORREF kStatusWarning = RGB(245, 158, 11);
constexpr COLORREF kStatusInfo = RGB(59, 130, 246);
constexpr COLORREF kStatusError = RGB(239, 68, 68);
}

IMPLEMENT_DYNAMIC(CMainFrame, CFrameWnd)

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_SIZE()
    ON_WM_PAINT()
    ON_WM_ERASEBKGND()
    ON_WM_CTLCOLOR()
    ON_BN_CLICKED(IDC_BTN_START, &CMainFrame::OnStartClicked)
    ON_BN_CLICKED(IDC_BTN_STOP, &CMainFrame::OnStopClicked)
    ON_BN_CLICKED(IDC_BTN_MUTE, &CMainFrame::OnMuteClicked)
    ON_NOTIFY(NM_CUSTOMDRAW, IDC_LIST_MESSAGES, &CMainFrame::OnCustomDrawMessages)
    ON_NOTIFY(NM_CUSTOMDRAW, IDC_LIST_LOG, &CMainFrame::OnCustomDrawLogs)
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
    , m_brushWindow(kWindowBg)
    , m_brushCard(kCardBg)
    , m_brushStatus(kStatusNeutral)
    , m_statusTextColor(kTextSecondary)
    , m_statusTone(StatusTone::Hidden)
    , m_statusText(_T(""))
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
    m_titleFont.CreatePointFont(180, _T("Segoe UI Semibold"));
    m_subtitleFont.CreatePointFont(90, _T("Segoe UI"));
    
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

    m_headerTitle.Create(_T("Voice Agent"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(0, 0, 10, 10), this);
    m_headerTitle.SetFont(&m_titleFont);

    m_headerSubtitle.Create(_T("Real-time conversation with your AI assistant"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(0, 0, 10, 10), this);
    m_headerSubtitle.SetFont(&m_subtitleFont);
    
    m_listMessages.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_MESSAGES);
    m_listMessages.SetFont(&m_normalFont);
    m_listMessages.SetExtendedStyle(LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER);
    m_listMessages.InsertColumn(0, _T("Messages"), LVCFMT_LEFT, 500);
    ApplyListTheme(m_listMessages, 500);
    
    m_labelAgentStatus.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_CENTER,
        CRect(0, 0, 10, 10), this);
    m_labelAgentStatus.SetFont(&m_normalFont);
}

void CMainFrame::SetupLogPanel()
{
    m_logPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_ETCHEDFRAME, CRect(0, 0, 10, 10), this);

    m_logTitle.Create(_T("Debug Log"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(0, 0, 10, 10), this);
    m_logTitle.SetFont(&m_subtitleFont);
    
    m_listLog.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_LOG);
    m_listLog.SetFont(&m_smallFont);
    m_listLog.SetExtendedStyle(LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER);
    m_listLog.InsertColumn(0, _T("Log"), LVCFMT_LEFT, LOG_PANEL_WIDTH - 20);
    ApplyListTheme(m_listLog, LOG_PANEL_WIDTH - 20);
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
    
    CRect logCard = GetLogCardRect();
    CRect controlBar = GetControlBarRect();
    CRect statusRect = GetStatusRect();
    CRect messagesCard = GetMessagesCardRect();

    const int contentWidth = logCard.left - PADDING;
    const int titleTop = PADDING + 8;
    const int titleHeight = 34;
    const int subtitleTop = titleTop + titleHeight + 4;
    const int subtitleHeight = 20;
    const int listInset = 14;
    const int logHeaderHeight = 22;
    const int buttonY = controlBar.top + (controlBar.Height() - BUTTON_HEIGHT) / 2;
    const int stopWidth = 120;
    const int muteWidth = 96;
    const int startX = controlBar.left + 12;
    const int startWidth = controlBar.Width() - 24;
    const int stopX = controlBar.right - 12 - stopWidth;
    const int muteX = stopX - 12 - muteWidth;

    m_topPanel.MoveWindow(0, 0, contentWidth, controlBar.top);
    m_headerTitle.MoveWindow(PADDING, titleTop, contentWidth - PADDING * 2, titleHeight);
    m_headerSubtitle.MoveWindow(PADDING, subtitleTop, contentWidth - PADDING * 2, subtitleHeight);

    m_listMessages.MoveWindow(messagesCard.left + listInset, messagesCard.top + listInset,
        messagesCard.Width() - listInset * 2, messagesCard.Height() - listInset * 2);
    m_listMessages.SetColumnWidth(0, messagesCard.Width() - listInset * 2 - 8);

    m_labelAgentStatus.MoveWindow(statusRect.left, statusRect.top, statusRect.Width(), statusRect.Height());

    m_bottomPanel.MoveWindow(controlBar.left, controlBar.top, controlBar.Width(), controlBar.Height());
    m_btnStart.MoveWindow(startX, buttonY, startWidth, BUTTON_HEIGHT);
    m_btnMute.MoveWindow(muteX, buttonY, muteWidth, BUTTON_HEIGHT);
    m_btnStop.MoveWindow(stopX, buttonY, stopWidth, BUTTON_HEIGHT);

    m_logPanel.MoveWindow(logCard.left, logCard.top, logCard.Width(), logCard.Height());
    m_logTitle.MoveWindow(logCard.left + 14, logCard.top + 12, logCard.Width() - 28, logHeaderHeight);
    m_listLog.MoveWindow(logCard.left + 14, logCard.top + 40, logCard.Width() - 28, logCard.Height() - 54);
    m_listLog.SetColumnWidth(0, logCard.Width() - 36);

    Invalidate(FALSE);
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

void CMainFrame::ApplyListTheme(CListCtrl& list, int width)
{
    list.SetBkColor(kCardBg);
    list.SetTextBkColor(kCardBg);
    list.SetTextColor(kTextPrimary);
    list.SetColumnWidth(0, width);
}

CRect CMainFrame::GetMessagesCardRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    const int logLeft = rc.right - LOG_PANEL_WIDTH;
    const int contentWidth = logLeft - PADDING;
    const int controlTop = rc.bottom - BOTTOM_PANEL_HEIGHT - PADDING;
    const int statusHeight = 40;
    const int headerBottom = PADDING + 72;

    return CRect(PADDING, headerBottom, contentWidth - PADDING, controlTop - statusHeight - 16);
}

CRect CMainFrame::GetStatusRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    const int logLeft = rc.right - LOG_PANEL_WIDTH;
    const int contentWidth = logLeft - PADDING;
    const int controlTop = rc.bottom - BOTTOM_PANEL_HEIGHT - PADDING;
    return CRect(PADDING, controlTop - 48, contentWidth - PADDING, controlTop - 8);
}

CRect CMainFrame::GetControlBarRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    const int logLeft = rc.right - LOG_PANEL_WIDTH;
    const int contentWidth = logLeft - PADDING;
    return CRect(PADDING, rc.bottom - BOTTOM_PANEL_HEIGHT - PADDING, contentWidth - PADDING, rc.bottom - PADDING);
}

CRect CMainFrame::GetLogCardRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    return CRect(rc.right - LOG_PANEL_WIDTH, PADDING, rc.right - PADDING, rc.bottom - PADDING);
}

void CMainFrame::DrawRoundedCard(CDC& dc, const CRect& rect, COLORREF fillColor, COLORREF borderColor, int radius) const
{
    CPen pen(PS_SOLID, 1, borderColor);
    CBrush brush(fillColor);
    CPen* oldPen = dc.SelectObject(&pen);
    CBrush* oldBrush = dc.SelectObject(&brush);
    dc.RoundRect(rect, CPoint(radius, radius));
    dc.SelectObject(oldBrush);
    dc.SelectObject(oldPen);
}

void CMainFrame::RefreshStatusBrush()
{
    COLORREF color = kStatusNeutral;
    switch (m_statusTone) {
    case StatusTone::Hidden:
    case StatusTone::Neutral:
        color = kStatusNeutral;
        break;
    case StatusTone::Success:
        color = kStatusSuccess;
        break;
    case StatusTone::Warning:
        color = kStatusWarning;
        break;
    case StatusTone::Info:
        color = kStatusInfo;
        break;
    case StatusTone::Error:
        color = kStatusError;
        break;
    }

    m_brushStatus.DeleteObject();
    m_brushStatus.CreateSolidBrush(color);
    m_statusTextColor = kTextPrimary;
}

void CMainFrame::UpdateAgentStatus(const CString& status, StatusTone tone)
{
    m_statusText = status;
    m_statusTone = tone;
    RefreshStatusBrush();
    m_labelAgentStatus.SetWindowText(status);
    m_labelAgentStatus.ShowWindow(tone == StatusTone::Hidden ? SW_HIDE : SW_SHOW);
    if (GetSafeHwnd()) {
        InvalidateRect(GetStatusRect(), FALSE);
    }
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
        CString role = (t.type == TranscriptType::Agent) ? _T("Agent") : _T("User");
        CString content = StringUtils::Utf8ToCString(t.text);
        CString row;
        row.Format(_T("%s  •  %s"), role, content);
        if (t.status != TranscriptStatus::End) {
            row += _T(" ...");
        }
        m_listMessages.InsertItem((int)i, row);
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
    UpdateAgentStatus(_T("Ready to start"), StatusTone::Hidden);
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
    m_isActive = false;
    m_agentId.clear();
    m_agentToken.clear();
    m_authToken.clear();
    m_listMessages.DeleteAllItems();
    UpdateAgentStatus(_T("Generating token..."), StatusTone::Warning);
    
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    TokenGenerator::GenerateToken(m_channelName, std::to_string(m_userUid), 86400, types,
        [this](bool ok, const std::string& token, const std::string&) {
            if (!GetSafeHwnd()) return;
            if (!ok) {
                LogToView(_T("Token FAIL"));
                PostMessage(WM_TOKEN_FAILED, 0, 0);
                return;
            }
            LogToView(_T("Token OK"));
            m_userToken = token;
            m_authToken = token;
            UpdateAgentStatus(_T("Joining channel..."), StatusTone::Info);
            LoginRTM(token);
        });
}

void CMainFrame::StopSession()
{
    UpdateAgentStatus(_T("Stopping agent..."), StatusTone::Warning);
    
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
    UpdateAgentStatus(_T("Ready to start"), StatusTone::Hidden);
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
    opt.autoSubscribeVideo = true;
    
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

void CMainFrame::SubscribeConvoAIMessage()
{
    if (!m_rtmClient) {
        LogToView(_T("ConvoAI subscribe FAIL: RTM nil"));
        PostMessage(WM_AGENT_START_FAILED, 0, 0);
        return;
    }

    UpdateAgentStatus(_T("Subscribing to ConvoAI..."), StatusTone::Info);
    LogToView(_T("ConvoAI subscribe..."));

    agora::rtm::SubscribeOptions opt;
    opt.withMessage = true;
    opt.withPresence = true;
    opt.withMetadata = false;
    opt.withLock = false;

    uint64_t reqId = 0;
    m_rtmClient->subscribe(m_channelName.c_str(), opt, reqId);
}

void CMainFrame::GenerateAgentTokenAndStart()
{
    UpdateAgentStatus(_T("Requesting agent token..."), StatusTone::Warning);

    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    TokenGenerator::GenerateToken(m_channelName, std::to_string(m_agentUid), 86400, types,
        [this, types](bool ok, const std::string& token, const std::string&) {
            if (!GetSafeHwnd()) return;
            if (!ok) {
                LogToView(_T("Agent token FAIL"));
                PostMessage(WM_AGENT_START_FAILED, 0, 0);
                return;
            }

            LogToView(_T("Agent token OK"));
            m_agentToken = token;
            StartAgent();
        });
}

void CMainFrame::StartAgent()
{
    UpdateAgentStatus(_T("Starting agent..."), StatusTone::Warning);

    AgentManager::StartAgent(m_channelName, std::to_string(m_agentUid), m_agentToken, m_userToken,
        [this](bool ok, const std::string& result) {
            if (!GetSafeHwnd()) return;
            if (!ok) {
                LogToView(StringUtils::Utf8ToCString("Agent start FAIL: " + result));
                PostMessage(WM_AGENT_START_FAILED, 0, 0);
                return;
            }
            LogToView(_T("Agent start OK"));
            m_agentId = result;
            m_isActive = true;
            PostMessage(WM_AGENT_STARTED, 0, 0);
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

// =============================================================================
// RTC Callbacks
// =============================================================================

void CMainFrame::onJoinChannelSuccess(const char*, agora::rtc::uid_t uid, int)
{
    m_rtcJoined = true;
    CString msg;
    msg.Format(_T("onJoinSuccess uid=%u"), uid);
    LogToView(msg);
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
    UpdateAgentStatus(msg, StatusTone::Error);
}

// =============================================================================
// RTM Callbacks
// =============================================================================

void CMainFrame::OnRtmLoginResult(int errorCode)
{
    if (errorCode == 0) {
        m_rtmLoggedIn = true;
        LogToView(_T("RTM login OK"));
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

void CMainFrame::RtmEventHandler::onLinkStateEvent(const LinkStateEvent& event)
{
    CString msg;
    msg.Format(_T("RTM link state changed: %d"), static_cast<int>(event.currentState));
    m_frame->LogToView(msg);
}

void CMainFrame::RtmEventHandler::onSubscribeResult(const uint64_t, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode)
{
    CString msg;
    msg.Format(_T("RTM subscribe channel=%S result=%d"), channelName ? channelName : "", static_cast<int>(errorCode));
    m_frame->LogToView(msg);

    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        m_frame->GenerateAgentTokenAndStart();
    } else {
        m_frame->PostMessage(WM_AGENT_START_FAILED, 0, 0);
    }
}

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

void CMainFrame::OnAgentError(const std::string&, const ModuleError& error)
{
    CString msg;
    msg.Format(_T("onAgentError module=%S code=%d message=%S"),
        error.module.c_str(),
        error.code,
        error.message.c_str());
    LogToView(msg);
}

void CMainFrame::OnMessageError(const std::string&, const MessageError& error)
{
    CString msg;
    msg.Format(_T("onMessageError module=%S code=%d message=%S"),
        error.module.c_str(),
        error.code,
        error.message.c_str());
    LogToView(msg);
}

void CMainFrame::OnDebugLog(const std::string& log)
{
    LogToView(StringUtils::Utf8ToCString(log));
}

// =============================================================================
// Async Message Handlers
// =============================================================================

LRESULT CMainFrame::OnTokenFailed(WPARAM, LPARAM)
{
    UpdateAgentStatus(_T("Token failed"), StatusTone::Error);
    ShowIdleButtons();
    return 0;
}

LRESULT CMainFrame::OnRTMLoginSuccess(WPARAM, LPARAM)
{
    InitializeConvoAI();
    JoinRTCChannel(m_userToken);
    SubscribeConvoAIMessage();
    return 0;
}

LRESULT CMainFrame::OnRTMLoginFailed(WPARAM, LPARAM)
{
    UpdateAgentStatus(_T("RTM login failed"), StatusTone::Error);
    ShowIdleButtons();
    return 0;
}

LRESULT CMainFrame::OnAgentStarted(WPARAM, LPARAM)
{
    ShowActiveButtons();
    UpdateAgentStatus(_T("Launching..."), StatusTone::Info);
    return 0;
}

LRESULT CMainFrame::OnAgentStartFailed(WPARAM, LPARAM)
{
    UpdateAgentStatus(_T("Start failed"), StatusTone::Error);
    StopSession();
    return 0;
}

LRESULT CMainFrame::OnAgentJoined(WPARAM, LPARAM)
{
    if (m_isActive) UpdateAgentStatus(_T("Connected"), StatusTone::Success);
    return 0;
}

LRESULT CMainFrame::OnAgentLeft(WPARAM, LPARAM)
{
    if (m_isActive) UpdateAgentStatus(_T("Disconnected"), StatusTone::Error);
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
    StatusTone tone = StatusTone::Neutral;
    if (idx == 2) tone = StatusTone::Success;
    else if (idx == 3) tone = StatusTone::Warning;
    else if (idx == 4) tone = StatusTone::Info;
    UpdateAgentStatus(idx >= 0 && idx < 5 ? states[idx] : states[5], tone);
    return 0;
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);
    CRect rc;
    GetClientRect(&rc);
    dc.FillSolidRect(&rc, kWindowBg);

    DrawRoundedCard(dc, GetMessagesCardRect(), kCardBg, kCardBorder, 18);
    if (m_statusTone != StatusTone::Hidden) {
        COLORREF statusColor = kStatusNeutral;
        switch (m_statusTone) {
        case StatusTone::Success:
            statusColor = kStatusSuccess;
            break;
        case StatusTone::Warning:
            statusColor = kStatusWarning;
            break;
        case StatusTone::Info:
            statusColor = kStatusInfo;
            break;
        case StatusTone::Error:
            statusColor = kStatusError;
            break;
        case StatusTone::Hidden:
        case StatusTone::Neutral:
        default:
            statusColor = kStatusNeutral;
            break;
        }
        DrawRoundedCard(dc, GetStatusRect(), statusColor, kCardBorder, 16);
    }
    DrawRoundedCard(dc, GetControlBarRect(), kCardBg, kCardBorder, 18);
    DrawRoundedCard(dc, GetLogCardRect(), kCardBg, kCardBorder, 18);
}

BOOL CMainFrame::OnEraseBkgnd(CDC*)
{
    return TRUE;
}

HBRUSH CMainFrame::OnCtlColor(CDC* pDC, CWnd* pWnd, UINT nCtlColor)
{
    HBRUSH brush = CFrameWnd::OnCtlColor(pDC, pWnd, nCtlColor);

    if (!pWnd) {
        return brush;
    }

    const UINT id = pWnd->GetDlgCtrlID();
    if (pWnd == &m_headerTitle || pWnd == &m_headerSubtitle || pWnd == &m_logTitle || pWnd == &m_labelAgentStatus) {
        pDC->SetBkMode(TRANSPARENT);
        pDC->SetTextColor(pWnd == &m_headerTitle ? kTextPrimary : (pWnd == &m_labelAgentStatus ? m_statusTextColor : kTextSecondary));
        return static_cast<HBRUSH>(GetStockObject(NULL_BRUSH));
    }

    if (nCtlColor == CTLCOLOR_BTN) {
        pDC->SetBkMode(TRANSPARENT);
        pDC->SetTextColor(kTextPrimary);
        return (id == IDC_BTN_START || id == IDC_BTN_MUTE || id == IDC_BTN_STOP) ? static_cast<HBRUSH>(m_brushCard.GetSafeHandle()) : brush;
    }

    if (nCtlColor == CTLCOLOR_STATIC) {
        pDC->SetBkMode(TRANSPARENT);
        pDC->SetTextColor(kTextSecondary);
        return static_cast<HBRUSH>(GetStockObject(NULL_BRUSH));
    }

    return brush;
}

void CMainFrame::OnCustomDrawMessages(NMHDR* pNMHDR, LRESULT* pResult)
{
    LPNMLVCUSTOMDRAW pDraw = reinterpret_cast<LPNMLVCUSTOMDRAW>(pNMHDR);
    *pResult = CDRF_DODEFAULT;

    if (pDraw->nmcd.dwDrawStage == CDDS_PREPAINT) {
        *pResult = CDRF_NOTIFYITEMDRAW;
        return;
    }

    if (pDraw->nmcd.dwDrawStage == CDDS_ITEMPREPAINT) {
        const int index = static_cast<int>(pDraw->nmcd.dwItemSpec);
        pDraw->clrTextBk = m_transcripts[index].type == TranscriptType::User ? kUserBubble : kCardBg;
        pDraw->clrText = kTextPrimary;
        *pResult = CDRF_DODEFAULT;
    }
}

void CMainFrame::OnCustomDrawLogs(NMHDR* pNMHDR, LRESULT* pResult)
{
    LPNMLVCUSTOMDRAW pDraw = reinterpret_cast<LPNMLVCUSTOMDRAW>(pNMHDR);
    *pResult = CDRF_DODEFAULT;

    if (pDraw->nmcd.dwDrawStage == CDDS_PREPAINT) {
        *pResult = CDRF_NOTIFYITEMDRAW;
        return;
    }

    if (pDraw->nmcd.dwDrawStage == CDDS_ITEMPREPAINT) {
        pDraw->clrTextBk = kCardBg;
        pDraw->clrText = kTextSecondary;
        *pResult = CDRF_DODEFAULT;
    }
}
