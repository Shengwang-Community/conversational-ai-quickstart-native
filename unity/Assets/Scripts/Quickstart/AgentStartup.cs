using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.UI;
using Agora.Rtc;
using Agora.Rtm;

namespace Quickstart
{
    public class AgentStartup : MonoBehaviour
    {
        public Text LogText;
        public Text TranscriptText;
        public Button StartButton;
        public Button MuteButton;
        public Button StopButton;

        private IRtcEngine _rtc;
        private IRtmClient _rtm;
        private readonly TranscriptManager _transcriptMgr = new TranscriptManager();
        private readonly List<string> _logEntries = new List<string>();
        private string _channelName = string.Empty;
        private string _agentId = string.Empty;
        private string _authToken = string.Empty;
        private string _agentStateText = "Idle";
        private int _lastAgentStateTurnId = -1;
        private bool _muted = false;
        private bool _permissionRequestInFlight = false;
        private ScrollRect _logScrollRect;
        private RectTransform _logContentRect;
        private ScrollRect _transcriptScrollRect;
        private RectTransform _transcriptContentRect;
        private Text _agentStateTextView;
        private Text _sessionMetaTextView;
        private RectTransform _shellRect;
        private RectTransform _headerRect;
        private RectTransform _mainPanelsRect;
        private RectTransform _footerRect;
        private RectTransform _transcriptPanelRect;
        private RectTransform _transcriptHeaderRect;
        private RectTransform _transcriptBodyRect;
        private RectTransform _logPanelRect;
        private RectTransform _logHeaderRect;
        private RectTransform _logBodyRect;
        private RectTransform _actionRowRect;
        private bool _dashboardBuilt = false;
        private int _lastScreenWidth = -1;
        private int _lastScreenHeight = -1;

        private const int UserUid = 1001086;
        private const string AgentUid = "1009527";
        private const int MaxLogLines = 200;
        private static readonly Color BackgroundColor = new Color(0.06f, 0.08f, 0.11f, 1f);
        private static readonly Color PanelColor = new Color(0.11f, 0.14f, 0.18f, 0.96f);
        private static readonly Color PrimaryTextColor = new Color(0.93f, 0.95f, 0.97f, 1f);
        private static readonly Color SecondaryTextColor = new Color(0.57f, 0.63f, 0.70f, 1f);
        private static readonly Color PrimaryButtonColor = new Color(0.20f, 0.42f, 0.84f, 1f);
        private static readonly Color SecondaryButtonColor = new Color(0.20f, 0.25f, 0.31f, 1f);
        private static readonly Color DangerButtonColor = new Color(0.72f, 0.24f, 0.22f, 1f);

        private void Awake()
        {
            EnvConfig.Load();
            BuildDashboardUi();
            SetupLogScrollView();
            SetupTranscriptScrollView();
            if (StartButton != null) 
            { 
                StartButton.onClick.AddListener(OnStart);
                SetButtonText(StartButton, "Start Agent");
            }
            if (MuteButton != null) 
            { 
                MuteButton.onClick.AddListener(OnToggleMute); 
                MuteButton.gameObject.SetActive(false);
                SetButtonText(MuteButton, "Mute");
            }
            if (StopButton != null) 
            { 
                StopButton.onClick.AddListener(OnStop); 
                StopButton.gameObject.SetActive(false);
                SetButtonText(StopButton, "Stop Agent");
            }
            RefreshLogView();
            RefreshTranscripts();
            UpdateAgentStateUi();
            UpdateSessionMeta();
            RefreshActionLayout();
        }

        private void SetButtonText(Button btn, string text)
        {
            var txt = btn.GetComponentInChildren<Text>(true);
            if (txt != null) txt.text = text;
        }

        private void Update()
        {
            if (!_dashboardBuilt) return;
            var waitingForLayout = (_mainPanelsRect != null && _mainPanelsRect.rect.width < 10f) ||
                                   (_actionRowRect != null && _actionRowRect.rect.width < 10f);
            if (!waitingForLayout && _lastScreenWidth == Screen.width && _lastScreenHeight == Screen.height) return;

            ApplyResponsiveLayout();
        }

        private string RandomChannel()
        {
            var r = UnityEngine.Random.Range(1000, 9999);
            return $"channel_unity_{r}";
        }

        private void AppendLog(string msg)
        {
            if (_logEntries.Count >= MaxLogLines)
            {
                _logEntries.RemoveAt(0);
            }
            _logEntries.Add($"<color=#738091>[{DateTime.Now:HH:mm:ss}]</color> {EscapeRichText(msg)}");
            RefreshLogView();
        }

        private void UpdateAgentStateUi()
        {
            if (_agentStateTextView != null)
            {
                _agentStateTextView.text = FormatAgentStateLabel(_agentStateText);
                _agentStateTextView.color = AgentStateTextColor(_agentStateText);
            }

            UpdateSessionMeta();
        }

        private string FormatAgentStateLabel(string state)
        {
            if (string.IsNullOrEmpty(state)) return "Idle";
            var normalized = state.Trim().ToLowerInvariant();
            switch (normalized)
            {
                case "silent":
                    return "Silent";
                case "listening":
                    return "Listening";
                case "thinking":
                    return "Thinking";
                case "speaking":
                    return "Speaking";
                case "idle":
                default:
                    return "Idle";
            }
        }

