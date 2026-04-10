import { KeyCenter } from '../common/KeyCenter';
import { HttpClient } from './HttpClient';

type AgoraTokenType = 'rtc' | 'rtm';

export class TokenGenerator {
  private static readonly TOOLBOX_SERVER_HOST =
    'https://service.apprtc.cn/toolbox';

  static async generateUnifiedToken(
    channelName: string,
    uid: string | number,
    tokenTypes: AgoraTokenType[] = ['rtc', 'rtm']
  ): Promise<string> {
    const typeNumbers: number[] = [];
    for (const tokenType of tokenTypes) {
      typeNumbers.push(tokenType === 'rtc' ? 1 : 2);
    }

    const requestBody = TokenGenerator.buildRequestBody(
      channelName,
      uid.toString(),
      typeNumbers
    );

    const response = await HttpClient.postJson(
      `${TokenGenerator.TOOLBOX_SERVER_HOST}/v2/token/generate`,
      '{"Content-Type":"application/json"}',
      requestBody
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `Token generation failed: httpCode=${response.statusCode}, httpMsg=${response.body}`
      );
    }

    const code = TokenGenerator.extractIntField(response.body, 'code');
    if (code !== 0) {
      const message = TokenGenerator.extractStringField(response.body, 'message');
      throw new Error(
        `Token generation failed: code=${code}, message=${message.length > 0 ? message : 'Unknown error'}`
      );
    }

    const token = TokenGenerator.extractStringField(response.body, 'token');
    if (token.length === 0) {
      throw new Error('Token generation failed: token is empty in response');
    }

    return token;
  }

  private static buildRequestBody(
    channelName: string,
    uid: string,
    typeNumbers: number[]
  ): string {
    let body =
      '{' +
      `"appId":${JSON.stringify(KeyCenter.APP_ID)},` +
      `"appCertificate":${JSON.stringify(KeyCenter.APP_CERTIFICATE)},` +
      `"channelName":${JSON.stringify(channelName)},` +
      `"uid":${JSON.stringify(uid)},` +
      '"expire":86400,' +
      `"src":"HarmonyOS",` +
      `"ts":${JSON.stringify(Date.now().toString())},`;

    if (typeNumbers.length === 1) {
      body += `"type":${typeNumbers[0]}`;
    } else {
      body += `"types":[${typeNumbers.join(',')}]`;
    }

    body += '}';
    return body;
  }

  private static extractIntField(jsonText: string, fieldName: string): number {
    const pattern = new RegExp(`"${fieldName}"\\s*:\\s*(-?\\d+)`);
    const match = pattern.exec(jsonText);
    if (!match || match.length < 2) {
      return -1;
    }

    return Number.parseInt(match[1], 10);
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

    return TokenGenerator.decodeJsonString(lastMatch[1]);
  }

  private static decodeJsonString(value: string): string {
    try {
      return JSON.parse(`"${value.replace(/"/g, '\\"')}"`) as string;
    } catch (_) {
      return value;
    }
  }
}
