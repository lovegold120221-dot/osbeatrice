# Beatrice OS — Private Agent

Beatrice OS is an Android-only Flutter application for task execution on a
user's phone. It combines chat and dictation with an OpenAI-compatible model,
Android Accessibility Service automation, and an optional embedded Beatrice
Voice experience.

The app is the **execution plane** in OSBeatrice. It can carry out device
tasks, while the separate `../Beatrice-Voice` app is the user-facing
conversational voice interface.

## Features

- Native chat and dictation input, plus text-to-speech replies.
- Agent mode for structured, model-generated actions.
- Multi-step task execution: screen dump, model decision, gesture/action,
  recovery, and repeat-until-complete loop.
- Android Accessibility Service control for reading UI, tapping, typing,
  scrolling, swiping, navigation, and screenshots on supported Android APIs.
- App launching, contacts, calling, SMS, email, alarms, volume, brightness,
  notifications, Shizuku integration, and optional on-device vision support.
- Local chat sessions, skills, task history, and settings persistence.
- Optional Telegram polling channel for remote device commands.
- A dedicated embedded `https://osbeatrice.vercel.app/` WebView page, opened from
  the Agent input bar without replacing the existing dictation microphone.
- Firebase Realtime Database task listener for Beatrice Voice task handoff.

## Architecture

```text
Flutter HomeScreen
  ├── Chat / local dictation / TTS
  ├── ActionHandler
  │     └── TaskExecutor → ScreenAutomationService → Android accessibility
  ├── FirebaseTaskBridge
  │     └── deviceTasks/{deviceId}/{taskId}
  └── BeatriceVoiceScreen (embedded web view)
        └── https://beatrice.eburon.ai
```

`ActionHandler` handles one-step actions and constructs `TaskExecutor` for an
`execute_task` goal. `TaskExecutor` asks the configured model for the next
action after reading the current accessibility tree, executes it through the
native MethodChannel, reports progress, and uses recovery when necessary.

## Beatrice Voice task bridge

The embedded voice page identifies the local device and writes a confirmed
high-level goal to Firebase. `FirebaseTaskBridge` listens at
`deviceTasks/{deviceId}`, atomically changes an `incoming` task to `claimed`,
executes it through the existing action path, and writes progress plus final
`done` or `failed` status.

This implementation is a foundation, not a production authorization model.
Before remote deployment, configure Firebase Realtime Database rules and a
real user-to-device pairing flow. Do not expose a device task queue with open
database rules.

## Requirements

- Flutter stable with Android SDK and Java/Kotlin 17.
- Android 8.0 / API 26 or newer; API 30+ is recommended for screenshots.
- A configured OpenAI-compatible AI provider. Gemini-compatible endpoints are
  the default.
- Accessibility Service enabled for screen automation.
- Firebase Android configuration in `android/app/google-services.json` for the
  voice task queue.

## Run and verify

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

Build a release APK with:

```bash
flutter build apk --release
```

Release builds currently use debug signing until a production signing key is
configured. Build success verifies compilation only; test on a physical device
for microphone, accessibility, Firebase, and background behavior.

## Permissions and safety

The app requests permissions needed for microphone, notifications, contacts,
calls, SMS, alarms, settings, and accessibility-driven automation. Android may
require **Allow restricted settings** before enabling the Accessibility Service
for a sideloaded app.

Treat task prompts, Telegram credentials, and AI-provider keys as sensitive.
The current settings storage uses local preferences. Configure sender allowlists
for Telegram and Firebase rules/device pairing before enabling remote control.

## Project layout

- `lib/main.dart` — application entry and Firebase initialization.
- `lib/screens/home_screen.dart` — chat/Agent UI and service startup.
- `lib/screens/beatrice_voice_screen.dart` — embedded Beatrice Voice page.
- `lib/services/action_handler.dart` — action dispatch and task execution.
- `lib/services/task_executor.dart` — multi-step mobile-use loop.
- `lib/services/firebase_task_bridge.dart` — Firebase task claim/status bridge.
- `lib/services/screen_automation_service.dart` — Dart accessibility bridge.
- `android/app/src/main/kotlin/ai/eburon/beatrice/` — Android accessibility
  service and MethodChannel implementation.

## Current limitations

- The Firebase bridge needs production database rules and device pairing.
- Beatrice Voice must be deployed and tested at its production URL.
- End-to-end task dispatch, microphone WebView permissions, and background
  operation require physical-device testing.
- Wake-word activation is planned but is not implemented. It will require an
  on-device wake-word engine and Android foreground service.
