import Config from 'react-native-config';

export class KeyCenter {
  private static readonly DEFAULT_LLM_URL =
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  private static readonly DEFAULT_LLM_MODEL = 'qwen-plus';

  private static getConfigValue(
    keys: string[],
    fallback: string = '',
  ): string {
    const config = Config as unknown as Record<string, unknown>;

    for (const key of keys) {
      const value = config[key];
      if (typeof value === 'string' && value.trim().length > 0) {
        return value;
      }
    }

    return fallback;
  }

  static get APP_ID(): string {
    return this.getConfigValue(['APP_ID', 'AGORA_APP_ID']);
  }

  static get AGORA_APP_ID(): string {
    return this.APP_ID;
  }

  static get APP_CERTIFICATE(): string {
    return this.getConfigValue(['APP_CERTIFICATE', 'AGORA_APP_CERTIFICATE']);
  }

  static get AGORA_APP_CERTIFICATE(): string {
    return this.APP_CERTIFICATE;
  }

  static get LLM_API_KEY(): string {
    return this.getConfigValue(['LLM_API_KEY']);
  }

  static get LLM_URL(): string {
    return this.getConfigValue(['LLM_URL'], this.DEFAULT_LLM_URL);
  }

  static get LLM_MODEL(): string {
    return this.getConfigValue(['LLM_MODEL'], this.DEFAULT_LLM_MODEL);
  }

  static get TTS_BYTEDANCE_APP_ID(): string {
    return this.getConfigValue(['TTS_BYTEDANCE_APP_ID']);
  }

  static get TTS_BYTEDANCE_TOKEN(): string {
    return this.getConfigValue(['TTS_BYTEDANCE_TOKEN']);
  }
}
