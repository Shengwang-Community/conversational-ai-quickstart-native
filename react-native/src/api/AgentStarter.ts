import { KeyCenter } from '../utils/KeyCenter';

interface StartAgentRequest {
  channelName: string;
  agentRtcUid: string;
  agentToken: string;
  authToken: string;
  remoteRtcUid: string;
  messageTransport?: 'datastream' | 'rtm';
}

interface StartAgentResponse {
  agent_id: string;
}

export class AgentStarter {
  private static readonly JSON_CONTENT_TYPE =
    'application/json; charset=utf-8';
  private static readonly API_BASE_URL =
    'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';
  private static readonly DEFAULT_MESSAGE_TRANSPORT = 'datastream';
  private static readonly DEFAULT_TTS_CLUSTER = 'volcano_tts';
  private static readonly DEFAULT_TTS_VOICE_TYPE = 'BV700_streaming';
  private static readonly REDIRECT_STATUS_CODES = new Set([301, 302, 307, 308]);
  private static readonly SENSITIVE_KEYS = new Set([
    'auth',
    'token',
    'password',
    'cert',
    'secret',
    'api_key',
    'appId',
    'app_id',
    'appCertificate',
  ]);

  private static maskValue(value: any): any {
    if (Array.isArray(value)) {
      return value.map((item) => this.maskValue(item));
    }

    if (value !== null && typeof value === 'object') {
      return Object.entries(value).reduce<Record<string, any>>(
        (masked, [key, nestedValue]) => {
          masked[key] = this.SENSITIVE_KEYS.has(key)
            ? '***'
            : this.maskValue(nestedValue);
          return masked;
        },
        {},
      );
    }

    return value;
  }

  private static maskJson(input: string): string {
    try {
      return JSON.stringify(this.maskValue(JSON.parse(input)));
    } catch {
      return input;
    }
  }

  private static ensureInlineProviderConfig(): void {
    const missingFields: string[] = [];

    if (!KeyCenter.LLM_API_KEY) {
      missingFields.push('LLM_API_KEY');
    }

    if (!KeyCenter.TTS_BYTEDANCE_APP_ID) {
      missingFields.push('TTS_BYTEDANCE_APP_ID');
    }

    if (!KeyCenter.TTS_BYTEDANCE_TOKEN) {
      missingFields.push('TTS_BYTEDANCE_TOKEN');
    }

    if (missingFields.length > 0) {
      throw new Error(
        `Missing inline provider config: ${missingFields.join(', ')}. Update react-native/.env and rebuild the app.`,
      );
    }
  }

  private static buildJsonPayload({
    channelName,
    agentRtcUid,
    agentToken,
    remoteRtcUid,
    messageTransport,
  }: {
    channelName: string;
    agentRtcUid: string;
    agentToken: string;
    remoteRtcUid: string;
    messageTransport: 'datastream' | 'rtm';
  }): Record<string, any> {
    const isRtmTransport = messageTransport === 'rtm';

    return {
      name: channelName,
      properties: {
        channel: channelName,
        token: agentToken,
        agent_rtc_uid: agentRtcUid,
        remote_rtc_uids: [remoteRtcUid],
        enable_string_uid: false,
        idle_timeout: 120,
        advanced_features: {
          enable_rtm: isRtmTransport,
        },
        asr: {
          vendor: 'fengming',
          language: 'zh-CN',
        },
        llm: {
          vendor: 'aliyun',
          url: KeyCenter.LLM_URL,
          api_key: KeyCenter.LLM_API_KEY,
          system_messages: [
            {
              role: 'system',
              content: '你是一名有帮助的 AI 助手。',
            },
          ],
          greeting_message: '你好！我是你的 AI 助手，有什么可以帮你？',
          failure_message: '抱歉，我暂时处理不了你的请求，请稍后再试。',
          params: {
            model: KeyCenter.LLM_MODEL,
          },
        },
        tts: {
          vendor: 'bytedance',
          params: {
            token: KeyCenter.TTS_BYTEDANCE_TOKEN,
            app_id: KeyCenter.TTS_BYTEDANCE_APP_ID,
            cluster: this.DEFAULT_TTS_CLUSTER,
            voice_type: this.DEFAULT_TTS_VOICE_TYPE,
            speed_ratio: 1.0,
            volume_ratio: 1.0,
            pitch_ratio: 1.0,
          },
        },
        parameters: {
          data_channel: messageTransport,
          enable_error_message: true,
          ...(isRtmTransport
            ? {}
            : {
                transcript: {
                  enable_words: false,
                },
              }),
        },
      },
    };
  }