        private void RefreshTranscripts()
        {
            if (TranscriptText == null) return;

            if (_transcriptMgr.Items.Count == 0)
            {
                TranscriptText.text = "<color=#E7EBF0><b>No transcript yet</b></color>\n\n<color=#738091>Start Agent to see the live conversation transcript.</color>";
                RebuildScrollableText(_transcriptContentRect, _transcriptScrollRect);
                return;
            }

            var sb = new StringBuilder();
            for (var i = 0; i < _transcriptMgr.Items.Count; i++)
            {
                var t = _transcriptMgr.Items[i];
                var badge = t.Type == TranscriptType.User
                    ? "<color=#91A5BF><b>USER</b></color>"
                    : "<color=#E0BE87><b>AGENT</b></color>";
                var status = FormatTranscriptStatus(t.Status);
                sb.AppendLine($"{badge}  <color=#738091>{status}</color>");
                sb.AppendLine($"<color=#E7EBF0>{EscapeRichText(t.Text)}</color>");
                if (i < _transcriptMgr.Items.Count - 1)
                {
                    sb.AppendLine();
                }
            }
            TranscriptText.text = sb.ToString();
            RebuildScrollableText(_transcriptContentRect, _transcriptScrollRect);
        }

        private void SetupLogScrollView()
        {
            SetupTextScrollView(LogText, "LogViewport", ref _logScrollRect, ref _logContentRect);
        }

        private void SetupTranscriptScrollView()
        {
            SetupTextScrollView(TranscriptText, "TranscriptViewport", ref _transcriptScrollRect, ref _transcriptContentRect);
        }

        private void SetupTextScrollView(Text text, string viewportName, ref ScrollRect scrollRect, ref RectTransform contentRect)
        {
            if (text == null || scrollRect != null) return;

            var textRect = text.rectTransform;
            var hostRect = textRect.parent as RectTransform;
            if (hostRect == null) return;

            var viewport = CreateUiObject(viewportName, hostRect, typeof(Image), typeof(RectMask2D), typeof(ScrollRect));
            viewport.SetSiblingIndex(textRect.GetSiblingIndex());
            Stretch(viewport, 0f, 0f, 0f, 0f);
            viewport.sizeDelta = Vector2.zero;

            var viewportImage = viewport.GetComponent<Image>();
            viewportImage.color = new Color(0f, 0f, 0f, 0f);
            viewportImage.raycastTarget = false;

            scrollRect = viewport.GetComponent<ScrollRect>();
            scrollRect.horizontal = false;
            scrollRect.vertical = true;
            scrollRect.movementType = ScrollRect.MovementType.Clamped;
            scrollRect.scrollSensitivity = 28f;
            scrollRect.viewport = viewport;

            textRect.SetParent(viewport, false);
            textRect.anchorMin = new Vector2(0f, 1f);
            textRect.anchorMax = new Vector2(1f, 1f);
            textRect.pivot = new Vector2(0.5f, 1f);
            textRect.anchoredPosition = Vector2.zero;
            textRect.sizeDelta = Vector2.zero;

            text.horizontalOverflow = HorizontalWrapMode.Wrap;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            text.supportRichText = true;
            text.raycastTarget = false;

            var fitter = EnsureComponent<ContentSizeFitter>(text.gameObject);
            fitter.horizontalFit = ContentSizeFitter.FitMode.Unconstrained;
            fitter.verticalFit = ContentSizeFitter.FitMode.PreferredSize;

            contentRect = textRect;
            scrollRect.content = textRect;
        }

        private void BuildDashboardUi()
        {
            if (_dashboardBuilt || LogText == null || TranscriptText == null || StartButton == null || MuteButton == null || StopButton == null) return;

            ConfigureCanvas();

            var canvasRect = transform as RectTransform;
            if (canvasRect == null) return;

            CreateBackdrop(canvasRect);

            _shellRect = CreateUiObject("DashboardShell", canvasRect);
            Stretch(_shellRect, 16f, 16f, 16f, 16f);

            _headerRect = CreateUiObject("Header", _shellRect);
            var header = _headerRect;
            var headerLayout = EnsureComponent<VerticalLayoutGroup>(header.gameObject);
            headerLayout.padding = new RectOffset(0, 0, 0, 0);
            headerLayout.spacing = 2f;
            headerLayout.childAlignment = TextAnchor.UpperLeft;
            headerLayout.childControlWidth = true;
            headerLayout.childControlHeight = false;
            headerLayout.childForceExpandWidth = true;
            headerLayout.childForceExpandHeight = false;
            CreateTextElement(header, "Title", "Shengwang Conversational AI", 23, FontStyle.Bold, PrimaryTextColor, TextAnchor.MiddleLeft);
            _sessionMetaTextView = CreateTextElement(
                header,
                "SessionMeta",
                "Channel  --    •    Mic  Ready    •    Agent  Idle",
                14,
                FontStyle.Normal,
                SecondaryTextColor,
                TextAnchor.MiddleLeft
            );

            _mainPanelsRect = CreateUiObject("MainPanels", _shellRect);

            var transcriptPanel = CreatePanel(_mainPanelsRect, "TranscriptPanel", out _, out _);
            _transcriptPanelRect = transcriptPanel;
            _transcriptHeaderRect = CreateUiObject("TranscriptHeader", transcriptPanel);
            var transcriptHeader = _transcriptHeaderRect;
            var transcriptHeaderLayout = EnsureComponent<HorizontalLayoutGroup>(transcriptHeader.gameObject);
            transcriptHeaderLayout.spacing = 10f;
            transcriptHeaderLayout.childAlignment = TextAnchor.MiddleLeft;
            transcriptHeaderLayout.childControlWidth = false;
            transcriptHeaderLayout.childControlHeight = false;
            transcriptHeaderLayout.childForceExpandWidth = false;
            transcriptHeaderLayout.childForceExpandHeight = false;

            var transcriptHeaderCopy = CreateUiObject("TranscriptHeaderCopy", transcriptHeader);
            var transcriptHeaderCopyElement = EnsureComponent<LayoutElement>(transcriptHeaderCopy.gameObject);
            transcriptHeaderCopyElement.flexibleWidth = 1f;
            var transcriptTitle = CreateTextElement(transcriptHeaderCopy, "TranscriptTitle", "Transcript", 20, FontStyle.Bold, PrimaryTextColor, TextAnchor.MiddleLeft);
            Stretch(transcriptTitle.rectTransform, 0f, 0f, 0f, 0f);

            var stateBadge = CreateUiObject("AgentStateBadge", transcriptHeader);
            var stateBadgeElement = EnsureComponent<LayoutElement>(stateBadge.gameObject);
            stateBadgeElement.preferredWidth = ScaleSize(88f);
            stateBadgeElement.preferredHeight = ScaleSize(28f);
            _agentStateTextView = CreateTextElement(stateBadge, "AgentStateText", "Idle", 14, FontStyle.Bold, AgentStateTextColor("Idle"), TextAnchor.MiddleRight);
            Stretch(_agentStateTextView.rectTransform, 0f, 0f, 0f, 0f);

            _transcriptBodyRect = CreateUiObject("TranscriptBody", transcriptPanel);
            TranscriptText.transform.SetParent(_transcriptBodyRect, false);
            StyleReadingText(TranscriptText, 18, 1.28f);

            var logPanel = CreatePanel(_mainPanelsRect, "LogPanel", out _, out _);
            _logPanelRect = logPanel;
            _logHeaderRect = CreateUiObject("LogHeader", logPanel);
            var logTitle = CreateTextElement(_logHeaderRect, "LogTitle", "Log", 20, FontStyle.Bold, PrimaryTextColor, TextAnchor.MiddleLeft);
            Stretch(logTitle.rectTransform, 0f, 0f, 0f, 0f);

            _logBodyRect = CreateUiObject("LogBody", logPanel);
            LogText.transform.SetParent(_logBodyRect, false);
            StyleReadingText(LogText, 15, 1.24f);

            _footerRect = CreateUiObject("Footer", _shellRect);
            _actionRowRect = CreateUiObject("ActionRow", _footerRect);

            StartButton.transform.SetParent(_actionRowRect, false);
            MuteButton.transform.SetParent(_actionRowRect, false);
            StopButton.transform.SetParent(_actionRowRect, false);
            StyleButton(StartButton, PrimaryButtonColor, BackgroundColor);
            StyleButton(MuteButton, SecondaryButtonColor, PrimaryTextColor);
            StyleButton(StopButton, DangerButtonColor, PrimaryTextColor);

            _dashboardBuilt = true;
            ApplyResponsiveLayout();
        }

