import common from '@ohos.app.ability.common';
import {
  AgentState,
  ConnectionState,
  TranscriptRecord,
  TranscriptStatus,
  TranscriptType,
  UiMutation
} from '../common/Types';
import {
  ChatTheme,
  getLogColor,
  getStartButtonLabel,
  getStatusColor,
  getStatusLabel,
  getTranscriptMetaLabel
} from '../common/Theme';
import { AgentChatController } from '../controller/AgentChatController';

@Entry
@Component
struct Index {
  private controller?: AgentChatController;
  private logScroller: Scroller = new Scroller();

  @State private connectionState: ConnectionState = ConnectionState.Idle;
  @State private agentState: AgentState = AgentState.IDLE;
  @State private isMuted: boolean = false;
  @State private transcripts: TranscriptRecord[] = [];
  @State private logs: string[] = [];
  @State private agentId: string = '';

  aboutToAppear(): void {
    this.ensureController();
    void this.initializePage();
  }

  aboutToDisappear(): void {
    void this.controller?.destroy();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(ChatTheme.bgPrimary);

      Column({ space: 16 }) {
        this.buildHeader();
        this.buildContent();
        this.buildActionBar();
      }
      .width('100%')
      .height('100%')
      .padding({
        top: 18,
        right: 16,
        bottom: 16,
        left: 16
      });
    }
    .width('100%')
    .height('100%');
  }

  private async initializePage(): Promise<void> {
    try {
      await this.ensureController().initialize(this.requireHostContext());
    } catch (error) {
      const message = (error as Error).message ?? 'Unknown error';
      this.showToast(message);
    }
  }

  @Builder
  private buildHeader() {
    Column({ space: 4 }) {
      Text('Shengwang Conversational AI')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(ChatTheme.textTitle);

      Text('Real-time Voice Conversation Demo')
        .fontSize(13)
        .fontColor(ChatTheme.textSubtitle);
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%');
  }

  @Builder
  private buildContent() {
    Column({ space: 8 }) {
      this.buildLogCard();
      this.buildTranscriptCard();
    }
    .layoutWeight(1)
    .width('100%');
  }

  @Builder
  private buildLogCard() {
    Column() {
      Column({ space: 4 }) {
        if (this.logs.length === 0) {
          Text('log')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(ChatTheme.textSecondary);
        } else {
          List({ space: 2, scroller: this.logScroller }) {
            ForEach(
              this.logs,
              (log: string, index: number) => {
                ListItem() {
                  Text(log)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor(getLogColor(log));
                }
              },
              (log: string, index: number) => `${index}-${log}`
            );
          }
          .width('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring);
        }
      }
      .width('100%')
      .height('100%')
      .padding(12)
      .backgroundColor(ChatTheme.bgLogInner)
      .borderRadius(11);
    }
    .width('100%')
    .layoutWeight(3)
    .padding(1)
    .backgroundColor(ChatTheme.bgLogOuter)
    .borderRadius(12)
    .border({
      width: 1,
      color: ChatTheme.border
    });
  }

  @Builder
  private buildTranscriptCard() {
    Column({ space: 0 }) {
      if (this.transcripts.length === 0) {
        this.buildTranscriptEmptyState();
      } else {
        List({ space: 8 }) {
          ForEach(
            this.transcripts,
            (item: TranscriptRecord) => {
              ListItem() {
                this.buildTranscriptRow(item);
              }
            },
            (item: TranscriptRecord) =>
              `${item.type}-${item.turnId}-${item.status}-${item.text}`
          );
        }
        .width('100%')
        .layoutWeight(1)
        .padding({
          top: 12,
          right: 12,
          bottom: 12,
          left: 12
        })
        .edgeEffect(EdgeEffect.Spring);
      }

      Divider()
        .strokeWidth(1)
        .color(ChatTheme.border);

      Row({ space: 8 }) {
        Circle()
          .width(10)
          .height(10)
          .fill(getStatusColor(this.connectionState, this.agentState));

        Text(getStatusLabel(this.connectionState, this.agentState))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(getStatusColor(this.connectionState, this.agentState));
      }
      .width('100%')
      .padding({
        top: 10,
        right: 12,
        bottom: 10,
        left: 12
      })
      .backgroundColor(ChatTheme.bgSecondary);
    }
    .width('100%')
    .layoutWeight(7)
    .backgroundColor(ChatTheme.bgCard)
    .borderRadius(12)
    .border({
      width: 1,
      color: ChatTheme.border
    })
    .clip(true);
  }

  @Builder
  private buildTranscriptEmptyState() {
    Column({ space: 8 }) {
      Blank()
        .layoutWeight(1);

      Text('No transcript yet')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(ChatTheme.textTitle);

      Text('Start Agent to see the live conversation transcript.')
        .fontSize(13)
        .fontColor(ChatTheme.textSecondary)
        .textAlign(TextAlign.Center);

      Blank()
        .layoutWeight(1);
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(28);
  }

  @Builder
  private buildTranscriptRow(item: TranscriptRecord) {
    Row() {
      if (item.type !== TranscriptType.USER) {
        this.buildAvatar('AI', ChatTheme.accentBlue);
        Blank()
          .width(8);
      }

      Column({ space: 4 }) {
        Text(item.text)
          .fontSize(14)
          .lineHeight(20)
          .fontColor(
            item.type === TranscriptType.USER
              ? ChatTheme.bubbleUserText
              : ChatTheme.bubbleAgentText
          )
          .padding({
            top: 9,
            right: 12,
            bottom: 9,
            left: 12
          })
          .backgroundColor(
            item.type === TranscriptType.USER
              ? ChatTheme.bubbleUserBg
              : ChatTheme.bubbleAgentBg
          )
          .borderRadius({
            topLeft: item.type === TranscriptType.USER ? 16 : 2,
            topRight: item.type === TranscriptType.USER ? 2 : 16,
            bottomLeft: 16,
            bottomRight: 16
          })
          .opacity(item.status === TranscriptStatus.IN_PROGRESS ? 0.92 : 1)
          .constraintSize({
            maxWidth: '100%'
          });

        if (getTranscriptMetaLabel(item.status).length > 0) {
          Text(getTranscriptMetaLabel(item.status))
            .fontSize(12)
            .fontColor(ChatTheme.warningAmberLight)
            .textAlign(
              item.type === TranscriptType.USER
                ? TextAlign.End
                : TextAlign.Start
            );
        }
      }
      .alignItems(
        item.type === TranscriptType.USER
          ? HorizontalAlign.End
          : HorizontalAlign.Start
      )
      .constraintSize({
        maxWidth: '78%'
      });

      if (item.type === TranscriptType.USER) {
        Blank()
          .width(8);
        this.buildAvatar('Me', ChatTheme.successGreen);
      }
    }
    .width('100%')
    .justifyContent(
      item.type === TranscriptType.USER ? FlexAlign.End : FlexAlign.Start
    )
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private buildAvatar(label: string, backgroundColor: string) {
    Text(label)
      .width(32)
      .height(32)
      .borderRadius(16)
      .textAlign(TextAlign.Center)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .backgroundColor(backgroundColor)
      .padding({ top: 8, bottom: 8 });
  }

  @Builder
  private buildActionBar() {
    if (this.connectionState !== ConnectionState.Connected) {
      Button(getStartButtonLabel(this.connectionState))
        .width('100%')
        .height(56)
        .enabled(this.connectionState !== ConnectionState.Connecting)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(
          this.connectionState === ConnectionState.Error
            ? ChatTheme.errorRedDark
            : ChatTheme.buttonStart
        )
        .borderRadius(10)
        .onClick(() => {
          void this.handleStartTap();
        });
    } else {
      Row({ space: 18 }) {
        Button(this.isMuted ? 'Off' : 'Mic')
          .width(56)
          .height(56)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(
            this.isMuted ? ChatTheme.micMutedText : ChatTheme.micNormalText
          )
          .backgroundColor(
            this.isMuted ? ChatTheme.micMutedBg : ChatTheme.micNormalBg
          )
          .borderRadius(28)
          .onClick(() => {
            this.ensureController().toggleMute();
          });

        Button('Stop Agent')
          .layoutWeight(1)
          .height(56)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(ChatTheme.buttonStop)
          .borderRadius(10)
          .onClick(() => {
            void this.handleStopTap();
          });
      }
      .width('100%');
    }
  }

  private async handleStartTap(): Promise<void> {
    try {
      const controller = this.ensureController();
      const granted = await controller.ensureMicrophonePermission(
        this.requireHostContext()
      );
      if (!granted) {
        this.showToast('Allow microphone access to start a voice conversation.');
        return;
      }

      await controller.startConnection();
    } catch (error) {
      const message = (error as Error).message ?? 'Unknown error';
      this.showToast(message);
    }
  }

  private async handleStopTap(): Promise<void> {
    try {
      await this.ensureController().stopAgent();
    } catch (error) {
      const message = (error as Error).message ?? 'Unknown error';
      this.showToast(message);
    }
  }

  private ensureController(): AgentChatController {
    if (!this.controller) {
      this.controller = new AgentChatController((mutation: UiMutation) => {
        this.applyMutation(mutation);
      });
    }

    return this.controller;
  }

  private applyMutation(mutation: UiMutation): void {
    if (mutation.connectionState !== undefined) {
      this.connectionState = mutation.connectionState;
    }

    if (mutation.agentState !== undefined) {
      this.agentState = mutation.agentState;
    }

    if (mutation.isMuted !== undefined) {
      this.isMuted = mutation.isMuted;
    }

    if (mutation.transcripts !== undefined) {
      this.transcripts = mutation.transcripts;
    }

    if (mutation.logs !== undefined) {
      this.logs = mutation.logs;
      this.scrollLogsToBottom();
    }

    if (mutation.agentId !== undefined) {
      this.agentId = mutation.agentId;
    }
  }

  private requireHostContext(): common.Context {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      throw new Error('Failed to access UIAbilityContext from the current page');
    }

    return hostContext as common.Context;
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message });
  }

  private scrollLogsToBottom(): void {
    if (this.logs.length === 0) {
      return;
    }

    setTimeout(() => {
      try {
        this.logScroller.scrollEdge(Edge.Bottom);
      } catch (_) {
      }
    }, 0);
  }
}
