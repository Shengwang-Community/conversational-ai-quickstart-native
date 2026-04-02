// MainFrm.cpp

#include "../general/pch.h"
#include "../general/framework.h"
#include "../general/VoiceAgent.h"
#include "MainFrm.h"
#include "../../resources/Resource.h"
#include "../KeyCenter.h"
#include "../tools/AgentManager.h"
#include "../tools/Logger.h"
#include "../tools/NetworkManager.h"
#include "../tools/StringUtils.h"

#include <algorithm>
#include <ctime>
#include <random>

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

#define WM_EXECUTE_UI_TASK  (WM_USER + 1)

#define IDC_BTN_START       2001
#define IDC_BTN_STOP        2002
#define IDC_BTN_MUTE        2003
#define IDC_LIST_MESSAGES   2004
#define IDC_LIST_LOG        2005

namespace {
constexpr COLORREF kWindowBg = RGB(15, 23, 42);
constexpr COLORREF kCardBg = RGB(30, 41, 59);
constexpr COLORREF kCardBorder = RGB(51, 65, 85);
constexpr COLORREF kLogSurface = RGB(9, 15, 28);
constexpr COLORREF kTextPrimary = RGB(241, 245, 249);
constexpr COLORREF kTextSecondary = RGB(148, 163, 184);
constexpr COLORREF kUserRow = RGB(30, 64, 175);
constexpr COLORREF kAgentRow = RGB(30, 41, 59);
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
    ON_WM_DRAWITEM()
    ON_WM_MEASUREITEM()
    ON_BN_CLICKED(IDC_BTN_START, &CMainFrame::OnStartClicked)
    ON_BN_CLICKED(IDC_BTN_STOP, &CMainFrame::OnStopClicked)
    ON_BN_CLICKED(IDC_BTN_MUTE, &CMainFrame::OnMuteClicked)
    ON_MESSAGE(WM_EXECUTE_UI_TASK, &CMainFrame::OnExecuteUITask)
END_MESSAGE_MAP()

CMainFrame::CMainFrame() noexcept
    : m_statusTextColor(kTextSecondary)
    , m_statusTone(StatusTone::Hidden)
    , m_statusText(_T(""))
    , m_isChatSessionVisible(false)
    , m_debugLogHorizontalExtent(0)
    , m_isSessionActive(false)
    , m_isMicMuted(false)
    , m_sessionGeneration(0)
    , m_userUid(generateRandomUserUid())
    , m_agentUid(generateRandomAgentUid())
    , m_currentAgentState(AgentState::Unknown)
    , m_rtcEngine(nullptr)
    , m_rtmClient(nullptr)
    , m_brushWindow(kWindowBg)
    , m_brushCard(kCardBg)
    , m_brushLogSurface(kLogSurface)
    , m_brushStatus(kStatusNeutral)
{
    while (m_agentUid == m_userUid) {
        m_agentUid = generateRandomAgentUid();
    }
}

CMainFrame::~CMainFrame()
{
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }

    if (m_rtmClient) {
        uint64_t requestId = 0;
        m_rtmClient->logout(requestId);
        m_rtmClient->release();
        m_rtmClient = nullptr;
    }

    if (m_rtcEngine) {
        m_rtcEngine->leaveChannel();
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
    }
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    if (!CFrameWnd::PreCreateWindow(cs)) {
        return FALSE;
    }

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
    if (CFrameWnd::OnCreate(lpCreateStruct) == -1) {
        return -1;
    }

    m_normalFont.CreatePointFont(90, _T("Segoe UI"));
    m_smallFont.CreatePointFont(80, _T("Consolas"));

    setupUI();
    setupSDK();
    switchToConnectionStartView();

    return 0;
}

#ifdef _DEBUG
void CMainFrame::AssertValid() const { CFrameWnd::AssertValid(); }
void CMainFrame::Dump(CDumpContext& dc) const { CFrameWnd::Dump(dc); }
#endif

void CMainFrame::setupUI()
{
    setupDebugInfoPanel();
    setupChatViews();
    layoutViews();
}

void CMainFrame::setupDebugInfoPanel()
{
    m_debugInfoList.Create(WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL | LBS_NOINTEGRALHEIGHT | LBS_DISABLENOSCROLL,
        CRect(0, 0, 10, 10), this, IDC_LIST_LOG);
    m_debugInfoList.SetFont(&m_smallFont);
    appendDebugMessage(_T("Waiting for connection..."));
}

void CMainFrame::setupChatViews()
{
    m_connectionStartView.Create(this, IDC_BTN_START, &m_normalFont);
    m_chatSessionView.Create(this, IDC_LIST_MESSAGES, IDC_BTN_MUTE, IDC_BTN_STOP, &m_normalFont, &m_normalFont);
}