  private static async postWithRedirects({
    url,
    headers,
    body,
    maxRedirects = 3,
  }: {
    url: string;
    headers: Record<string, string>;
    body: string;
    maxRedirects?: number;
  }): Promise<Response> {
    let currentUrl = url;

    for (
      let redirectCount = 0;
      redirectCount <= maxRedirects;
      redirectCount += 1
    ) {
      const response = await fetch(currentUrl, {
        method: 'POST',
        headers,
        body,
      });

      if (!this.REDIRECT_STATUS_CODES.has(response.status)) {
        return response;
      }

      const location =
        response.headers.get('location') ?? response.headers.get('Location');
      console.log(
        `[AgentStarter] Redirect (${response.status}) to: ${location ?? '<none>'}`,
      );

      if (!location) {
        return response;
      }

      currentUrl = location;
    }

    return fetch(currentUrl, {
      method: 'POST',
      headers,
      body,
    });
  }

  static async startAgentAsync(request: StartAgentRequest): Promise<string> {
    this.ensureInlineProviderConfig();

    const projectId = KeyCenter.APP_ID;
    const url = `${this.API_BASE_URL}/${projectId}/join`;
    const requestBody = this.buildJsonPayload({
      channelName: request.channelName,
      agentRtcUid: request.agentRtcUid,
      agentToken: request.agentToken,
      remoteRtcUid: request.remoteRtcUid,
      messageTransport:
        request.messageTransport || this.DEFAULT_MESSAGE_TRANSPORT,
    });
    const requestBodyString = JSON.stringify(requestBody);

    console.log('[AgentStarter] Request URL:', url);
    console.log(
      '[AgentStarter] Headers:',
      JSON.stringify({
        Authorization: '***',
        'Content-Type': this.JSON_CONTENT_TYPE,
      }),
    );
    console.log(
      '[AgentStarter] Request body:',
      this.maskJson(requestBodyString),
    );

    try {
      const response = await this.postWithRedirects({
        url,
        headers: {
          Authorization: `agora token=${request.authToken}`,
          'Content-Type': this.JSON_CONTENT_TYPE,
        },
        body: requestBodyString,
      });

      console.log(
        '[AgentStarter] Response status:',
        response.status,
        response.statusText,
      );

      const responseBody = await response.text();
      console.log(
        '[AgentStarter] Response body:',
        this.maskJson(responseBody),
      );

      if (!response.ok) {
        throw new Error(
          `Start agent error: httpCode=${response.status}, httpMsg=${responseBody}`,
        );
      }

      const data: StartAgentResponse = JSON.parse(responseBody);
      if (!data.agent_id) {
        throw new Error(
          `Failed to parse agentId from response: ${responseBody}`,
        );
      }

      return data.agent_id;
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes('fetch')) {
        throw new Error(`Start agent network error: ${error.message}`);
      }

      throw error;
    }
  }

  static async stopAgentAsync(
    agentId: string,
    authToken: string,
  ): Promise<void> {
    const projectId = KeyCenter.APP_ID;
    const url = `${this.API_BASE_URL}/${projectId}/agents/${agentId}/leave`;

    console.log('[AgentStarter] Stop agent request URL:', url);
    console.log(
      '[AgentStarter] Stop agent headers:',
      JSON.stringify({
        Authorization: '***',
        'Content-Type': this.JSON_CONTENT_TYPE,
      }),
    );

    try {
      const response = await this.postWithRedirects({
        url,
        headers: {
          Authorization: `agora token=${authToken}`,
          'Content-Type': this.JSON_CONTENT_TYPE,
        },
        body: '',
      });

      console.log(
        '[AgentStarter] Stop agent response status:',
        response.status,
        response.statusText,
      );

      const responseBody = await response.text();
      if (responseBody) {
        console.log(
          '[AgentStarter] Stop agent response body:',
          this.maskJson(responseBody),
        );
      }

      if (!response.ok) {
        throw new Error(
          `Stop agent error: httpCode=${response.status}, httpMsg=${responseBody}`,
        );
      }
    } catch (error: any) {
      if (error instanceof TypeError && error.message.includes('fetch')) {
        throw new Error(`Stop agent network error: ${error.message}`);
      }

      throw error;
    }
  }
}
