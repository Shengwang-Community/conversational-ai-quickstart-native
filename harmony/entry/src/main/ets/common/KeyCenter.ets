import common from '@ohos.app.ability.common';
import util from '@ohos.util';

interface KeyCenterConfig {
  APP_ID: string;
  APP_CERTIFICATE: string;
  LLM_API_KEY: string;
  LLM_URL: string;
  LLM_MODEL: string;
  TTS_BYTEDANCE_APP_ID: string;
  TTS_BYTEDANCE_TOKEN: string;
}

/**
 * Runtime config loader for the Harmony quickstart.
 *
 * Secrets are loaded from `resources/rawfile/env.local` instead of being
 * hardcoded in source files.
 */
export class KeyCenter {
  private static readonly RAW_FILE_PATH = 'env.local';
  private static readonly DEFAULT_LLM_URL =
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  private static readonly DEFAULT_LLM_MODEL = 'qwen-plus';
  private static readonly textDecoder = util.TextDecoder.create('utf-8');
  private static config?: KeyCenterConfig;

  static async ensureLoaded(context: common.Context): Promise<void> {
    if (KeyCenter.config) {
      return;
    }

    try {
      const content = await context.resourceManager.getRawFileContent(
        KeyCenter.RAW_FILE_PATH
      );
      const envText = KeyCenter.textDecoder.decodeToString(content);
      KeyCenter.config = KeyCenter.parseEnvContent(envText);
    } catch (error) {
      const errorMessage = (error as Error).message ?? 'Unknown error';
      throw new Error(
        `Failed to load Harmony config from resources/rawfile/${KeyCenter.RAW_FILE_PATH}: ${errorMessage}. Copy env.example.local to env.local and fill your local values.`
      );
    }
  }

  static get APP_ID(): string {
    return KeyCenter.currentConfig.APP_ID;
  }

  static get APP_CERTIFICATE(): string {
    return KeyCenter.currentConfig.APP_CERTIFICATE;
  }

  static get LLM_API_KEY(): string {
    return KeyCenter.currentConfig.LLM_API_KEY;
  }

  static get LLM_URL(): string {
    return KeyCenter.currentConfig.LLM_URL;
  }

  static get LLM_MODEL(): string {
    return KeyCenter.currentConfig.LLM_MODEL;
  }

  static get TTS_BYTEDANCE_APP_ID(): string {
    return KeyCenter.currentConfig.TTS_BYTEDANCE_APP_ID;
  }

  static get TTS_BYTEDANCE_TOKEN(): string {
    return KeyCenter.currentConfig.TTS_BYTEDANCE_TOKEN;
  }

  static validateAppConfig(): string[] {
    const missingFields: string[] = [];

    if (KeyCenter.APP_ID.length === 0) {
      missingFields.push('APP_ID');
    }

    if (KeyCenter.APP_CERTIFICATE.length === 0) {
      missingFields.push('APP_CERTIFICATE');
    }

    return missingFields;
  }

  static validateProviderConfig(): string[] {
    const missingFields: string[] = [];

    if (KeyCenter.LLM_API_KEY.length === 0) {
      missingFields.push('LLM_API_KEY');
    }

    if (KeyCenter.TTS_BYTEDANCE_APP_ID.length === 0) {
      missingFields.push('TTS_BYTEDANCE_APP_ID');
    }

    if (KeyCenter.TTS_BYTEDANCE_TOKEN.length === 0) {
      missingFields.push('TTS_BYTEDANCE_TOKEN');
    }

    return missingFields;
  }

  private static get currentConfig(): KeyCenterConfig {
    return KeyCenter.config ?? {
      APP_ID: '',
      APP_CERTIFICATE: '',
      LLM_API_KEY: '',
      LLM_URL: KeyCenter.DEFAULT_LLM_URL,
      LLM_MODEL: KeyCenter.DEFAULT_LLM_MODEL,
      TTS_BYTEDANCE_APP_ID: '',
      TTS_BYTEDANCE_TOKEN: ''
    };
  }

  private static parseEnvContent(content: string): KeyCenterConfig {
    const config: KeyCenterConfig = {
      APP_ID: '',
      APP_CERTIFICATE: '',
      LLM_API_KEY: '',
      LLM_URL: KeyCenter.DEFAULT_LLM_URL,
      LLM_MODEL: KeyCenter.DEFAULT_LLM_MODEL,
      TTS_BYTEDANCE_APP_ID: '',
      TTS_BYTEDANCE_TOKEN: ''
    };

    const lines = content.split(/\r?\n/);
    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (line.length === 0 || line.startsWith('#')) {
        continue;
      }

      const separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      const key = line.substring(0, separatorIndex).trim();
      const value = line.substring(separatorIndex + 1).trim();

      switch (key) {
        case 'APP_ID':
        case 'AGORA_APP_ID':
        case 'agora.appId':
          config.APP_ID = value;
          break;
        case 'APP_CERTIFICATE':
        case 'AGORA_APP_CERTIFICATE':
        case 'agora.appCertificate':
          config.APP_CERTIFICATE = value;
          break;
        case 'LLM_API_KEY':
        case 'agora.llmApiKey':
          config.LLM_API_KEY = value;
          break;
        case 'LLM_URL':
        case 'agora.llmUrl':
          if (value.length > 0) {
            config.LLM_URL = value;
          }
          break;
        case 'LLM_MODEL':
        case 'agora.llmModel':
          if (value.length > 0) {
            config.LLM_MODEL = value;
          }
          break;
        case 'TTS_BYTEDANCE_APP_ID':
        case 'agora.ttsBytedanceAppId':
          config.TTS_BYTEDANCE_APP_ID = value;
          break;
        case 'TTS_BYTEDANCE_TOKEN':
        case 'agora.ttsBytedanceToken':
          config.TTS_BYTEDANCE_TOKEN = value;
          break;
        default:
          break;
      }
    }

    return config;
  }
}