        private RectTransform CreatePanel(Transform parent, string name, out Image image, out LayoutElement layoutElement)
        {
            var panel = CreateUiObject(name, parent, typeof(Image));
            image = panel.GetComponent<Image>();
            image.color = new Color(0.12f, 0.15f, 0.19f, 1f);
            image.raycastTarget = false;

            var outline = EnsureComponent<Outline>(panel.gameObject);
            outline.effectColor = new Color(0.19f, 0.24f, 0.30f, 1f);
            outline.effectDistance = new Vector2(1f, -1f);

            layoutElement = null;
            return panel;
        }

        private void ConfigureCanvas()
        {
            var scaler = GetComponent<CanvasScaler>();
            if (scaler != null)
            {
                scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
                scaler.referenceResolution = new Vector2(1440f, 960f);
                scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
                scaler.matchWidthOrHeight = 0.58f;
            }
        }

        private void CreateBackdrop(RectTransform parent)
        {
            var background = CreateUiObject("Backdrop", parent, typeof(Image));
            background.SetSiblingIndex(0);
            Stretch(background, 0f, 0f, 0f, 0f);
            var backgroundImage = background.GetComponent<Image>();
            backgroundImage.color = BackgroundColor;
            backgroundImage.raycastTarget = false;
        }

        private void RefreshLogView()
        {
            if (LogText == null) return;

            LogText.text = _logEntries.Count == 0
                ? "<color=#738091>No logs yet</color>"
                : string.Join("\n", _logEntries);

            RebuildScrollableText(_logContentRect, _logScrollRect);
        }

        private void RebuildScrollableText(RectTransform contentRect, ScrollRect scrollRect)
        {
            if (contentRect != null)
            {
                LayoutRebuilder.ForceRebuildLayoutImmediate(contentRect);
            }

            Canvas.ForceUpdateCanvases();

            if (scrollRect != null)
            {
                scrollRect.verticalNormalizedPosition = 0f;
            }
        }

        private void UpdateSessionMeta()
        {
            if (_sessionMetaTextView == null) return;

            var channelLabel = string.IsNullOrEmpty(_channelName) ? "--" : _channelName;
            var micLabel = _rtc == null ? "Ready" : (_muted ? "Off" : "On");
            _sessionMetaTextView.text =
                $"Channel  {channelLabel}    •    Mic  {micLabel}    •    Agent  {FormatAgentStateLabel(_agentStateText)}";
        }

        private string FormatTranscriptStatus(TranscriptStatus status)
        {
            switch (status)
            {
                case TranscriptStatus.End:
                    return "completed";
                case TranscriptStatus.Interrupted:
                    return "interrupted";
                case TranscriptStatus.InProgress:
                    return "streaming";
                default:
                    return "unknown";
            }
        }

        private void RefreshActionLayout()
        {
            ApplyResponsiveLayout();
        }

