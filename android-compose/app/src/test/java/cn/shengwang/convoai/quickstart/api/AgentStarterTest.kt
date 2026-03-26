package cn.shengwang.convoai.quickstart.api

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStarterTest {
    @Test
    fun buildJsonPayload_usesThreeStagePipeline() {
        val payload = AgentStarter.buildJsonPayload(
            name = "channel_compose_123456",
            channel = "channel_compose_123456",
            agentRtcUid = AgentStarter.DEFAULT_AGENT_RTC_UID,
            token = "agent-token",
            remoteRtcUids = listOf("*")
        )

        assertFalse(payload.has("pipeline_id"))

        val properties = payload.getJSONObject("properties")
        assertEquals("channel_compose_123456", payload.getString("name"))
        assertEquals("channel_compose_123456", properties.getString("channel"))
        assertEquals("agent-token", properties.getString("token"))
        assertTrue(properties.getJSONObject("advanced_features").getBoolean("enable_rtm"))
        assertEquals("fengming", properties.getJSONObject("asr").getString("vendor"))
        assertEquals("aliyun", properties.getJSONObject("llm").getString("vendor"))
        assertEquals("bytedance", properties.getJSONObject("tts").getString("vendor"))
        assertEquals("rtm", properties.getJSONObject("parameters").getString("data_channel"))
    }
}