void CMainFrame::layoutViews()
{
    CRect rc;
    GetClientRect(&rc);
    if (rc.Width() <= 0 || rc.Height() <= 0) {
        return;
    }

    const CRect messagesCard = getMessagesCardRect();
    const CRect statusRect = getStatusRect();
    const CRect controlBarRect = getControlBarRect();
    const CRect logListRect = getLogListRect();

    m_connectionStartView.Layout(controlBarRect);
    m_chatSessionView.Layout(messagesCard, statusRect, controlBarRect);
    m_debugInfoList.MoveWindow(logListRect);

    Invalidate(FALSE);
}

CRect CMainFrame::getMessagesCardRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    const int logLeft = rc.right - LOG_PANEL_WIDTH;
    const int contentWidth = logLeft - PADDING;
    const int controlTop = rc.bottom - BOTTOM_PANEL_HEIGHT - PADDING;
    const int statusHeight = 40;
    return CRect(PADDING, PADDING, contentWidth - PADDING, controlTop - statusHeight - 8);
}

CRect CMainFrame::getStatusRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    const int logLeft = rc.right - LOG_PANEL_WIDTH;
    const int contentWidth = logLeft - PADDING;
    const int controlTop = rc.bottom - BOTTOM_PANEL_HEIGHT - PADDING;
    return CRect(PADDING, controlTop - 42, contentWidth - PADDING, controlTop - 6);
}

CRect CMainFrame::getControlBarRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    const int logLeft = rc.right - LOG_PANEL_WIDTH;
    const int contentWidth = logLeft - PADDING;
    return CRect(PADDING, rc.bottom - BOTTOM_PANEL_HEIGHT - PADDING, contentWidth - PADDING, rc.bottom - PADDING);
}

CRect CMainFrame::getLogCardRect() const
{
    CRect rc;
    const_cast<CMainFrame*>(this)->GetClientRect(&rc);
    return CRect(rc.right - LOG_PANEL_WIDTH, PADDING, rc.right - PADDING, rc.bottom - PADDING);
}

CRect CMainFrame::getLogListRect() const
{
    const CRect logCard = getLogCardRect();
    return CRect(logCard.left + 6, logCard.top + 6, logCard.right - 6, logCard.bottom - 6);
}

void CMainFrame::drawRoundedCard(CDC& dc, const CRect& rect, COLORREF fillColor, COLORREF borderColor, int) const
{
    CPen pen(PS_SOLID, 1, borderColor);
    CBrush brush(fillColor);
    CPen* oldPen = dc.SelectObject(&pen);
    CBrush* oldBrush = dc.SelectObject(&brush);
    dc.Rectangle(rect);
    dc.SelectObject(oldBrush);
    dc.SelectObject(oldPen);
}

void CMainFrame::refreshStatusBrush()
{
    COLORREF color = kStatusNeutral;
    switch (m_statusTone) {
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
    case StatusTone::Hidden:
    case StatusTone::Neutral:
    default:
        color = kStatusNeutral;
        break;
    }

    m_brushStatus.DeleteObject();
    m_brushStatus.CreateSolidBrush(color);
    m_statusTextColor = kTextPrimary;
}

void CMainFrame::switchToConnectionStartView()
{
    m_isChatSessionVisible = false;
    m_connectionStartView.Show(TRUE);
    m_connectionStartView.SetStartButtonEnabled(TRUE);
    m_chatSessionView.Show(FALSE);
    m_chatSessionView.GetAgentStateView().Show(FALSE);
    Invalidate(FALSE);
}

void CMainFrame::switchToChatSessionView()
{
    m_isChatSessionVisible = true;
    m_connectionStartView.Show(FALSE);
    m_chatSessionView.Show(TRUE);
    m_chatSessionView.UpdateMicButtonState(m_isMicMuted);
    m_chatSessionView.GetAgentStateView().Show(m_statusTone != StatusTone::Hidden ? TRUE : FALSE);
    Invalidate(FALSE);
}

void CMainFrame::updateAgentStatus(const CString& status, StatusTone tone)
{
    m_statusText = status;
    m_statusTone = tone;
    refreshStatusBrush();
    m_chatSessionView.GetAgentStateView().SetText(status);
    if (m_isChatSessionVisible) {
        m_chatSessionView.GetAgentStateView().Show(tone == StatusTone::Hidden ? FALSE : TRUE);
    }
    InvalidateRect(getStatusRect(), FALSE);
}

void CMainFrame::updateTranscripts()
{
    auto& transcriptList = m_chatSessionView.GetTranscriptList();
    transcriptList.ResetContent();

    for (size_t index = 0; index < m_transcripts.size(); ++index) {
        const Transcript& transcript = m_transcripts[index];
        CString content = StringUtils::Utf8ToCString(transcript.text);
        if (transcript.status != TranscriptStatus::End) {
            content += _T(" ...");
        }
        CString row = buildTranscriptHeader(transcript);
        row += _T("\n");
        row += content;
        transcriptList.AddString(row);
    }

    if (!m_transcripts.empty()) {
        transcriptList.SetTopIndex(std::max(0, transcriptList.GetCount() - 1));
    }
}

