using System;
using System.Text;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

namespace Quickstart
{
    public static class TokenGenerator
    {
        private const string Host = "https://service.apprtc.cn/toolbox";

        public static IEnumerator GenerateUnifiedToken(string channelName, string uid, Action<string> onSuccess, Action<string> onError)
        {
            if (string.IsNullOrEmpty(EnvConfig.AppId) || string.IsNullOrEmpty(EnvConfig.AppCertificate))
            {
                Debug.LogError("TokenGenerator: AppId/AppCertificate is empty. Please fill Assets/Resources/env.txt");
                onError?.Invoke("empty AppId/AppCertificate");
                yield break;
            }
            var bodyObj = new TokenReq
            {
                appId = EnvConfig.AppId,
                appCertificate = EnvConfig.AppCertificate,
                channelName = channelName,
                expire = 60 * 60 * 24,
                src = "Unity",
                ts = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString(),
                types = new[] { 1, 2 },
                uid = uid,
            };
            var json = JsonUtility.ToJson(bodyObj);
            var url = $"{Host}/v2/token/generate";
            Debug.Log($"GenerateUnifiedToken {url} {Mask(json)}");
            using var req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
            var bytes = Encoding.UTF8.GetBytes(json);
            req.uploadHandler = new UploadHandlerRaw(bytes);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            yield return req.SendWebRequest();
            if (req.result != UnityWebRequest.Result.Success)
            {
                onError?.Invoke($"http {req.responseCode} {req.error}");
                yield break;
            }
            try
            {
                var wrapper = JsonUtility.FromJson<TokenResp>(req.downloadHandler.text);
                if (wrapper.code != 0)
                {
                    onError?.Invoke($"service code {wrapper.code} {wrapper.message}");
                }
                else
                {
                    onSuccess?.Invoke(wrapper.data.token);
                }
            }
            catch (Exception e)
            {
                onError?.Invoke(e.Message);
            }
        }

        [Serializable]
        private class TokenResp
        {
            public int code;
            public string message;
            public Data data;
        }

        [Serializable]
        private class Data
        {
            public string token;
        }
        [Serializable]
        private class TokenReq
        {
            public string appId;
            public string appCertificate;
            public string channelName;
            public int expire;
            public string src;
            public string ts;
            public int[] types;
            public string uid;
        }

        private static string Mask(string input)
        {
            try
            {
                var obj = JsonUtility.FromJson<TokenReq>(input);
                var safe = new TokenReq
                {
                    appId = obj.appId,
                    appCertificate = "***",
                    channelName = obj.channelName,
                    expire = obj.expire,
                    src = obj.src,
                    ts = obj.ts,
                    types = obj.types,
                    uid = obj.uid,
                };
                return JsonUtility.ToJson(safe);
            }
            catch
            {
                return input;
            }
        }
    }
}
