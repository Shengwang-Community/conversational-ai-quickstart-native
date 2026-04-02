#pragma once

#include <afxwin.h>

class CAgentStateView {
public:
    BOOL Create(CWnd* parent, CFont* font);
    void Layout(const CRect& bounds);
    void SetText(const CString& text);
    void Show(BOOL show);
    CStatic& GetLabel();

private:
    CStatic m_statusLabel;
};