CString CMainFrame::buildTranscriptHeader(const Transcript& transcript) const
{
    const CString role = transcript.type == TranscriptType::User ? _T("User") : _T("Agent");
    CString header;
    header.Format(_T("%s | Turn %d | ID %S"),
        role.GetString(),
        transcript.turnId,
        transcript.userId.c_str());
    return header;
}

int CMainFrame::measureTranscriptItemHeight(CDC& dc, const Transcript& transcript, int availableWidth) const
{
    const int contentWidth = std::max(80, availableWidth - 32);
    CRect calcRect(0, 0, contentWidth, 0);

    CString message = StringUtils::Utf8ToCString(transcript.text);
    if (transcript.status != TranscriptStatus::End) {
        message += _T(" ...");
    }

    CFont* oldFont = dc.SelectObject(const_cast<CFont*>(&m_smallFont));
    const CString header = buildTranscriptHeader(transcript);
    dc.DrawText(header, &calcRect, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    const int headerHeight = calcRect.Height();

    calcRect = CRect(0, 0, contentWidth, 0);
    dc.SelectObject(const_cast<CFont*>(&m_normalFont));
    dc.DrawText(message, &calcRect, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    const int messageHeight = calcRect.Height();
    dc.SelectObject(oldFont);

    return std::max(56, headerHeight + messageHeight + 32);
}

void CMainFrame::appendDebugMessage(const CString& message)
{
    time_t now = time(nullptr);
    struct tm timeInfo;
    localtime_s(&timeInfo, &now);

    CString line;
    line.Format(_T("[%02d:%02d:%02d] %s"), timeInfo.tm_hour, timeInfo.tm_min, timeInfo.tm_sec, message);

    constexpr int kMaxDebugItems = 500;
    if (m_debugInfoList.GetCount() >= kMaxDebugItems) {
        m_debugInfoList.DeleteString(0);
    }

    m_debugInfoList.AddString(line);

    CClientDC dc(&m_debugInfoList);
    CFont* oldFont = dc.SelectObject(&m_smallFont);
    const int lineWidth = static_cast<int>(dc.GetTextExtent(line).cx) + 24;
    m_debugLogHorizontalExtent = std::max(m_debugLogHorizontalExtent, lineWidth);
    dc.SelectObject(oldFont);
    m_debugInfoList.SetHorizontalExtent(m_debugLogHorizontalExtent);

    const int itemCount = m_debugInfoList.GetCount();
    if (itemCount > 0) {
        CRect listRect;
        m_debugInfoList.GetClientRect(&listRect);
        const int itemHeight = std::max(1, static_cast<int>(m_debugInfoList.GetItemHeight(0)));
        const int visibleItems = std::max(1, listRect.Height() / itemHeight);
        m_debugInfoList.SetTopIndex(std::max(0, itemCount - visibleItems));
    }

    LOG_INFO(std::string(CT2A(message)));
}

void CMainFrame::postUITask(UITask task)
{
    auto* taskPtr = new UITask(std::move(task));
    if (!GetSafeHwnd() || !::IsWindow(GetSafeHwnd()) || !PostMessage(WM_EXECUTE_UI_TASK, 0, reinterpret_cast<LPARAM>(taskPtr))) {
        delete taskPtr;
    }
}

void CMainFrame::handleStartFailure(const CString& status)
{
    appendDebugMessage(status);
    updateAgentStatus(status, StatusTone::Error);
    stopSession();
}

void CMainFrame::setupSDK()
{
    initializeRTC();
    initializeRTM();
    updateAgentStatus(_T("Ready to start"), StatusTone::Hidden);
}

void CMainFrame::initializeRTC()
{
    m_rtcEngine = createAgoraRtcEngine();
    if (!m_rtcEngine) {
        appendDebugMessage(_T("RTC init FAIL"));
        return;
    }

    agora::rtc::RtcEngineContext context{};
    context.appId = KeyCenter::AGORA_APP_ID;
    context.eventHandler = this;
    context.audioScenario = agora::rtc::AUDIO_SCENARIO_AI_CLIENT;

    if (m_rtcEngine->initialize(context) != 0) {
        appendDebugMessage(_T("RTC init FAIL"));
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
        return;
    }

    m_rtcEngine->setChannelProfile(agora::CHANNEL_PROFILE_LIVE_BROADCASTING);
    m_rtcEngine->setClientRole(agora::rtc::CLIENT_ROLE_BROADCASTER);
    m_rtcEngine->enableAudio();
    m_rtcEngine->disableVideo();
    m_rtcEngine->enableLocalAudio(true);
    m_rtcEngine->enableAudioVolumeIndication(100, 3, false);
    m_rtcEngine->setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}");

    CString message;
    message.Format(_T("RTC init OK, v%S"), m_rtcEngine->getVersion(nullptr));
    appendDebugMessage(message);
}

void CMainFrame::initializeRTM()
{
    m_rtmHandler = std::make_unique<RtmEventHandler>(this);

    agora::rtm::RtmConfig config{};
    const std::string userId = std::to_string(m_userUid);
    config.appId = KeyCenter::AGORA_APP_ID;
    config.userId = userId.c_str();
    config.eventHandler = m_rtmHandler.get();
    config.presenceTimeout = 30;
    config.useStringUserId = true;
    config.areaCode = agora::rtm::RTM_AREA_CODE_GLOB;

    int errorCode = 0;
    m_rtmClient = createAgoraRtmClient(config, errorCode);

    if (m_rtmClient && errorCode == 0) {
        appendDebugMessage(_T("RTM init OK"));
    } else {
        CString message;
        message.Format(_T("RTM init FAIL, code=%d"), errorCode);
        appendDebugMessage(message);
    }
}

void CMainFrame::initializeConvoAIAPI()
{
    if (!m_convoAIAPI) {
        m_convoAIAPI = std::make_unique<ConversationalAIAPI>(ConversationalAIAPIConfig(m_rtcEngine, m_rtmClient, true));
        m_convoAIAPI->AddHandler(this);
    }
}

void CMainFrame::startSession()
{
    resetSessionState();
    m_channelName = generateRandomChannelName();
    const auto sessionGeneration = ++m_sessionGeneration;
    updateAgentStatus(_T("Generating user token..."), StatusTone::Warning);
    m_connectionStartView.SetStartButtonEnabled(FALSE);

    generateUserToken(sessionGeneration, [this, sessionGeneration](bool didGenerateUserToken) {
        if (sessionGeneration != m_sessionGeneration) {
            return;
        }
        if (!didGenerateUserToken) {
            handleStartFailure(_T("User token failed"));
            return;
        }

        updateAgentStatus(_T("Logging in RTM..."), StatusTone::Info);
        loginRTM(sessionGeneration, [this, sessionGeneration](bool didLoginRTM) {
            if (sessionGeneration != m_sessionGeneration) {
                return;
            }
            if (!didLoginRTM) {
                handleStartFailure(_T("RTM login failed"));
                return;
            }

            initializeConvoAIAPI();
            updateAgentStatus(_T("Joining RTC channel..."), StatusTone::Info);
            joinRTCChannel();
            updateAgentStatus(_T("Subscribing to ConvoAI..."), StatusTone::Info);

            subscribeConvoAIMessage([this, sessionGeneration](bool didSubscribeToConvoAI) {
                if (sessionGeneration != m_sessionGeneration) {
                    return;
                }
                if (!didSubscribeToConvoAI) {
                    handleStartFailure(_T("ConvoAI subscribe failed"));
                    return;
                }

                updateAgentStatus(_T("Generating agent token..."), StatusTone::Warning);
                generateAgentToken(sessionGeneration, [this, sessionGeneration](bool didGenerateAgentToken) {
                    if (sessionGeneration != m_sessionGeneration) {
                        return;
                    }
                    if (!didGenerateAgentToken) {
                        handleStartFailure(_T("Agent token failed"));
                        return;
                    }

                    updateAgentStatus(_T("Starting agent..."), StatusTone::Warning);
                    startAgent(sessionGeneration, [this, sessionGeneration](bool didStartAgent) {
                        if (sessionGeneration != m_sessionGeneration) {
                            return;
                        }
                        if (!didStartAgent) {
                            handleStartFailure(_T("Agent start failed"));
                            return;
                        }

                        switchToChatSessionView();
                        updateAgentStatus(_T("Launching..."), StatusTone::Info);
                    });
                });
            });
        });
    });
}

void CMainFrame::stopSession()
{
    ++m_sessionGeneration;

    if (!m_agentId.empty() && !m_userToken.empty()) {
        AgentManager::stopAgent(m_agentId, m_userToken, nullptr);
    }

    if (m_convoAIAPI) {
        if (!m_channelName.empty()) {
            m_convoAIAPI->UnsubscribeMessage(m_channelName, nullptr);
        }
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI->Destroy();
        m_convoAIAPI.reset();
    }

    if (m_rtmClient) {
        uint64_t requestId = 0;
        m_rtmClient->logout(requestId);
    }

    if (m_rtcEngine) {
        m_rtcEngine->leaveChannel();
    }

    resetSessionState();
    switchToConnectionStartView();
    updateAgentStatus(_T("Ready to start"), StatusTone::Hidden);
}

void CMainFrame::generateUserToken(unsigned long long sessionGeneration, const std::function<void(bool)>& completion)
{
    NetworkManager::shared().generateToken(m_channelName, std::to_string(m_userUid), 86400,
        {AgoraTokenType::RTC, AgoraTokenType::RTM},
        [this, sessionGeneration, completion](bool success, const std::string& token, const std::string& errorMessage) {
            postUITask([this, sessionGeneration, completion, success, token, errorMessage]() {
                if (sessionGeneration != m_sessionGeneration) {
                    return;
                }
                if (!success) {
                    appendDebugMessage(StringUtils::Utf8ToCString("User token failed: " + errorMessage));
                    completion(false);
                    return;
                }

                m_userToken = token;
                appendDebugMessage(_T("User token succeeded"));
                completion(true);
            });
        });
}

void CMainFrame::loginRTM(unsigned long long sessionGeneration, const std::function<void(bool)>& completion)
{
    if (!m_rtmClient) {
        completion(false);
        return;
    }

    m_onRTMLoginCompletion = [this, sessionGeneration, completion](bool didLoginRTM) {
        if (sessionGeneration != m_sessionGeneration) {
            return;
        }
        completion(didLoginRTM);
    };
    uint64_t requestId = 0;
    m_rtmClient->login(m_userToken.c_str(), requestId);
}

void CMainFrame::joinRTCChannel()
{
    if (!m_rtcEngine) {
        appendDebugMessage(_T("joinChannel FAIL"));
        return;
    }

    if (m_convoAIAPI) {
        m_convoAIAPI->LoadAudioSettings();
    }

    agora::rtc::ChannelMediaOptions options{};
    options.clientRoleType = agora::rtc::CLIENT_ROLE_BROADCASTER;
    options.publishMicrophoneTrack = true;
    options.publishCameraTrack = false;
    options.autoSubscribeAudio = true;
    options.autoSubscribeVideo = true;

    const int result = m_rtcEngine->joinChannel(m_userToken.c_str(), m_channelName.c_str(), m_userUid, options);
    CString message;
    message.Format(_T("joinChannel ret=%d"), result);
    appendDebugMessage(message);
}

void CMainFrame::subscribeConvoAIMessage(const std::function<void(bool)>& completion)
{
    if (!m_convoAIAPI) {
        completion(false);
        return;
    }

    m_convoAIAPI->SubscribeMessage(m_channelName, [this, completion](const ConversationalAIAPIError* error) {
        postUITask([this, completion, hasError = error != nullptr, errorMessage = error ? error->message : std::string()]() {
            if (hasError) {
                appendDebugMessage(StringUtils::Utf8ToCString("ConvoAI subscribe failed: " + errorMessage));
                completion(false);
                return;
            }

            appendDebugMessage(_T("ConvoAI subscribed"));
            completion(true);
        });
    });
}

void CMainFrame::generateAgentToken(unsigned long long sessionGeneration, const std::function<void(bool)>& completion)
{
    NetworkManager::shared().generateToken(m_channelName, std::to_string(m_agentUid), 86400,
        {AgoraTokenType::RTC, AgoraTokenType::RTM},
        [this, sessionGeneration, completion](bool success, const std::string& token, const std::string& errorMessage) {
            postUITask([this, sessionGeneration, completion, success, token, errorMessage]() {
                if (sessionGeneration != m_sessionGeneration) {
                    return;
                }
                if (!success) {
                    appendDebugMessage(StringUtils::Utf8ToCString("Agent token failed: " + errorMessage));
                    completion(false);
                    return;
                }

                m_agentToken = token;
                appendDebugMessage(_T("Agent token succeeded"));
                completion(true);
            });
        });
}

void CMainFrame::startAgent(unsigned long long sessionGeneration, const std::function<void(bool)>& completion)
{
    AgentManager::startAgent(m_channelName, std::to_string(m_agentUid), m_agentToken, m_userToken,
        [this, sessionGeneration, completion](bool success, const std::string& agentIdOrError) {
            postUITask([this, sessionGeneration, completion, success, agentIdOrError]() {
                if (sessionGeneration != m_sessionGeneration) {
                    return;
                }
                if (!success) {
                    appendDebugMessage(StringUtils::Utf8ToCString("Agent start failed: " + agentIdOrError));
                    completion(false);
                    return;
                }

                m_agentId = agentIdOrError;
                m_isSessionActive = true;
                appendDebugMessage(_T("Agent start succeeded"));
                completion(true);
            });
        });
}

void CMainFrame::resetSessionState()
{
    m_channelName.clear();
    m_userToken.clear();
    m_agentToken.clear();
    m_agentId.clear();
    m_isSessionActive = false;
    m_isMicMuted = false;
    m_currentAgentState = AgentState::Unknown;
    m_transcripts.clear();
    m_connectionStartView.SetStartButtonEnabled(TRUE);
    m_chatSessionView.UpdateMicButtonState(false);
    m_chatSessionView.GetAgentStateView().SetText(_T(""));
    m_chatSessionView.GetAgentStateView().Show(FALSE);
    m_onRTMLoginCompletion = nullptr;
    updateTranscripts();
}

unsigned int CMainFrame::generateRandomUserUid()
{
    static std::random_device randomDevice;
    static std::mt19937 generator(randomDevice());
    static std::uniform_int_distribution<unsigned int> distribution(1000, 9999999);
    return distribution(generator);
}

unsigned int CMainFrame::generateRandomAgentUid()
{
    static std::random_device randomDevice;
    static std::mt19937 generator(randomDevice());
    static std::uniform_int_distribution<unsigned int> distribution(10000000, 99999999);
    return distribution(generator);
}

std::string CMainFrame::generateRandomChannelName() const
{
    return "channel_windows_" + std::to_string(generateRandomUserUid());
}

void CMainFrame::onJoinChannelSuccess(const char*, agora::rtc::uid_t uid, int)
{
    postUITask([this, uid]() {
        CString message;
        message.Format(_T("RTC joined channel (uid=%u)"), uid);
        appendDebugMessage(message);
    });
}

void CMainFrame::onLeaveChannel(const agora::rtc::RtcStats&)
{
    postUITask([this]() {
        appendDebugMessage(_T("RTC left channel"));
    });
}

void CMainFrame::onUserJoined(agora::rtc::uid_t uid, int)
{
    postUITask([this, uid]() {
        CString message;
        message.Format(_T("Remote user joined (uid=%u)"), uid);
        appendDebugMessage(message);

        if (uid == m_agentUid && m_isSessionActive) {
            updateAgentStatus(_T("Connected"), StatusTone::Success);
        }
    });
}

void CMainFrame::onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE)
{
    postUITask([this, uid]() {
        CString message;
        message.Format(_T("Remote user left (uid=%u)"), uid);
        appendDebugMessage(message);

        if (uid == m_agentUid && m_isSessionActive) {
            updateAgentStatus(_T("Disconnected"), StatusTone::Error);
        }
    });
}

