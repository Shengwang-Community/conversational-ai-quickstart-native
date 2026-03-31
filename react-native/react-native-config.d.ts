declare module 'react-native-config' {
  export interface NativeConfig {
    APP_ID?: string;
    AGORA_APP_ID?: string;
    APP_CERTIFICATE?: string;
    AGORA_APP_CERTIFICATE?: string;
    LLM_API_KEY?: string;
    LLM_URL?: string;
    LLM_MODEL?: string;
    TTS_BYTEDANCE_APP_ID?: string;
    TTS_BYTEDANCE_TOKEN?: string;
  }

  const Config: NativeConfig;
  export default Config;
}
