#include "ConnectionStartView.h"

BOOL CConnectionStartView::Create(CWnd* parent, UINT startButtonId, CFont* buttonFont)
{
    if (!m_startButton.Create(_T("Start Agent"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), parent, startButtonId)) {
        return FALSE;
    }

    if (buttonFont) {
        m_startButton.SetFont(buttonFont);
    }

    return TRUE;
}

void CConnectionStartView::Layout(const CRect& bounds)
{
    const int inset = 12;
    const int buttonHeight = 44;
    const int buttonY = bounds.top + (bounds.Height() - buttonHeight) / 2;
    m_startButton.MoveWindow(bounds.left + inset, buttonY, bounds.Width() - inset * 2, buttonHeight);
}

void CConnectionStartView::Show(BOOL show)
{
    m_startButton.ShowWindow(show ? SW_SHOW : SW_HIDE);
}

void CConnectionStartView::SetStartButtonEnabled(BOOL enabled)
{
    m_startButton.EnableWindow(enabled);
}

CButton& CConnectionStartView::GetStartButton()
{
    return m_startButton;
}