void CMainFrame::onAudioVolumeIndication(const agora::rtc::AudioVolumeInfo* speakers, unsigned int speakerNumber, int totalVolume)
{
    (void)speakers;
    (void)speakerNumber;
    (void)totalVolume;
}

void CMainFrame::onLocalAudioStateChanged(agora::rtc::LOCAL_AUDIO_STREAM_STATE state, agora::rtc::LOCAL_AUDIO_STREAM_REASON reason)
{
    postUITask([this, state, reason]() {
        CString message;
        message.Format(_T("Local audio state=%d reason=%d"), static_cast<int>(state), static_cast<int>(reason));
        appendDebugMessage(message);
    });
}

void CMainFrame::onTokenPrivilegeWillExpire(const char*)
{
    postUITask([this]() {
        appendDebugMessage(_T("Token expiring"));
    });
}

void CMainFrame::onError(int errorCode, const char*)
{
    postUITask([this, errorCode]() {
        CString message;
        message.Format(_T("RTC error: %d"), errorCode);
        appendDebugMessage(message);
        updateAgentStatus(message, StatusTone::Error);
    });
}

void CMainFrame::onRTMLoginResult(int errorCode)
{
    postUITask([this, errorCode]() {
        const bool isSuccess = errorCode == 0;
        appendDebugMessage(isSuccess ? _T("RTM login succeeded") : _T("RTM login failed"));

        if (m_onRTMLoginCompletion) {
            auto completion = std::move(m_onRTMLoginCompletion);
            completion(isSuccess);
        }
    });
}

