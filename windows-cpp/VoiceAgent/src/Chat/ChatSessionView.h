#pragma once

#include <afxcmn.h>
#include <afxwin.h>

#include "AgentStateView.h"

class CChatSessionView {
public:
    BOOL Create(CWnd* parent, UINT messagesListId, UINT muteButtonId, UINT stopButtonId, CFont* listFont, CFont* buttonFont);
    void Layout(const CRect& messagesBounds, const CRect& statusBounds, const CRect& controlBarBounds);
    void Show(BOOL show);
    void UpdateMicButtonState(bool isMuted);
    CListBox& GetTranscriptList();
    CButton& GetMuteButton();
    CButton& GetStopButton();
    CAgentStateView& GetAgentStateView();

private:
    CListBox m_transcriptList;
    CButton m_micButton;
    CButton m_stopButton;
    CAgentStateView m_agentStateView;
};