        private void ApplyResponsiveLayout()
        {
            if (_shellRect == null) return;

            Canvas.ForceUpdateCanvases();
            var landscape = Screen.width > Screen.height;
            var wideLandscape = landscape && Screen.width >= 900;
            var compact = !wideLandscape;

            var shellWidth = Mathf.Max(0f, _shellRect.rect.width);
            var shellHeight = Mathf.Max(0f, _shellRect.rect.height);
            var sectionGap = compact ? 12f : 16f;
            var headerHeight = 52f;
            var footerHeight = compact ? 156f : 56f;

            if (_headerRect != null)
            {
                SetFrame(_headerRect, 0f, 0f, shellWidth, headerHeight);
            }

            if (_footerRect != null)
            {
                SetFrame(_footerRect, 0f, shellHeight - footerHeight, shellWidth, footerHeight);
            }

            if (_actionRowRect != null)
            {
                SetFrame(_actionRowRect, 0f, 0f, shellWidth, footerHeight);
            }

            if (_mainPanelsRect != null)
            {
                var mainTop = headerHeight + sectionGap;
                var mainHeight = Mathf.Max(180f, shellHeight - headerHeight - footerHeight - sectionGap * 2f);
                SetFrame(_mainPanelsRect, 0f, mainTop, shellWidth, mainHeight);
            }

            if (_mainPanelsRect != null && _transcriptPanelRect != null && _logPanelRect != null)
            {
                var gap = sectionGap;
                var width = Mathf.Max(0f, _mainPanelsRect.rect.width);
                var height = Mathf.Max(0f, _mainPanelsRect.rect.height);

                if (compact)
                {
                    var logHeight = Mathf.Clamp(height * 0.30f, 140f, 220f);
                    var transcriptHeight = Mathf.Max(220f, height - gap - logHeight);
                    SetFrame(_transcriptPanelRect, 0f, 0f, width, transcriptHeight);
                    SetFrame(_logPanelRect, 0f, transcriptHeight + gap, width, logHeight);
                }
                else
                {
                    var logWidth = Mathf.Clamp(width * 0.30f, 260f, 360f);
                    var transcriptWidth = Mathf.Max(420f, width - gap - logWidth);
                    SetFrame(_transcriptPanelRect, 0f, 0f, transcriptWidth, height);
                    SetFrame(_logPanelRect, transcriptWidth + gap, 0f, logWidth, height);
                }
            }

            LayoutPanelSections(_transcriptPanelRect, _transcriptHeaderRect, _transcriptBodyRect);
            LayoutPanelSections(_logPanelRect, _logHeaderRect, _logBodyRect);

            if (_actionRowRect != null)
            {
                LayoutActionButtons(compact);
            }

            _lastScreenWidth = Screen.width;
            _lastScreenHeight = Screen.height;

            LayoutRebuilder.ForceRebuildLayoutImmediate(transform as RectTransform);
        }

        private void LayoutPanelSections(RectTransform panelRect, RectTransform headerRect, RectTransform bodyRect)
        {
            if (panelRect == null || headerRect == null || bodyRect == null) return;

            var panelWidth = Mathf.Max(0f, panelRect.rect.width);
            var panelHeight = Mathf.Max(0f, panelRect.rect.height);
            var inset = ScaleSize(16f);
            var headerHeight = ScaleSize(32f);
            var bodyTop = inset + headerHeight + ScaleSize(10f);
            var bodyHeight = Mathf.Max(60f, panelHeight - bodyTop - inset);

            SetFrame(headerRect, inset, inset, Mathf.Max(0f, panelWidth - inset * 2f), headerHeight);
            SetFrame(bodyRect, inset, bodyTop, Mathf.Max(0f, panelWidth - inset * 2f), bodyHeight);
        }

        private void LayoutActionButtons(bool compact)
        {
            if (_actionRowRect == null) return;

            var rowWidth = Mathf.Max(0f, _actionRowRect.rect.width);
            var rowHeight = Mathf.Max(0f, _actionRowRect.rect.height);
            var buttonGap = compact ? ScaleSize(10f) : ScaleSize(12f);
            var buttonHeight = ScaleSize(50f);

            var visibleButtons = new List<Button>();
            if (StartButton != null && StartButton.gameObject.activeSelf) visibleButtons.Add(StartButton);
            if (MuteButton != null && MuteButton.gameObject.activeSelf) visibleButtons.Add(MuteButton);
            if (StopButton != null && StopButton.gameObject.activeSelf) visibleButtons.Add(StopButton);

            if (visibleButtons.Count == 0) return;

            if (compact)
            {
                var top = 0f;
                foreach (var button in visibleButtons)
                {
                    SetFrame(button.transform as RectTransform, 0f, top, rowWidth, buttonHeight);
                    top += buttonHeight + buttonGap;
                }
                return;
            }

            var widths = new List<float>();
            var totalWidth = 0f;
            for (var i = 0; i < visibleButtons.Count; i++)
            {
                var width = GetButtonWidth(visibleButtons[i], rowWidth);
                widths.Add(width);
                totalWidth += width;
            }
            totalWidth += buttonGap * (visibleButtons.Count - 1);

            var left = Mathf.Max(0f, (rowWidth - totalWidth) * 0.5f);
            var topOffset = Mathf.Max(0f, (rowHeight - buttonHeight) * 0.5f);

            for (var i = 0; i < visibleButtons.Count; i++)
            {
                SetFrame(visibleButtons[i].transform as RectTransform, left, topOffset, widths[i], buttonHeight);
                left += widths[i] + buttonGap;
            }
        }

        private float GetButtonWidth(Button button, float rowWidth)
        {
            if (button == StartButton) return Mathf.Min(220f, rowWidth);
            if (button == StopButton) return Mathf.Min(172f, rowWidth);
            return Mathf.Min(132f, rowWidth);
        }