void CMainFrame::onRTMMessage(const char* message, const char* publisher)
{
    if (m_convoAIAPI) {
        m_convoAIAPI->HandleMessage(message ? message : "", publisher ? publisher : "");
    }
}

void CMainFrame::OnTranscriptUpdated(const std::string&, const Transcript& transcript)
{
    postUITask([this, transcript]() {
        const auto existingTranscript = std::find_if(m_transcripts.begin(), m_transcripts.end(),
            [&transcript](const Transcript& candidate) {
                return candidate.turnId == transcript.turnId &&
                       candidate.type == transcript.type &&
                       candidate.userId == transcript.userId;
            });

        if (existingTranscript != m_transcripts.end()) {
            *existingTranscript = transcript;
        } else {
            m_transcripts.push_back(transcript);
        }

        updateTranscripts();
    });
}

void CMainFrame::OnAgentStateChanged(const std::string&, const StateChangeEvent& event)
{
    postUITask([this, event]() {
        m_currentAgentState = event.state;
        static const TCHAR* states[] = { _T("Idle"), _T("Silent"), _T("Listening"), _T("Thinking"), _T("Speaking"), _T("Unknown") };
        StatusTone tone = StatusTone::Neutral;
        if (event.state == AgentState::Listening) {
            tone = StatusTone::Success;
        } else if (event.state == AgentState::Thinking) {
            tone = StatusTone::Warning;
        } else if (event.state == AgentState::Speaking) {
            tone = StatusTone::Info;
        }

        const int stateIndex = static_cast<int>(event.state);
        updateAgentStatus(states[stateIndex >= 0 && stateIndex < 6 ? stateIndex : 5], tone);
    });
}

