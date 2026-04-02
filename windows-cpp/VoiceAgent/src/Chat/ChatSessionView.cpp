#include "ChatSessionView.h"

BOOL CChatSessionView::Create(CWnd* parent, UINT messagesListId, UINT muteButtonId, UINT stopButtonId, CFont* listFont, CFont* buttonFont)
{
    if (!m_transcriptList.Create(WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_OWNERDRAWVARIABLE | LBS_NOINTEGRALHEIGHT | LBS_HASSTRINGS | LBS_NOSEL,
        CRect(0, 0, 10, 10), parent, messagesListId)) {
        return FALSE;
    }

    if (listFont) {
        m_transcriptList.SetFont(listFont);
    }

    if (!m_agentStateView.Create(parent, buttonFont)) {
        return FALSE;
    }

    if (!m_micButton.Create(_T("Mute"), WS_CHILD | BS_PUSHBUTTON, CRect(0, 0, 10, 10), parent, muteButtonId)) {
        return FALSE;
    }

    if (!m_stopButton.Create(_T("Stop Agent"), WS_CHILD | BS_PUSHBUTTON, CRect(0, 0, 10, 10), parent, stopButtonId)) {
        return FALSE;
    }

    if (buttonFont) {
        m_micButton.SetFont(buttonFont);
        m_stopButton.SetFont(buttonFont);
    }

    Show(FALSE);
    return TRUE;
}

void CChatSessionView::Layout(const CRect& messagesBounds, const CRect& statusBounds, const CRect& controlBarBounds)
{
    const int listInset = 6;
    const int buttonHeight = 40;
    const int buttonY = controlBarBounds.top + (controlBarBounds.Height() - buttonHeight) / 2;
    const int stopWidth = 120;
    const int muteWidth = 96;
    const int stopX = controlBarBounds.right - 8 - stopWidth;
    const int muteX = stopX - 8 - muteWidth;

    m_transcriptList.MoveWindow(messagesBounds.left + listInset, messagesBounds.top + listInset,
        messagesBounds.Width() - listInset * 2, messagesBounds.Height() - listInset * 2);

    m_agentStateView.Layout(statusBounds);
    m_micButton.MoveWindow(muteX, buttonY, muteWidth, buttonHeight);
    m_stopButton.MoveWindow(stopX, buttonY, stopWidth, buttonHeight);
}

void CChatSessionView::Show(BOOL show)
{
    m_transcriptList.ShowWindow(show ? SW_SHOW : SW_HIDE);
    m_micButton.ShowWindow(show ? SW_SHOW : SW_HIDE);
    m_stopButton.ShowWindow(show ? SW_SHOW : SW_HIDE);
    m_agentStateView.Show(show ? SW_SHOW : SW_HIDE);
}

void CChatSessionView::UpdateMicButtonState(bool isMuted)
{
    m_micButton.SetWindowText(isMuted ? _T("Unmute") : _T("Mute"));
}

CListBox& CChatSessionView::GetTranscriptList()
{
    return m_transcriptList;
}

CButton& CChatSessionView::GetMuteButton()
{
    return m_micButton;
}

CButton& CChatSessionView::GetStopButton()
{
    return m_stopButton;
}

CAgentStateView& CChatSessionView::GetAgentStateView()
{
    return m_agentStateView;
}