        private void StyleButton(Button button, Color fillColor, Color labelColor)
        {
            if (button == null) return;

            var image = button.GetComponent<Image>();
            if (image != null)
            {
                image.color = fillColor;
                image.raycastTarget = true;
            }

            var colors = button.colors;
            colors.normalColor = fillColor;
            colors.highlightedColor = Color.Lerp(fillColor, Color.white, 0.08f);
            colors.pressedColor = Color.Lerp(fillColor, Color.black, 0.14f);
            colors.selectedColor = colors.highlightedColor;
            colors.disabledColor = new Color(fillColor.r, fillColor.g, fillColor.b, 0.38f);
            colors.colorMultiplier = 1f;
            colors.fadeDuration = 0.12f;
            button.colors = colors;

            var label = button.GetComponentInChildren<Text>(true);
            if (label != null)
            {
                label.fontSize = ResolveFontSize(17);
                label.fontStyle = FontStyle.Bold;
                label.alignment = TextAnchor.MiddleCenter;
                label.color = labelColor;
                label.horizontalOverflow = HorizontalWrapMode.Overflow;
                label.verticalOverflow = VerticalWrapMode.Overflow;
            }

            var layout = EnsureComponent<LayoutElement>(button.gameObject);
            layout.minHeight = ScaleSize(50f);
            layout.preferredHeight = ScaleSize(50f);
            layout.flexibleWidth = 1f;

            var outline = EnsureComponent<Outline>(button.gameObject);
            outline.effectColor = new Color(0.19f, 0.24f, 0.31f, 0.88f);
            outline.effectDistance = new Vector2(1f, -1f);
        }

        private void StyleReadingText(Text text, int fontSize, float lineSpacing)
        {
            if (text == null) return;

            text.fontSize = ResolveFontSize(fontSize);
            text.fontStyle = FontStyle.Normal;
            text.lineSpacing = lineSpacing;
            text.color = PrimaryTextColor;
            text.alignment = TextAnchor.UpperLeft;
            text.supportRichText = true;
            text.horizontalOverflow = HorizontalWrapMode.Wrap;
            text.verticalOverflow = VerticalWrapMode.Overflow;
        }

        private Text CreateTextElement(
            Transform parent,
            string name,
            string value,
            int fontSize,
            FontStyle fontStyle,
            Color color,
            TextAnchor alignment)
        {
            var textRect = CreateUiObject(name, parent, typeof(Text));
            var text = textRect.GetComponent<Text>();
            text.text = value;
            text.font = GetBuiltinFont();
            text.fontSize = ResolveFontSize(fontSize);
            text.fontStyle = fontStyle;
            text.color = color;
            text.alignment = alignment;
            text.supportRichText = true;
            text.horizontalOverflow = HorizontalWrapMode.Wrap;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            text.raycastTarget = false;
            return text;
        }

        private int ResolveFontSize(int baseSize)
        {
            return Mathf.RoundToInt(baseSize * GetUiScale());
        }

        private float ScaleSize(float baseSize)
        {
            return baseSize * GetUiScale();
        }

        private float GetUiScale()
        {
#if UNITY_ANDROID || UNITY_IOS
            var minDimension = Mathf.Min(Screen.width, Screen.height);
            if (minDimension >= 1440f) return 1.2f;
            if (minDimension >= 1080f) return 1.14f;
            if (minDimension >= 720f) return 1.08f;
#endif
            return 1f;
        }

        private Font GetBuiltinFont()
        {
            try
            {
                return Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            }
            catch (ArgumentException)
            {
                return Resources.GetBuiltinResource<Font>("Arial.ttf");
            }
        }