void CMainFrame::OnAgentError(const std::string&, const ModuleError& error)
{
    postUITask([this, error]() {
        CString message;
        message.Format(_T("Agent error: module=%S code=%d message=%S"),
            error.module.c_str(), error.code, error.message.c_str());
        appendDebugMessage(message);
    });
}

void CMainFrame::OnMessageError(const std::string&, const MessageError& error)
{
    postUITask([this, error]() {
        CString message;
        message.Format(_T("Message error: module=%S code=%d message=%S"),
            error.module.c_str(), error.code, error.message.c_str());
        appendDebugMessage(message);
    });
}

void CMainFrame::OnDebugLog(const std::string& log)
{
    postUITask([this, log]() {
        if (log.find("[ConversationalAIAPI] message.metrics ") != std::string::npos) {
            return;
        }
        appendDebugMessage(StringUtils::Utf8ToCString(log));
    });
}

void CMainFrame::RtmEventHandler::onLoginResult(const uint64_t, agora::rtm::RTM_ERROR_CODE errorCode)
{
    m_frame->onRTMLoginResult(errorCode);
}

void CMainFrame::RtmEventHandler::onMessageEvent(const MessageEvent& event)
{
    if (event.message && event.messageLength > 0) {
        std::string message(event.message, event.messageLength);
        std::string publisher = event.publisher ? event.publisher : "";
        m_frame->onRTMMessage(message.c_str(), publisher.c_str());
    }
}

