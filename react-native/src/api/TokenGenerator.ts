import { KeyCenter } from '../utils/KeyCenter';

type AgoraTokenType = 'rtc' | 'rtm';

/**
 * ⚠️ WARNING: DO NOT USE IN PRODUCTION ⚠️
 *
 * This TokenGenerator is for DEMO/DEVELOPMENT purposes ONLY.
 * Production MUST use backend server to generate tokens.
 */
export class TokenGenerator {
  private static readonly TOOLBOX_SERVER_HOST =
    'https://service.apprtc.cn/toolbox';

  static async generateUnifiedToken({
    channelName,
    uid,
    tokenTypes = ['rtc', 'rtm'],
  }: {
    channelName: string;
    uid: string | number;
    tokenTypes?: AgoraTokenType[];
  }): Promise<string> {
    const typeNumbers = tokenTypes.map((type) => (type === 'rtc' ? 1 : 2));

    const requestBody: Record<string, any> = {
      appId: KeyCenter.APP_ID,
      appCertificate: KeyCenter.APP_CERTIFICATE,
      channelName,
      uid: uid.toString(),
      expire: 60 * 60 * 24,
      src: 'ReactNative',
      ts: Date.now().toString(),
    };

    if (typeNumbers.length === 1) {
      requestBody['type'] = typeNumbers[0];
    } else {
      requestBody['types'] = typeNumbers;
    }

    const url = `${this.TOOLBOX_SERVER_HOST}/v2/token/generate`;
    
    // Log request details for debugging
    console.log('[TokenGenerator] Request URL:', url);
    console.log(
      '[TokenGenerator] Request body:',
      JSON.stringify({
        ...requestBody,
        appCertificate: requestBody.appCertificate ? '***' : '',
      }),
    );

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      });

      console.log('[TokenGenerator] Response status:', response.status, response.statusText);

      if (!response.ok) {
        const errorBody = await response.text();
        const errorMessage = `Token generation failed: httpCode=${response.status}, httpMsg=${errorBody}`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }

      const data = await response.json();
      console.log('[TokenGenerator] Response data:', JSON.stringify({
        code: data.code,
        message: data.message,
        hasToken: !!data.data?.token,
      }));

      if (data.code !== 0) {
        const errorMessage = `Token generation failed: code=${data.code}, message=${data.message || 'Unknown error'}`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }

      if (!data.data?.token) {
        const errorMessage = `Token generation failed: token is empty in response`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }

      return data.data.token;
    } catch (error: any) {
      // Handle network errors
      if (error instanceof TypeError && error.message.includes('fetch')) {
        const errorMessage = `Token generation network error: ${error.message}`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }
      // Re-throw other errors
      throw error;
    }
  }

  static async generateTokenAsync(
    channelName: string,
    uid: string | number,
    tokenTypes: AgoraTokenType[] = ['rtc'],
  ): Promise<string> {
    return this.generateUnifiedToken({
      channelName,
      uid,
      tokenTypes,
    });
  }
}
