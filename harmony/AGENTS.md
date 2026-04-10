# Conversational AI Quickstart Harmony — AI Assistant Guide

## How To Use This Project

This is a single-screen HarmonyOS quickstart for real-time voice conversation with a Shengwang Conversational AI Agent.

- If you are starting from scratch on HarmonyOS, use this project directly.
- If you already have a HarmonyOS app, copy the key parts into your codebase:
  - `KeyCenter.ets`
  - `resources/rawfile/env.example.local`
  - `TokenGenerator.ets`
  - `AgentStarter.ets`
  - `AgentChatController.ets`
  - `pages/Index.ets`

## Project Identity

- Bundle name: `cn.shengwang.convoai.quickstart.harmony`
- Module name: `entry`
- Entry ability: `entry/src/main/ets/entryability/EntryAbility.ets`
- Main page: `entry/src/main/ets/pages/Index.ets`

## Runtime Model

The Harmony version is a single-screen quickstart with:

- single-screen UI
- microphone permission before start
- demo token generation on device
- RTC join
- RTM login + subscribe
- RTM transcript parsing
- REST `/join` to start agent
- REST `/leave` to stop agent

Current scope includes:

- start / stop
- mute / unmute
- transcript rendering
- agent state rendering
- rolling status logs

Current scope excludes:

- text input
- image messaging
- backend-owned token generation
- multi-screen navigation

## Key Constraints

1. Keep the project minimal. Prefer small reusable helpers over framework-heavy architecture.
2. Preserve the main flow first: initialize → start agent → stop agent.
3. Harmony currently uses:
   - RTC for audio
   - RTM for transcript / state / error messages
4. Agent state updates come from RTM presence events, while transcript / error messages come from RTM message events.
5. Runtime config is loaded from `entry/src/main/resources/rawfile/env.local`, not hardcoded in ArkTS source.
