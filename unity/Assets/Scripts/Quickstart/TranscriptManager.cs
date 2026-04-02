using System;
using System.Collections.Generic;
using UnityEngine;

namespace Quickstart
{
    public enum TranscriptType { User, Agent }
    public enum TranscriptStatus { InProgress, End, Interrupted, Unknown }

    [Serializable]
    public class TranscriptItem
    {
        public string Id;
        public TranscriptType Type;
        public string Text;
        public TranscriptStatus Status;
    }

    public class TranscriptManager
    {
        public readonly List<TranscriptItem> Items = new List<TranscriptItem>();

        public bool Upsert(TranscriptItem item)
        {
            var idx = Items.FindIndex(e => e.Id == item.Id && e.Type == item.Type);
            if (idx >= 0)
            {
                Items[idx] = item;
            }
            else
            {
                Items.Add(item);
            }
            return true;
        }

        public bool UpsertFromJson(string json)
        {
            var parsed = ParseJson(json);
            if (parsed == null) return false;
            return Upsert(parsed);
        }

        public bool MarkInterrupted(string turnId)
        {
            if (string.IsNullOrEmpty(turnId)) return false;

            var updated = false;
            for (var i = 0; i < Items.Count; i++)
            {
                if (Items[i].Id != turnId) continue;
                if (Items[i].Status == TranscriptStatus.Interrupted) continue;

                Items[i] = new TranscriptItem
                {
                    Id = Items[i].Id,
                    Type = Items[i].Type,
                    Text = Items[i].Text,
                    Status = TranscriptStatus.Interrupted,
                };
                updated = true;
            }

            return updated;
        }

        private TranscriptItem ParseJson(string json)
        {
            try
            {
                var payload = JsonUtility.FromJson<TranscriptPayload>(json);
                if (payload == null) return null;

                var objectType = payload.@object ?? string.Empty;
                TranscriptType type;
                if (objectType == "assistant.transcription")
                {
                    type = TranscriptType.Agent;
                }
                else if (objectType == "user.transcription")
                {
                    type = TranscriptType.User;
                }
                else
                {
                    return null;
                }

                var id = payload.turn_id > 0
                    ? payload.turn_id.ToString()
                    : !string.IsNullOrEmpty(payload.message_id)
                        ? payload.message_id
                        : DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();

                var text = string.IsNullOrEmpty(payload.text) ? "(empty)" : payload.text;
                var statusCode = AsInt(payload.turn_status);

                TranscriptStatus status;
                switch (statusCode)
                {
                    case null:
                    case 0:
                        status = TranscriptStatus.InProgress;
                        break;
                    case 1:
                        status = TranscriptStatus.End;
                        break;
                    case 2:
                        status = TranscriptStatus.Interrupted;
                        break;
                    default:
                        status = TranscriptStatus.Unknown;
                        break;
                }

                return new TranscriptItem
                {
                    Id = id,
                    Type = type,
                    Text = text,
                    Status = status,
                };
            }
            catch
            {
                return null;
            }
        }

        private int? AsInt(int value)
        {
            return value;
        }

        [Serializable]
        private class TranscriptPayload
        {
            public string @object;
            public string text;
            public int turn_id;
            public string message_id;
            public int turn_status;
        }
    }
}