        private Color AgentStateTextColor(string state)
        {
            switch ((state ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "listening":
                    return new Color(0.42f, 0.62f, 0.52f, 1f);
                case "thinking":
                    return new Color(0.77f, 0.63f, 0.36f, 1f);
                case "speaking":
                    return new Color(0.73f, 0.48f, 0.33f, 1f);
                case "silent":
                    return new Color(0.42f, 0.45f, 0.50f, 1f);
                case "idle":
                default:
                    return new Color(0.48f, 0.54f, 0.62f, 1f);
            }
        }

        private string EscapeRichText(string value)
        {
            if (string.IsNullOrEmpty(value)) return string.Empty;
            return value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;");
        }

        private RectTransform CreateUiObject(string name, Transform parent, params Type[] extraComponents)
        {
            var components = new List<Type> { typeof(RectTransform) };
            if (extraComponents != null)
            {
                components.AddRange(extraComponents);
            }

            var go = new GameObject(name, components.ToArray());
            var rect = go.GetComponent<RectTransform>();
            rect.SetParent(parent, false);
            rect.localScale = Vector3.one;
            return rect;
        }

        private void Stretch(RectTransform rect, float left, float top, float right, float bottom)
        {
            if (rect == null) return;
            rect.anchorMin = Vector2.zero;
            rect.anchorMax = Vector2.one;
            rect.pivot = new Vector2(0.5f, 0.5f);
            rect.offsetMin = new Vector2(left, bottom);
            rect.offsetMax = new Vector2(-right, -top);
        }

        private void SetAnchors(RectTransform rect, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax)
        {
            if (rect == null) return;
            rect.anchorMin = anchorMin;
            rect.anchorMax = anchorMax;
            rect.pivot = new Vector2(0.5f, 0.5f);
            rect.offsetMin = offsetMin;
            rect.offsetMax = offsetMax;
        }

        private void SetFrame(RectTransform rect, float left, float top, float width, float height)
        {
            if (rect == null) return;
            rect.anchorMin = new Vector2(0f, 1f);
            rect.anchorMax = new Vector2(0f, 1f);
            rect.pivot = new Vector2(0f, 1f);
            rect.anchoredPosition = new Vector2(left, -top);
            rect.sizeDelta = new Vector2(Mathf.Max(0f, width), Mathf.Max(0f, height));
        }

        private T EnsureComponent<T>(GameObject go) where T : Component
        {
            var existing = go.GetComponent<T>();
            return existing != null ? existing : go.AddComponent<T>();
        }

        private void ApplyRtcAudioBestPractices()
        {
            if (_rtc == null) return;

            _rtc.EnableAudio();
            _rtc.SetAudioScenario(AUDIO_SCENARIO_TYPE.AUDIO_SCENARIO_AI_CLIENT);
            ApplyRtcAudioRouteParameters((int)AudioRoute.ROUTE_SPEAKERPHONE);
        }

        private void ApplyRtcAudioRouteParameters(int routing)
        {
            if (_rtc == null) return;

            SetRtcParameter("{\"che.audio.aec.split_srate_for_48k\":16000}", "aec split sample rate");
            SetRtcParameter("{\"che.audio.sf.enabled\":true}", "sound field enabled");
            SetRtcParameter("{\"che.audio.sf.stftType\":6}", "sound field stftType");
            SetRtcParameter("{\"che.audio.sf.ainlpLowLatencyFlag\":1}", "ainlp low latency");
            SetRtcParameter("{\"che.audio.sf.ainsLowLatencyFlag\":1}", "ains low latency");
            SetRtcParameter("{\"che.audio.sf.procChainMode\":1}", "proc chain mode");
            SetRtcParameter("{\"che.audio.sf.nlpDynamicMode\":1}", "nlp dynamic mode");
            SetRtcParameter(
                $"{{\"che.audio.sf.nlpAlgRoute\":{(IsHeadsetStyleRoute(routing) ? 0 : 1)}}}",
                "nlp algorithm route"
            );
        }

        private bool IsHeadsetStyleRoute(int routing)
        {
            return routing == (int)AudioRoute.ROUTE_HEADSET ||
                   routing == (int)AudioRoute.ROUTE_EARPIECE ||
                   routing == (int)AudioRoute.ROUTE_HEADSETNOMIC ||
                   routing == (int)AudioRoute.ROUTE_BLUETOOTH_DEVICE_HFP ||
                   routing == (int)AudioRoute.ROUTE_BLUETOOTH_DEVICE_A2DP;
        }

        private string AudioRouteLabel(int routing)
        {
            switch (routing)
            {
                case (int)AudioRoute.ROUTE_HEADSET:
                    return "headset";
                case (int)AudioRoute.ROUTE_EARPIECE:
                    return "earpiece";
                case (int)AudioRoute.ROUTE_HEADSETNOMIC:
                    return "headset-no-mic";
                case (int)AudioRoute.ROUTE_SPEAKERPHONE:
                    return "speakerphone";
                case (int)AudioRoute.ROUTE_LOUDSPEAKER:
                    return "loudspeaker";
                case (int)AudioRoute.ROUTE_BLUETOOTH_DEVICE_HFP:
                    return "bluetooth-hfp";
                case (int)AudioRoute.ROUTE_BLUETOOTH_DEVICE_A2DP:
                    return "bluetooth-a2dp";
                default:
                    return $"route-{routing}";
            }
        }

        private void HandleAudioRoutingChanged(int routing)
        {
            ApplyRtcAudioRouteParameters(routing);
            AppendLog("RTC 音频路由切换: " + AudioRouteLabel(routing));
        }

        private void ApplyAgentStateChange(AgentStateChange stateChange)
        {
            if (stateChange == null) return;

            _lastAgentStateTurnId = stateChange.TurnId;
            _agentStateText = stateChange.State;
            UpdateAgentStateUi();
            AppendLog("Agent state: " + FormatAgentStateLabel(_agentStateText));
        }

        private void ApplyAgentInterrupt(AgentInterrupt interruptEvent)
        {
            if (interruptEvent == null) return;

            AppendLog("Agent interrupt: turnId=" + interruptEvent.TurnId);
            if (_transcriptMgr.MarkInterrupted(interruptEvent.TurnId.ToString()))
            {
                RefreshTranscripts();
            }
        }

        private void SetRtcParameter(string parameters, string label)
        {
            if (_rtc == null) return;
            var result = _rtc.SetParameters(parameters);
            if (result < 0)
            {
                Debug.LogWarning($"RTC 参数设置失败 {label}: {result}");
            }
        }

        private void OnStart()
        {
            if (!TryRequestRuntimePermissions())
            {
                return;
            }

            BeginStart();
        }

        private void BeginStart()
        {
            if (StartButton != null) StartButton.interactable = false;
            _agentStateText = "Idle";
            _lastAgentStateTurnId = -1;
            UpdateAgentStateUi();
            AppendLog("Starting...");
            Debug.Log("Starting...");
            _channelName = RandomChannel();
            UpdateSessionMeta();
            StartCoroutine(StartFlow());
        }

        private bool TryRequestRuntimePermissions()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            if (_permissionRequestInFlight)
            {
                return false;
            }

            if (!UnityEngine.Android.Permission.HasUserAuthorizedPermission(UnityEngine.Android.Permission.Microphone))
            {
                _permissionRequestInFlight = true;
                AppendLog("Requesting microphone permission...");
                UnityEngine.Android.Permission.RequestUserPermission(UnityEngine.Android.Permission.Microphone);
                StartCoroutine(WaitForMicrophonePermission());
                return false;
            }
#endif
            return true;
        }

        private IEnumerator WaitForMicrophonePermission()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            const float timeoutSeconds = 10f;
            var elapsed = 0f;

            while (elapsed < timeoutSeconds)
            {
                if (UnityEngine.Android.Permission.HasUserAuthorizedPermission(UnityEngine.Android.Permission.Microphone))
                {
                    _permissionRequestInFlight = false;
                    AppendLog("Microphone permission granted");
                    BeginStart();
                    yield break;
                }

                elapsed += 0.25f;
                yield return new WaitForSeconds(0.25f);
            }

            _permissionRequestInFlight = false;
            AppendLog("Microphone permission is required on Android");
            if (StartButton != null) StartButton.interactable = true;
#else
            yield break;
#endif
        }

