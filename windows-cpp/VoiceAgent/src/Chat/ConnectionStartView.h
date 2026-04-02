#pragma once

#include <afxwin.h>

class CConnectionStartView {
public:
    BOOL Create(CWnd* parent, UINT startButtonId, CFont* buttonFont);
    void Layout(const CRect& bounds);
    void Show(BOOL show);
    void SetStartButtonEnabled(BOOL enabled);
    CButton& GetStartButton();

private:
    CButton m_startButton;
};