void CMainFrame::RtmEventHandler::onPresenceEvent(const PresenceEvent& event)
{
    if (event.stateItemCount == 0 || !event.stateItems) {
        return;
    }

    std::string state;
    std::string turnId;
    for (size_t index = 0; index < event.stateItemCount; ++index) {
        const std::string key = event.stateItems[index].key ? event.stateItems[index].key : "";
        const std::string value = event.stateItems[index].value ? event.stateItems[index].value : "";
        if (key == "state") {
            state = value;
        } else if (key == "turn_id") {
            turnId = value;
        }
    }

    if (!state.empty()) {
        std::string json = "{\"object\":\"message.state\",\"state\":\"" + state +
            "\",\"turn_id\":" + (turnId.empty() ? "0" : turnId) +
            ",\"timestamp\":" + std::to_string(event.timestamp) + ",\"reason\":\"\"}";
        std::string publisher = event.publisher ? event.publisher : "";
        m_frame->onRTMMessage(json.c_str(), publisher.c_str());
    }
}

void CMainFrame::RtmEventHandler::onLinkStateEvent(const LinkStateEvent& event)
{
    m_frame->postUITask([this, state = event.currentState]() {
        CString message;
        message.Format(_T("RTM link state changed: %d"), static_cast<int>(state));
        m_frame->appendDebugMessage(message);
    });
}

void CMainFrame::RtmEventHandler::onPublishResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode)
{
    CString message;
    message.Format(_T("RTM publish requestId=%llu result=%d"),
        static_cast<unsigned long long>(requestId),
        static_cast<int>(errorCode));
    m_frame->appendDebugMessage(message);
    if (m_frame->m_convoAIAPI) {
        m_frame->m_convoAIAPI->OnPublishResult(requestId, errorCode);
    }
}

void CMainFrame::RtmEventHandler::onSubscribeResult(const uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode)
{
    CString message;
    message.Format(_T("RTM subscribe channel=%S result=%d"), channelName ? channelName : "", static_cast<int>(errorCode));
    m_frame->appendDebugMessage(message);
    if (m_frame->m_convoAIAPI) {
        m_frame->m_convoAIAPI->OnSubscribeResult(requestId, channelName, errorCode);
    }
}

void CMainFrame::RtmEventHandler::onUnsubscribeResult(const uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode)
{
    CString message;
    message.Format(_T("RTM unsubscribe channel=%S result=%d"), channelName ? channelName : "", static_cast<int>(errorCode));
    m_frame->appendDebugMessage(message);
    if (m_frame->m_convoAIAPI) {
        m_frame->m_convoAIAPI->OnUnsubscribeResult(requestId, channelName, errorCode);
    }
}

