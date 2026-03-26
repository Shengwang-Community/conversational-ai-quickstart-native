package cn.shengwang.convoai.quickstart;

/**
 * KeyCenter
 * Load values from BuildConfig, which are populated from env.properties at build time
 */
public class KeyCenter {
    public static final String APP_ID = BuildConfig.APP_ID;
    public static final String APP_CERTIFICATE = BuildConfig.APP_CERTIFICATE;
    public static final String LLM_API_KEY = BuildConfig.LLM_API_KEY;
    public static final String LLM_URL = BuildConfig.LLM_URL;
    public static final String LLM_MODEL = BuildConfig.LLM_MODEL;
    public static final String TTS_BYTEDANCE_APP_ID = BuildConfig.TTS_BYTEDANCE_APP_ID;
    public static final String TTS_BYTEDANCE_TOKEN = BuildConfig.TTS_BYTEDANCE_TOKEN;
}