        private IEnumerator StartFlow()
        {
            string userToken = null;
            yield return TokenGenerator.GenerateUnifiedToken(_channelName, UserUid.ToString(),
                (tok) => { userToken = tok; AppendLog("获取 Token 成功"); Debug.Log("获取 Token 成功"); },
                (err) => { AppendLog("获取 Token 失败: " + err); Debug.LogError("获取 Token 失败: " + err); });
            if (string.IsNullOrEmpty(userToken)) { StartButton.interactable = true; yield break; }

            try
            {
                _rtc = Agora.Rtc.RtcEngine.CreateAgoraRtcEngine();
            }
            catch (DllNotFoundException e)
            {
                AppendLog("RtcEngine 初始化失败: " + e.Message);
                Debug.LogError("Agora RTC native plugin is unavailable in Editor: " + e);
                if (StartButton != null) StartButton.interactable = true;
                yield break;
            }

            var ctx = new RtcEngineContext();
            ctx.appId = EnvConfig.AppId;
            ctx.channelProfile = CHANNEL_PROFILE_TYPE.CHANNEL_PROFILE_LIVE_BROADCASTING;
            ctx.audioScenario = AUDIO_SCENARIO_TYPE.AUDIO_SCENARIO_AI_CLIENT;
            _rtc.Initialize(ctx);
            AppendLog("RtcEngine 初始化成功");
            Debug.Log("RtcEngine 初始化成功");
            _rtc.InitEventHandler(new RtcHandler(this));
            _rtc.SetChannelProfile(CHANNEL_PROFILE_TYPE.CHANNEL_PROFILE_LIVE_BROADCASTING);
            _rtc.SetClientRole(CLIENT_ROLE_TYPE.CLIENT_ROLE_BROADCASTER);
            ApplyRtcAudioBestPractices();
            _rtc.JoinChannel(userToken, _channelName, "", (uint)UserUid);
            var pubOpts = new ChannelMediaOptions();
            pubOpts.publishMicrophoneTrack.SetValue(true);
            pubOpts.autoSubscribeAudio.SetValue(true);
            _rtc.UpdateChannelMediaOptions(pubOpts);
            AppendLog("joinChannel 调用完成");
            Debug.Log("joinChannel 调用完成");
            _rtc.AdjustRecordingSignalVolume(100);
            _muted = false;
            AppendLog("已自动开麦");
            Debug.Log("已自动开麦");
            UpdateSessionMeta();

            var rtmInitOk = false;
            try
            {
                var cfg = new RtmConfig { appId = EnvConfig.AppId, userId = UserUid.ToString(), presenceTimeout = 30, useStringUserId = false };
                _rtm = RtmClient.CreateAgoraRtmClient(cfg);
                _rtm.OnMessageEvent += OnRtmMessageEvent;
                _rtm.OnPresenceEvent += OnRtmPresenceEvent;
                _rtm.OnConnectionStateChanged += (channel, state, reason) => AppendLog($"RTM {state} -> {reason}");
                rtmInitOk = true;
                AppendLog("RtmClient 初始化成功");
                Debug.Log("RtmClient 初始化成功");
            }
            catch (DllNotFoundException e)
            {
                AppendLog("RtmClient 初始化失败: " + e.Message);
                Debug.LogError("Agora RTM native plugin is unavailable in Editor: " + e);
            }
            catch (Exception e)
            {
                AppendLog("RtmClient 初始化失败: " + e.Message);
                Debug.LogError("RtmClient 初始化失败: " + e.Message);
            }
            if (!rtmInitOk) { StartButton.interactable = true; yield break; }

            AppendLog("rtmLogin 调用");
            Debug.Log("rtmLogin 调用");
            var loginTask = _rtm.LoginAsync(userToken);
            while (!loginTask.IsCompleted) yield return null;
            if (loginTask.Result.Status.Error)
            {
                AppendLog("rtmLogin 失败: " + loginTask.Result.Status.ErrorCode);
                Debug.LogError("rtmLogin 失败: " + loginTask.Result.Status.ErrorCode);
                StartButton.interactable = true; yield break;
            }
            else
            {
                AppendLog("rtmLogin 成功");
                Debug.Log("rtmLogin 成功");
            }
            var subTask = _rtm.SubscribeAsync(_channelName, new SubscribeOptions
            {
                withMessage = true,
                withMetadata = false,
                withPresence = true,
                withLock = false,
            });
            while (!subTask.IsCompleted) yield return null;
            if (subTask.Result.Status.Error)
            {
                AppendLog("Subscribe 失败: " + subTask.Result.Status.ErrorCode);
                Debug.LogError("Subscribe 失败: " + subTask.Result.Status.ErrorCode);
                StartButton.interactable = true; yield break;
            }

            string agentToken = null;
            yield return TokenGenerator.GenerateUnifiedToken(_channelName, AgentUid,
                (tok) => { agentToken = tok; AppendLog("获取 Agent Token 成功"); Debug.Log("获取 Agent Token 成功"); },
                (err) => { AppendLog("获取 Agent Token 失败: " + err); Debug.LogError("获取 Agent Token 失败: " + err); });
            if (string.IsNullOrEmpty(agentToken)) { StartButton.interactable = true; yield break; }

            string authToken = null;
            yield return TokenGenerator.GenerateUnifiedToken(_channelName, UserUid.ToString(),
                (tok) => { authToken = tok; AppendLog("获取 REST Auth Token 成功"); Debug.Log("获取 REST Auth Token 成功"); },
                (err) => { AppendLog("获取 REST Auth Token 失败: " + err); Debug.LogError("获取 REST Auth Token 失败: " + err); });
            if (string.IsNullOrEmpty(authToken)) { StartButton.interactable = true; yield break; }

            var agentStartOk = false;
            yield return AgentStarter.StartAgent(_channelName, AgentUid, agentToken, authToken, UserUid.ToString(),
                (agentId) =>
                {
                    _agentId = agentId;
                    _authToken = authToken;
                    agentStartOk = true;
                    AppendLog("Agent Start 成功");
                    Debug.Log("Agent Start 成功");
                },
                (err) => { AppendLog("Agent Start 失败: " + err); Debug.LogError("Agent Start 失败: " + err); StartButton.interactable = true; });

            if (!agentStartOk)
            {
                yield break;
            }

            AppendLog("Agent start successfully");
            Debug.Log("Agent start successfully");
            _agentStateText = "Idle";
            UpdateAgentStateUi();
            
            // 更新按钮状态
            if (StartButton != null) StartButton.gameObject.SetActive(false);
            if (MuteButton != null) MuteButton.gameObject.SetActive(true);
            if (StopButton != null) StopButton.gameObject.SetActive(true);
            RefreshActionLayout();
            UpdateSessionMeta();
        }

