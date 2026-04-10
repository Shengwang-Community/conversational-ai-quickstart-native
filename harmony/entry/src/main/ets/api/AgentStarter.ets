import { KeyCenter } from '../common/KeyCenter';
import { HttpClient } from './HttpClient';

interface StartAgentResponse {
  agent_id?: string;
}

export class AgentStarter {
  private static readonly JSON_CONTENT_TYPE =
    'application/json; charset=utf-8';
  private static readonly API_BASE_URL =
    'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';
  private static readonly DEFAULT_TTS_CLUSTER = 'volcano_tts';
  private static readonly DEFAULT_TTS_VOICE_TYPE = 'BV700_streaming';
  private static readonly SENSITIVE_KEYS: string[] = [
    'auth',
    'token',
    'password',
    'cert',
    'secret',
    'api_key',
    'appId',
    'app_id',
    'appCertificate'
  ];

  static ensureProviderConfigReady(): void {
    const missingFields = KeyCenter.validateProviderConfig();
    if (missingFields.length > 0) {
      throw new Error(
        `Missing inline provider config: ${missingFields.join(', ')}. Update harmony/entry/src/main/resources/rawfile/env.local and rebuild the app.`
      );
    }
  }

  static buildStartPayload(
    channelName: string,
    agentRtcUid: string,
    agentToken: string,
    remoteRtcUid: string,
    messageTransport: 'datastream' | 'rtm'
  ): string {
    let parametersJson =
      '{' +
      `"data_channel":${JSON.stringify(messageTransport)},` +
      '"enable_error_message":true';
    parametersJson += '}';

    let payload =
      '{' +
      `"name":${JSON.stringify(channelName)},` +
      '"properties":{' +
      `"channel":${JSON.stringify(channelName)},` +
      `"token":${JSON.stringify(agentToken)},` +
      `"agent_rtc_uid":${JSON.stringify(agentRtcUid)},` +
      `"remote_rtc_uids":[${JSON.stringify(remoteRtcUid)}],` +
      '"enable_string_uid":false,' +
      '"idle_timeout":120,' +
      `"advanced_features":{"enable_rtm":${messageTransport === 'rtm' ? 'true' : 'false'}},` +
      '"asr":{"vendor":"fengming","language":"zh-CN"},' +
      '"llm":{' +
      '"vendor":"aliyun",' +
      `"url":${JSON.stringify(KeyCenter.LLM_URL)},` +
      `"api_key":${JSON.stringify(KeyCenter.LLM_API_KEY)},` +
      '"system_messages":[{"role":"system","content":"你是一名有帮助的 AI 助手。"}],' +
      '"greeting_message":"你好！我是你的 AI 助手，有什么可以帮你？",' +
      '"failure_message":"抱歉，我暂时处理不了你的请求，请稍后再试。",' +
      `"params":{"model":${JSON.stringify(KeyCenter.LLM_MODEL)}}` +
      '},' +
      '"tts":{' +
      '"vendor":"bytedance",' +
      '"params":{' +
      `"token":${JSON.stringify(KeyCenter.TTS_BYTEDANCE_TOKEN)},` +
      `"app_id":${JSON.stringify(KeyCenter.TTS_BYTEDANCE_APP_ID)},` +
      `"cluster":${JSON.stringify(AgentStarter.DEFAULT_TTS_CLUSTER)},` +
      `"voice_type":${JSON.stringify(AgentStarter.DEFAULT_TTS_VOICE_TYPE)},` +
      '"speed_ratio":1.0,' +
      '"volume_ratio":1.0,' +
      '"pitch_ratio":1.0' +
      '}' +
      '},' +
      `"parameters":${parametersJson}` +
      '}' +
      '}';

    return payload;
  }

  static async startAgent(
    channelName: string,
    agentRtcUid: string,
    agentToken: string,
    authToken: string,
    remoteRtcUid: string,
    messageTransport: 'datastream' | 'rtm' = 'datastream'
  ): Promise<string> {
    AgentStarter.ensureProviderConfigReady();

    const url = `${AgentStarter.API_BASE_URL}/${KeyCenter.APP_ID}/join`;
    const body = AgentStarter.buildStartPayload(
      channelName,
      agentRtcUid,
      agentToken,
      remoteRtcUid,
      messageTransport
    );

    const response = await HttpClient.postJsonWithRedirects(
      url,
      AgentStarter.buildAuthHeaderJson(authToken),
      body
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Start agent error: httpCode=${response.statusCode}, httpMsg=${AgentStarter.maskJson(response.body)}`
      );
    }

    const agentId = AgentStarter.extractStringField(response.body, 'agent_id');
    if (agentId.length === 0) {
      throw new Error(
        `Failed to parse agentId from response: ${AgentStarter.maskJson(response.body)}`
      );
    }

    return agentId;
  }

  static async stopAgent(agentId: string, authToken: string): Promise<void> {
    const url =
      `${AgentStarter.API_BASE_URL}/${KeyCenter.APP_ID}/agents/${agentId}/leave`;

    const response = await HttpClient.postJsonWithRedirects(
      url,
      AgentStarter.buildAuthHeaderJson(authToken),
      ''
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Stop agent error: httpCode=${response.statusCode}, httpMsg=${AgentStarter.maskJson(response.body)}`
      );
    }
  }

  private static maskJson(input: string): string {
    let output = input;

    for (const key of AgentStarter.SENSITIVE_KEYS) {
      const pattern = new RegExp(`("${key}"\\s*:\\s*")([^"]*)(")`, 'gi');
      output = output.replace(pattern, '$1***$3');
    }

    output = output.replace(/(agora token=)[^",\s}]+/gi, '$1***');
    return output;
  }

  private static buildAuthHeaderJson(authToken: string): string {
    return (
      '{' +
      `"Authorization":${JSON.stringify(`agora token=${authToken}`)},` +
      `"Content-Type":${JSON.stringify(AgentStarter.JSON_CONTENT_TYPE)}` +
      '}'
    );
  }

  private static extractStringField(jsonText: string, fieldName: string): string {
    const pattern = new RegExp(
      `"${fieldName}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`,
      'g'
    );
    let match = pattern.exec(jsonText);
    let lastMatch = match;

    while (match) {
      lastMatch = match;
      match = pattern.exec(jsonText);
    }

    if (!lastMatch || lastMatch.length < 2) {
      return '';
    }

    return AgentStarter.decodeJsonString(lastMatch[1]);
  }

  private static decodeJsonString(value: string): string {
    try {
      return JSON.parse(`"${value.replace(/"/g, '\\"')}"`) as string;
    } catch (_) {
      return value;
    }
  }
}
