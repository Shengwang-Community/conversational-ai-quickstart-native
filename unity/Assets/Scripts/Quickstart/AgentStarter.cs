using System;
using System.Text;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

namespace Quickstart
{
    public static class AgentStarter
    {
        private const string JsonType = "application/json; charset=utf-8";
        private const string BaseUrl = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects";
        private const int MaxRedirects = 3;
        private const string DefaultAgentRtcUid = "1009527";
        private const string DefaultLlmSystemMessage = "你是一名有帮助的 AI 助手。";
        private const string DefaultGreetingMessage = "你好！我是你的 AI 助手，有什么可以帮你？";
        private const string DefaultFailureMessage = "抱歉，我暂时处理不了你的请求，请稍后再试。";

        public static IEnumerator StartAgent(
            string channelName,
            string agentRtcUid,
            string agentToken,
            string authToken,
            string remoteRtcUid,
            Action<string> onSuccess,
            Action<string> onError
        )
        {
            var missingFields = GetMissingInlineProviderFields();
            if (missingFields.Length > 0)
            {
                onError?.Invoke($"missing inline provider config: {string.Join(", ", missingFields)}");
                yield break;
            }

            var projectId = EnvConfig.AppId;
            var url = $"{BaseUrl}/{projectId}/join";
            Debug.Log("POST " + url);

            var uid = string.IsNullOrEmpty(agentRtcUid) ? DefaultAgentRtcUid : agentRtcUid;
            var req = new JoinReq
            {
                name = channelName,
                properties = new JoinProps
                {
                    channel = channelName,
                    token = agentToken,
                    agent_rtc_uid = uid,
                    remote_rtc_uids = new[] { remoteRtcUid },
                    enable_string_uid = false,
                    idle_timeout = 120,
                    advanced_features = new AdvancedFeatures
                    {
                        enable_rtm = true,
                    },
                    asr = new AsrConfig
                    {
                        vendor = "fengming",
                        language = "zh-CN",
                    },
                    llm = new LlmConfig
                    {
                        vendor = "aliyun",
                        url = EnvConfig.LlmUrl,
                        api_key = EnvConfig.LlmApiKey,
                        system_messages = new[]
                        {
                            new SystemMessage
                            {
                                role = "system",
                                content = DefaultLlmSystemMessage,
                            },
                        },
                        greeting_message = DefaultGreetingMessage,
                        failure_message = DefaultFailureMessage,
                        @params = new LlmParams
                        {
                            model = EnvConfig.LlmModel,
                        },
                    },
                    tts = new TtsConfig
                    {
                        vendor = "bytedance",
                        @params = new TtsParams
                        {
                            token = EnvConfig.TtsBytedanceToken,
                            app_id = EnvConfig.TtsBytedanceAppId,
                            cluster = "volcano_tts",
                            voice_type = "BV700_streaming",
                            speed_ratio = 1.0f,
                            volume_ratio = 1.0f,
                            pitch_ratio = 1.0f,
                        },
                    },
                    parameters = new AgentParameters
                    {
                        data_channel = "rtm",
                        enable_error_message = true,
                    },
                },
            };

            var body = JsonUtility.ToJson(req);

            yield return PostWithRedirects(url, body, authToken, (resp) =>
            {
                try
                {
                    var json = JsonUtility.FromJson<AgentResp>(resp);
                    if (json != null && !string.IsNullOrEmpty(json.agent_id))
                    {
                        Debug.Log("Agent start success");
                        onSuccess?.Invoke(json.agent_id);
                    }
                    else
                    {
                        Debug.LogError("agent_id empty");
                        onError?.Invoke("agent_id empty");
                    }
                }
                catch (Exception e)
                {
                    Debug.LogError("Agent start parse error: " + e.Message);
                    onError?.Invoke(e.Message);
                }
            }, onError, "start agent");
        }

        public static IEnumerator StopAgent(string agentId, string authToken, Action onSuccess, Action<string> onError)
        {
            var projectId = EnvConfig.AppId;
            var url = $"{BaseUrl}/{projectId}/agents/{agentId}/leave";
            Debug.Log("POST " + url);
            yield return PostWithRedirects(url, string.Empty, authToken, (resp) => { onSuccess?.Invoke(); }, onError, "stop agent");
        }