        private void OnToggleMute()
        {
            _muted = !_muted;
            _rtc?.AdjustRecordingSignalVolume(_muted ? 0 : 100);
            SetButtonText(MuteButton, _muted ? "Unmute" : "Mute");
            AppendLog(_muted ? "麦克风已关闭" : "麦克风已开启");
            UpdateSessionMeta();
            Debug.Log(_muted ? "Mic muted" : "Mic unmuted");
        }

        private void OnStop()
        {
            StartCoroutine(StopFlow());
        }

        private IEnumerator StopFlow()
        {
            if (_rtm != null)
            {
                var unsubTask = _rtm.UnsubscribeAsync(_channelName);
                while (!unsubTask.IsCompleted) yield return null;
                var logoutTask = _rtm.LogoutAsync();
                while (!logoutTask.IsCompleted) yield return null;
                Debug.Log("RTM unsubscribed and logged out");
            }
            if (!string.IsNullOrEmpty(_agentId))
            {
                yield return AgentStarter.StopAgent(
                    _agentId,
                    _authToken,
                    () => { AppendLog("Agent stopped successfully"); Debug.Log("Agent stopped successfully"); },
                    (err) => { AppendLog("Stop agent error: " + err); Debug.LogError("Stop agent error: " + err); }
                );
                _agentId = string.Empty;
            }
            _rtc?.LeaveChannel();
            _rtc?.Dispose();
            Debug.Log("RTC left and disposed");
            _rtc = null;
            _rtm = null;
            _authToken = string.Empty;
            _channelName = string.Empty;
            _muted = false;
            _agentStateText = "Idle";
            _lastAgentStateTurnId = -1;
            SetButtonText(MuteButton, "Mute");
            UpdateAgentStateUi();
            _transcriptMgr.Items.Clear();
            RefreshTranscripts();
            
            // 恢复按钮状态
            if (StartButton != null) { StartButton.gameObject.SetActive(true); StartButton.interactable = true; }
            if (MuteButton != null) MuteButton.gameObject.SetActive(false);
            if (StopButton != null) StopButton.gameObject.SetActive(false);
            RefreshActionLayout();
        }

        private void OnDestroy()
        {
            // Editor 停止运行时清理资源
            if (_rtc != null || _rtm != null || !string.IsNullOrEmpty(_agentId))
            {
                StartCoroutine(StopFlow());
            }
        }

        private void OnApplicationQuit()
        {
            // 应用退出时同步清理（协程可能不会执行完）
            if (!string.IsNullOrEmpty(_agentId))
            {
                Debug.Log("OnApplicationQuit: stopping agent...");
                // 同步停止 agent（协程在退出时不可靠）
                StartCoroutine(AgentStarter.StopAgent(_agentId, _authToken, () => {}, (err) => {}));
            }
            _rtc?.LeaveChannel();
            _rtc?.Dispose();
            _rtc = null;
            _rtm = null;
            _authToken = string.Empty;
        }

        private void OnRtmMessageEvent(MessageEvent @event)
        {
            var text = @event.message.GetData<string>();
            var messageType = AgentEventParser.ParseMessageType(text);
            var readableText = AgentEventParser.FormatConsoleMessage(text);
            Debug.Log($"RTM 收到消息 ({(string.IsNullOrEmpty(messageType) ? "unknown" : messageType)}): " + readableText);

            if (messageType != "assistant.transcription" &&
                messageType != "user.transcription" &&
                messageType != "message.interrupt" &&
                messageType != "message.error")
            {
                return;
            }

            var agentError = AgentEventParser.ParseMessageError(text, @event.publisher);
            var interruptEvent = AgentEventParser.ParseMessageInterrupt(text, @event.publisher);
            var updated = _transcriptMgr.UpsertFromJson(text);

            if (agentError != null)
            {
                AppendLog($"Agent error: type={agentError.Module}, code={agentError.Code}, msg={agentError.Message}");
            }

            if (interruptEvent != null)
            {
                ApplyAgentInterrupt(interruptEvent);
            }

            if (updated)
            {
                RefreshTranscripts();
            }
        }

        private void OnRtmPresenceEvent(PresenceEvent @event)
        {
            var stateChange = AgentEventParser.ParsePresenceEvent(
                @event,
                _channelName,
                _lastAgentStateTurnId,
                _agentStateText
            );
            if (stateChange == null) return;

            ApplyAgentStateChange(stateChange);
        }

        private class RtcHandler : IRtcEngineEventHandler
        {
            private readonly AgentStartup _owner;
            public RtcHandler(AgentStartup owner) { _owner = owner; }
            public override void OnJoinChannelSuccess(RtcConnection connection, int elapsed)
            {
                _owner.AppendLog($"RTC 加入成功 {connection.localUid}");
                Debug.Log($"RTC 加入成功 {connection.localUid}");
            }
            public override void OnUserJoined(RtcConnection connection, uint remoteUid, int elapsed)
            {
                _owner.AppendLog($"RTC onUserJoined uid:{remoteUid}");
                Debug.Log($"RTC onUserJoined uid:{remoteUid}");
            }
            public override void OnError(int err, string msg)
            {
                _owner.AppendLog($"RTC 错误 {err}");
                Debug.LogError($"RTC 错误 {err} {msg}");
            }

            public override void OnAudioRoutingChanged(int routing)
            {
                _owner.HandleAudioRoutingChanged(routing);
            }
        }
    }
}
