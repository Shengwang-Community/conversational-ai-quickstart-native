using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using Agora.Rtm;
using UnityEngine;

namespace Quickstart
{
    [Serializable]
    public class AgentStateChange
    {
        public string AgentUserId;
        public string State;
        public int TurnId;
    }

    [Serializable]
    public class AgentError
    {
        public string AgentUserId;
        public string Module;
        public int Code;
        public string Message;
        public long Timestamp;
        public int? TurnId;
    }

    [Serializable]
    public class AgentInterrupt
    {
        public string AgentUserId;
        public int TurnId;
    }

    public static class AgentEventParser
    {
        private static readonly HashSet<string> SupportedPresenceStates = new HashSet<string>
        {
            "silent",
            "listening",
            "thinking",
            "speaking",
        };

        public static string FormatConsoleMessage(string rawMessage)
        {
            return Regex.Replace(
                rawMessage,
                "\\\\u([0-9a-fA-F]{4})",
                match =>
                {
                    if (!int.TryParse(match.Groups[1].Value, System.Globalization.NumberStyles.HexNumber, null, out var codeUnit))
                    {
                        return match.Value;
                    }
                    return ((char)codeUnit).ToString();
                }
            );
        }

        public static string ParseMessageType(string rawMessage)
        {
            try
            {
                var payload = JsonUtility.FromJson<MessageEnvelope>(rawMessage);
                if (payload == null) return string.Empty;
                return !string.IsNullOrEmpty(payload.@object)
                    ? payload.@object
                    : payload.event_type ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }

        public static string FormatPresenceEvent(PresenceEvent @event)
        {
            if (@event == null) return "PresenceEvent(null)";

            var builder = new System.Text.StringBuilder();
            builder.Append("PresenceEvent { ");
            builder.Append("type=").Append(@event.type);
            builder.Append(", channelType=").Append(@event.channelType);
            builder.Append(", channelName=").Append(@event.channelName ?? string.Empty);
            builder.Append(", publisher=").Append(@event.publisher ?? string.Empty);

            builder.Append(", stateItems=[");
            if (@event.stateItems != null)
            {
                for (var i = 0; i < @event.stateItems.Length; i++)
                {
                    var item = @event.stateItems[i];
                    if (item == null) continue;
                    if (i > 0) builder.Append(", ");
                    builder.Append(item.key ?? string.Empty).Append("=").Append(item.value ?? string.Empty);
                }
            }
            builder.Append("]");

            if (@event.interval != null)
            {
                builder.Append(", interval=");
                builder.Append("{ joinCount=").Append(@event.interval.joinUserList?.Length ?? 0);
                builder.Append(", leaveCount=").Append(@event.interval.leaveUserList?.Length ?? 0);
                builder.Append(", timeoutCount=").Append(@event.interval.timeoutUserList?.Length ?? 0);
                builder.Append(", userStateCount=").Append(@event.interval.userStateList?.Length ?? 0);
                builder.Append(" }");
            }

            if (@event.snapshot != null)
            {
                builder.Append(", snapshot=");
                builder.Append("{ userStateCount=").Append(@event.snapshot.userStateList?.Length ?? 0);
                builder.Append(" }");
            }

            builder.Append(" }");
            return builder.ToString();
        }

        public static AgentStateChange ParsePresenceEvent(
            PresenceEvent @event,
            string currentChannelName,
            int lastTurnId,
            string lastState
        )
        {
            if (@event == null) return null;
            if (@event.channelName != currentChannelName) return null;
            if (@event.channelType != RTM_CHANNEL_TYPE.MESSAGE) return null;
            if (@event.type != RTM_PRESENCE_EVENT_TYPE.REMOTE_STATE_CHANGED) return null;

            var stateMap = new Dictionary<string, string>();
            if (@event.stateItems != null)
            {
                foreach (var item in @event.stateItems)
                {
                    if (item == null || string.IsNullOrEmpty(item.key)) continue;
                    stateMap[item.key] = item.value ?? string.Empty;
                }
            }

            var state = (stateMap.TryGetValue("state", out var stateValue) ? stateValue : string.Empty).Trim().ToLowerInvariant();
            if (string.IsNullOrEmpty(state)) return null;
            if (!SupportedPresenceStates.Contains(state)) return null;

            var turnId = 0;
            if (stateMap.TryGetValue("turn_id", out var turnIdValue))
            {
                int.TryParse(turnIdValue, out turnId);
            }

            if (turnId < lastTurnId) return null;
            if (turnId == lastTurnId && state == (lastState ?? string.Empty).Trim().ToLowerInvariant()) return null;

            return new AgentStateChange
            {
                AgentUserId = @event.publisher ?? string.Empty,
                State = state,
                TurnId = turnId,
            };
        }

        public static AgentInterrupt ParseMessageInterrupt(string rawMessage, string agentUserId)
        {
            try
            {
                var payload = JsonUtility.FromJson<MessageInterruptPayload>(rawMessage);
                if (payload == null) return null;
                if ((payload.@object ?? string.Empty) != "message.interrupt") return null;

                return new AgentInterrupt
                {
                    AgentUserId = agentUserId ?? string.Empty,
                    TurnId = payload.turn_id,
                };
            }
            catch
            {
                return null;
            }
        }

        public static AgentError ParseMessageError(string rawMessage, string agentUserId)
        {
            try
            {
                var payload = JsonUtility.FromJson<MessageErrorPayload>(rawMessage);
                if (payload == null) return null;
                if ((payload.@object ?? string.Empty) != "message.error") return null;

                return new AgentError
                {
                    AgentUserId = agentUserId ?? string.Empty,
                    Module = payload.module ?? string.Empty,
                    Code = payload.code,
                    Message = string.IsNullOrEmpty(payload.message) ? "Unknown error" : payload.message,
                    Timestamp = payload.send_ts,
                    TurnId = payload.turn_id > 0 ? payload.turn_id : (int?)null,
                };
            }
            catch
            {
                return null;
            }
        }

        [Serializable]
        private class MessageErrorPayload
        {
            public string @object;
            public string module;
            public int code;
            public string message;
            public long send_ts;
            public int turn_id;
        }

        [Serializable]
        private class MessageInterruptPayload
        {
            public string @object;
            public int turn_id;
        }

        [Serializable]
        private class MessageEnvelope
        {
            public string @object;
            public string event_type;
        }
    }
}
