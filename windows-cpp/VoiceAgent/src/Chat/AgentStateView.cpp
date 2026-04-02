#include "AgentStateView.h"

BOOL CAgentStateView::Create(CWnd* parent, CFont* font)
{
    if (!m_statusLabel.Create(_T(""), WS_CHILD | SS_CENTER | SS_CENTERIMAGE, CRect(0, 0, 10, 10), parent)) {
        return FALSE;
    }

    if (font) {
        m_statusLabel.SetFont(font);
    }

    m_statusLabel.ShowWindow(SW_HIDE);
    return TRUE;
}

void CAgentStateView::Layout(const CRect& bounds)
{
    m_statusLabel.MoveWindow(bounds.left, bounds.top, bounds.Width(), bounds.Height());
}

void CAgentStateView::SetText(const CString& text)
{
    m_statusLabel.SetWindowText(text);
}

void CAgentStateView::Show(BOOL show)
{
    m_statusLabel.ShowWindow(show ? SW_SHOW : SW_HIDE);
}

CStatic& CAgentStateView::GetLabel()
{
    return m_statusLabel;
}
