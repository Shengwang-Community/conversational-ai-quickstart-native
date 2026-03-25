// VoiceAgent.cpp: 定义应用程序的类行为。
//

#include "pch.h"
#include "framework.h"
#include "afxwinappex.h"
#include "afxdialogex.h"
#include "VoiceAgent.h"
#include "../ui/MainFrm.h"
#include "../tools/Logger.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif


// CVoiceAgentApp

BEGIN_MESSAGE_MAP(CVoiceAgentApp, CWinAppEx)
	ON_COMMAND(ID_APP_ABOUT, &CVoiceAgentApp::OnAppAbout)
	// 基于文件的标准文档命令
	ON_COMMAND(ID_FILE_NEW, &CWinAppEx::OnFileNew)
	ON_COMMAND(ID_FILE_OPEN, &CWinAppEx::OnFileOpen)
	// 标准打印设置命令
	ON_COMMAND(ID_FILE_PRINT_SETUP, &CWinAppEx::OnFilePrintSetup)
END_MESSAGE_MAP()


// CVoiceAgentApp 构造

CVoiceAgentApp::CVoiceAgentApp() noexcept
{
	m_bHiColorIcons = TRUE;


	m_nAppLook = 0;
	// 支持重新启动管理器
	m_dwRestartManagerSupportFlags = AFX_RESTART_MANAGER_SUPPORT_ALL_ASPECTS;
#ifdef _MANAGED
	// 如果应用程序是利用公共语言运行时支持(/clr)构建的，则: 
	//     1) 必须有此附加设置，"重新启动管理器"支持才能正常工作。
	//     2) 在您的项目中，您必须按照生成顺序向 System.Windows.Forms 添加引用。
	System::Windows::Forms::Application::SetUnhandledExceptionMode(System::Windows::Forms::UnhandledExceptionMode::ThrowException);
#endif

	// TODO: 将以下应用程序 ID 字符串替换为唯一的 ID 字符串；建议的字符串格式
	//为 CompanyName.ProductName.SubProduct.VersionInformation
	SetAppID(_T("VoiceAgent.AppID.NoVersion"));

	// TODO:  在此处添加构造代码，
	// 将所有重要的初始化放置在 InitInstance 中
}

// 唯一的 CVoiceAgentApp 对象

CVoiceAgentApp theApp;


// CVoiceAgentApp 初始化

BOOL CVoiceAgentApp::InitInstance()
{
	// 初始化现代日志系统
	auto& logger = Logger::instance();
#ifdef _DEBUG
	logger.setLogLevel(LogLevel::Debug);  // 开发时使用Debug级别
#else
	logger.setLogLevel(LogLevel::Info);   // 发布时使用Info级别
#endif
	logger.setLogFile("logs/VoiceAgent.log");

	LOG_INFO("VoiceAgent application starting...");

	// 初始化日志系统
	LOG_INFO("Application initialization started");

	// 如果一个运行在 Windows XP 上的应用程序清单指定要
	// 使用 ComCtl32.dll 版本 6 或更高版本来启用可视化方式，
	//则需要 InitCommonControlsEx()。  否则，将无法创建窗口。
	INITCOMMONCONTROLSEX InitCtrls;
	InitCtrls.dwSize = sizeof(InitCtrls);
	// 将它设置为包括所有要在应用程序中使用的
	// 公共控件类。
	InitCtrls.dwICC = ICC_WIN95_CLASSES;
	InitCommonControlsEx(&InitCtrls);

	CWinAppEx::InitInstance();

	LOG_INFO("Common controls initialized");

	// 初始化 OLE 库
	if (!AfxOleInit())
	{
		LOG_ERROR("OLE initialization failed");
		AfxMessageBox(IDP_OLE_INIT_FAILED);
		return FALSE;
	}

	LOG_INFO("OLE library initialized successfully");

	AfxEnableControlContainer();

	EnableTaskbarInteraction();

	// 使用 RichEdit 控件需要 AfxInitRichEdit2()
	// AfxInitRichEdit2();

	// 标准初始化
	// 如果未使用这些功能并希望减小
	// 最终可执行文件的大小，则应移除下列
	// 不需要的特定初始化例程
	// 更改用于存储设置的注册表项
	// 例如修改为公司或组织名
	SetRegistryKey(_T("应用程序向导生成的本地应用程序"));
	LoadStdProfileSettings(4);  // 加载标准 INI 文件选项(包括 MRU)

	LOG_INFO("Registry and profile settings loaded");

	// 不需要初始化复杂的UI管理器，因为我们只使用简单的对话框

	// 创建主框架窗口（非MDI）
	CMainFrame* pMainFrame = new CMainFrame;
	if (!pMainFrame || !pMainFrame->Create(nullptr, _T("Voice Agent")))
	{
		LOG_ERROR("Failed to create main frame window");
		delete pMainFrame;
		return FALSE;
	}
	m_pMainWnd = pMainFrame;
	// 不需要处理命令行和文档模板，因为我们不使用MDI
    // 主窗口已初始化，显示首页界面
    pMainFrame->ShowWindow(SW_SHOW);
    pMainFrame->UpdateWindow();
    
    LOG_INFO("Application initialized with home page in main window");
	return TRUE;
}

int CVoiceAgentApp::ExitInstance()
{
	LOG_INFO("Application exit started");
	
	//TODO: 处理可能已添加的附加资源
	AfxOleTerm(FALSE);

	LOG_INFO("Application exit completed");
	return CWinAppEx::ExitInstance();
}

// CVoiceAgentApp 消息处理程序


// 用于应用程序"关于"菜单项的 CAboutDlg 对话框

class CAboutDlg : public CDialogEx
{
public:
	CAboutDlg() noexcept;

// 对话框数据
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_ABOUTBOX };
#endif

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV 支持

// 实现
protected:
	DECLARE_MESSAGE_MAP()
};

CAboutDlg::CAboutDlg() noexcept : CDialogEx(IDD_ABOUTBOX)
{
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialogEx)
END_MESSAGE_MAP()

// 用于运行对话框的应用程序命令
void CVoiceAgentApp::OnAppAbout()
{
	CAboutDlg aboutDlg;
	aboutDlg.DoModal();
}

// CVoiceAgentApp 自定义加载/保存方法

void CVoiceAgentApp::PreLoadState()
{
	// No custom menus needed for this simple application
}

void CVoiceAgentApp::LoadCustomState()
{
	// No custom state to load
}

void CVoiceAgentApp::SaveCustomState()
{
	// No custom state to save
}

// CVoiceAgentApp 消息处理程序