        private static string[] GetMissingInlineProviderFields()
        {
            var missing = new System.Collections.Generic.List<string>();
            if (string.IsNullOrEmpty(EnvConfig.LlmApiKey)) missing.Add("LLM_API_KEY");
            if (string.IsNullOrEmpty(EnvConfig.TtsBytedanceAppId)) missing.Add("TTS_BYTEDANCE_APP_ID");
            if (string.IsNullOrEmpty(EnvConfig.TtsBytedanceToken)) missing.Add("TTS_BYTEDANCE_TOKEN");
            return missing.ToArray();
        }

        private static IEnumerator PostWithRedirects(
            string url,
            string body,
            string authToken,
            Action<string> onSuccess,
            Action<string> onError,
            string actionName
        )
        {
            if (string.IsNullOrEmpty(authToken))
            {
                onError?.Invoke($"empty auth token for {actionName}");
                yield break;
            }

            var currentUrl = url;
            for (var i = 0; i <= MaxRedirects; i++)
            {
                using var req = CreateRequest(currentUrl, body, authToken);
                yield return req.SendWebRequest();

                if (IsRedirect(req.responseCode))
                {
                    var location = req.GetResponseHeader("Location") ?? req.GetResponseHeader("location");
                    Debug.Log($"Redirect ({req.responseCode}) to: {(string.IsNullOrEmpty(location) ? "<none>" : location)}");
                    if (string.IsNullOrEmpty(location))
                    {
                        onError?.Invoke($"redirect without location while trying to {actionName}");
                        yield break;
                    }
                    currentUrl = location;
                    continue;
                }

                if (req.result != UnityWebRequest.Result.Success)
                {
                    Debug.LogError($"HTTP {req.responseCode} {req.error} body: {req.downloadHandler.text}");
                    onError?.Invoke($"http {req.responseCode} {req.error}");
                    yield break;
                }

                Debug.Log($"HTTP {req.responseCode} success");
                onSuccess?.Invoke(req.downloadHandler.text);
                yield break;
            }

            onError?.Invoke($"too many redirects while trying to {actionName}");
        }

        private static UnityWebRequest CreateRequest(string url, string body, string authToken)
        {
            var req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
            req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(body));
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", JsonType);
            req.SetRequestHeader("Authorization", $"agora token={authToken}");
            req.uploadHandler.contentType = JsonType;
            return req;
        }

        private static bool IsRedirect(long code)
        {
            return code == 301 || code == 302 || code == 307 || code == 308;
        }

        [Serializable]
        private class AgentResp
        {
            public string agent_id;
        }

        [Serializable]
        private class JoinReq
        {
            public string name;
            public JoinProps properties;
        }

        [Serializable]
        private class JoinProps
        {
            public string channel;
            public string token;
            public string agent_rtc_uid;
            public string[] remote_rtc_uids;
            public bool enable_string_uid;
            public int idle_timeout;
            public AdvancedFeatures advanced_features;
            public AsrConfig asr;
            public LlmConfig llm;
            public TtsConfig tts;
            public AgentParameters parameters;
        }

        [Serializable]
        private class AdvancedFeatures
        {
            public bool enable_rtm;
        }

        [Serializable]
        private class AsrConfig
        {
            public string vendor;
            public string language;
        }

        [Serializable]
        private class LlmConfig
        {
            public string vendor;
            public string url;
            public string api_key;
            public SystemMessage[] system_messages;
            public string greeting_message;
            public string failure_message;
            public LlmParams @params;
        }

        [Serializable]
        private class SystemMessage
        {
            public string role;
            public string content;
        }

        [Serializable]
        private class LlmParams
        {
            public string model;
        }

        [Serializable]
        private class TtsConfig
        {
            public string vendor;
            public TtsParams @params;
        }

        [Serializable]
        private class TtsParams
        {
            public string token;
            public string app_id;
            public string cluster;
            public string voice_type;
            public float speed_ratio;
            public float volume_ratio;
            public float pitch_ratio;
        }

        [Serializable]
        private class AgentParameters
        {
            public string data_channel;
            public bool enable_error_message;
        }
    }
}