void CMainFrame::OnSize(UINT nType, int cx, int cy)
{
    CFrameWnd::OnSize(nType, cx, cy);
    if (cx > 0 && cy > 0 && ::IsWindow(m_debugInfoList.GetSafeHwnd())) {
        layoutViews();
    }
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);
    CRect clientRect;
    GetClientRect(&clientRect);
    dc.FillSolidRect(&clientRect, kWindowBg);

    if (m_isChatSessionVisible) {
        drawRoundedCard(dc, getMessagesCardRect(), kCardBg, kCardBorder, 18);
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
            drawRoundedCard(dc, getStatusRect(), statusColor, kCardBorder, 16);
        }
    }

    drawRoundedCard(dc, getLogCardRect(), kCardBg, kCardBorder, 18);
    drawRoundedCard(dc, getLogListRect(), kLogSurface, kCardBorder, 14);
    drawRoundedCard(dc, getControlBarRect(), kCardBg, kCardBorder, 18);
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

    if (pWnd == &m_chatSessionView.GetAgentStateView().GetLabel()) {
        pDC->SetBkMode(TRANSPARENT);
        pDC->SetTextColor(m_statusTextColor);
        return static_cast<HBRUSH>(GetStockObject(NULL_BRUSH));
    }

    if (nCtlColor == CTLCOLOR_LISTBOX) {
        if (pWnd == &m_debugInfoList) {
            pDC->SetBkColor(kLogSurface);
            pDC->SetTextColor(kTextSecondary);
            return static_cast<HBRUSH>(m_brushLogSurface.GetSafeHandle());
        }
        if (pWnd == &m_chatSessionView.GetTranscriptList()) {
            pDC->SetBkColor(kCardBg);
            pDC->SetTextColor(kTextPrimary);
            return static_cast<HBRUSH>(m_brushCard.GetSafeHandle());
        }
    }

    const UINT controlId = pWnd->GetDlgCtrlID();
    if (nCtlColor == CTLCOLOR_BTN) {
        pDC->SetBkMode(TRANSPARENT);
        pDC->SetTextColor(kTextPrimary);
        if (controlId == IDC_BTN_START || controlId == IDC_BTN_MUTE || controlId == IDC_BTN_STOP) {
            return static_cast<HBRUSH>(m_brushCard.GetSafeHandle());
        }
    }

    if (nCtlColor == CTLCOLOR_STATIC) {
        pDC->SetBkMode(TRANSPARENT);
        pDC->SetTextColor(kTextSecondary);
        return static_cast<HBRUSH>(GetStockObject(NULL_BRUSH));
    }

    return brush;
}

void CMainFrame::OnStartClicked()
{
    startSession();
}

void CMainFrame::OnStopClicked()
{
    stopSession();
}

void CMainFrame::OnMuteClicked()
{
    m_isMicMuted = !m_isMicMuted;
    m_chatSessionView.UpdateMicButtonState(m_isMicMuted);
    if (m_rtcEngine) {
        m_rtcEngine->adjustRecordingSignalVolume(m_isMicMuted ? 0 : 100);
    }
}

LRESULT CMainFrame::OnExecuteUITask(WPARAM, LPARAM lParam)
{
    std::unique_ptr<UITask> task(reinterpret_cast<UITask*>(lParam));
    if (task && *task) {
        (*task)();
    }
    return 0;
}

void CMainFrame::OnDrawItem(int nIDCtl, LPDRAWITEMSTRUCT lpDrawItemStruct)
{
    if (!lpDrawItemStruct || nIDCtl != IDC_LIST_MESSAGES) {
        return;
    }

    CDC dc;
    dc.Attach(lpDrawItemStruct->hDC);

    const int index = static_cast<int>(lpDrawItemStruct->itemID);
    CRect itemRect(lpDrawItemStruct->rcItem);
    dc.FillSolidRect(itemRect, kCardBg);

    if (index >= 0 && index < static_cast<int>(m_transcripts.size())) {
        const Transcript& transcript = m_transcripts[index];
        const COLORREF rowColor = transcript.type == TranscriptType::User ? kUserRow : kAgentRow;

        CRect cardRect(itemRect);
        cardRect.DeflateRect(8, 4);
        dc.FillSolidRect(cardRect, rowColor);
        dc.Draw3dRect(cardRect, kCardBorder, kCardBorder);

        dc.SetBkMode(TRANSPARENT);

        CRect headerRect(cardRect);
        headerRect.DeflateRect(12, 10);
        CFont* oldFont = dc.SelectObject(&m_smallFont);
        dc.SetTextColor(kTextSecondary);
        const CString header = buildTranscriptHeader(transcript);
        dc.DrawText(header, &headerRect, DT_SINGLELINE | DT_NOPREFIX);

        CString message = StringUtils::Utf8ToCString(transcript.text);
        if (transcript.status != TranscriptStatus::End) {
            message += _T(" ...");
        }

        CRect messageRect(cardRect);
        messageRect.DeflateRect(12, 10);
        messageRect.top += 18;
        dc.SelectObject(&m_normalFont);
        dc.SetTextColor(kTextPrimary);
        dc.DrawText(message, &messageRect, DT_WORDBREAK | DT_NOPREFIX);
        dc.SelectObject(oldFont);
    }

    dc.Detach();
}

void CMainFrame::OnMeasureItem(int nIDCtl, LPMEASUREITEMSTRUCT lpMeasureItemStruct)
{
    if (!lpMeasureItemStruct || nIDCtl != IDC_LIST_MESSAGES) {
        return;
    }

    const int index = static_cast<int>(lpMeasureItemStruct->itemID);
    if (index < 0 || index >= static_cast<int>(m_transcripts.size())) {
        lpMeasureItemStruct->itemHeight = 56;
        return;
    }

    CClientDC dc(this);
    lpMeasureItemStruct->itemHeight = static_cast<UINT>(
        measureTranscriptItemHeight(dc, m_transcripts[index], getMessagesCardRect().Width() - 12));
}
