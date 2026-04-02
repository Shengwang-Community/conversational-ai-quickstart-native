using System;
using System.Collections.Generic;
using UnityEngine;

namespace Quickstart
{
    public static class EnvConfig
    {
        private const string DefaultLlmUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
        private const string DefaultLlmModel = "qwen-plus";

        public static string AppId { get; private set; } = string.Empty;
        public static string AppCertificate { get; private set; } = string.Empty;
        public static string LlmApiKey { get; private set; } = string.Empty;
        public static string LlmUrl { get; private set; } = DefaultLlmUrl;
        public static string LlmModel { get; private set; } = DefaultLlmModel;
        public static string TtsBytedanceAppId { get; private set; } = string.Empty;
        public static string TtsBytedanceToken { get; private set; } = string.Empty;

        public static void Load()
        {
            try
            {
                var text = Resources.Load<TextAsset>("env");
                if (text == null)
                {
                    Debug.LogError("EnvConfig: Resources/env(.txt) not found. Using empty defaults");
                    return;
                }
                var lines = text.text.Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
                var dict = new Dictionary<string, string>();
                foreach (var raw in lines)
                {
                    var line = raw.Trim();
                    if (string.IsNullOrEmpty(line) || line.StartsWith("#")) continue;
                    var idx = line.IndexOf('=');
                    if (idx <= 0) continue;
                    var key = line.Substring(0, idx).Trim();
                    var value = line.Substring(idx + 1).Trim();
                    dict[key] = value;
                }

                AppId = GetValue(dict, AppId, "APP_ID");
                AppCertificate = GetValue(dict, AppCertificate, "APP_CERTIFICATE");
                LlmApiKey = GetValue(dict, LlmApiKey, "LLM_API_KEY");
                LlmUrl = GetValue(dict, LlmUrl, "LLM_URL");
                LlmModel = GetValue(dict, LlmModel, "LLM_MODEL");
                TtsBytedanceAppId = GetValue(dict, TtsBytedanceAppId, "TTS_BYTEDANCE_APP_ID");
                TtsBytedanceToken = GetValue(dict, TtsBytedanceToken, "TTS_BYTEDANCE_TOKEN");

                Debug.Log(
                    $"EnvConfig: loaded AppId={(string.IsNullOrEmpty(AppId) ? "<empty>" : AppId)} " +
                    $"LlmModel={(string.IsNullOrEmpty(LlmModel) ? "<empty>" : LlmModel)}"
                );
            }
            catch (Exception)
            {
                Debug.LogError("EnvConfig: exception while loading env");
            }
        }

        private static string GetValue(Dictionary<string, string> dict, string fallback, string key)
        {
            if (dict.TryGetValue(key, out var value) && !string.IsNullOrEmpty(value))
            {
                return value;
            }
            return fallback;
        }
    }
}
