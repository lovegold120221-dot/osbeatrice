# Beatrice Voice

Beatrice Voice is the web-based conversational and real-time voice interface
for OSBeatrice. It is a Next.js application that uses Gemini Live for spoken
conversation and can hand confirmed mobile tasks to the separate Flutter
private-agent through Firebase Realtime Database.

It is intended to deploy at `https://beatrice.eburon.ai` and be embedded inside
the Android private-agent application as a full-screen native WebView page.

## Features

- Gemini Live native-audio conversation with input/output transcription.
- Typed chat routed through the active Live session.
- Browser microphone capture, voice activity detection, PCM streaming, and Web
  Audio playback.
- Push-to-talk transcription mode, text-to-speech, image analysis/editing, and
  Gemini or Flux image generation.
- Firebase email/password and Google authentication.
- Firebase Realtime Database chat history and Cloud Storage image persistence.
- User context, response-style, theme, chat history, attachments, and a
  mobile-first conversational UI.
- Function declarations for calculator, calendar demo data, and mobile task
  dispatch.
- Live function-call handling and Firebase status updates for device tasks.

## Beatrice and private-agent

Beatrice Voice is the **conversation and planning plane**. The Flutter
private-agent is the **phone execution plane**.

```text
User ↔ Beatrice Voice / Gemini Live
             │
             ├── confirms a proposed task
             │
             ▼
Firebase: deviceTasks/{deviceId}/{taskId}
             │
             ▼
Flutter private-agent → ActionHandler → TaskExecutor → Accessibility Service
             │
             └── progress, done, or failed status
                         │
                         ▼
               Beatrice Voice speaks truthful updates
```

The browser writes only high-level confirmed goals. It does not run Android
commands. The private-agent claims and executes the task locally, then reports
status. Before production use, add Firebase security rules and user-to-device
pairing; the current bridge is not an authorization substitute.

## Setup

### Prerequisites

- Node.js and npm.
- A Gemini API key.
- Firebase configuration for authentication, Realtime Database, and storage.
- A paired private-agent device for mobile task execution.

### Local development

```bash
npm install
cp .env.example .env.local
npm run dev
```

Set at least `GEMINI_API_KEY` in `.env.local`. Firebase values can be supplied
through the documented `NEXT_PUBLIC_FIREBASE_*` environment variables.

### Validation

```bash
npm run lint
npm run build
```

## Deployment

Deploy the Next.js app to Vercel, configure the production environment
variables, and map `beatrice.eburon.ai` to the deployment. Verify microphone
permission, Gemini Live connection, Firebase sign-in, task dispatch, and task
status return from a physical Android device before relying on it.

## Project layout

- `src/app/page.tsx` — single-page chat, Live voice, UI state, and task status
  subscription.
- `src/services/gemini.ts` — Gemini chat, media, text-to-speech, transcription,
  and Gemini Live connection.
- `src/services/tools.ts` — tool declarations and Firebase mobile-task enqueue.
- `src/services/ollama.ts` — optional Ollama streaming fallback.
- `src/services/flux.ts` — Flux image generation integration.
- `src/lib/firebase.ts` — Firebase initialization.

## Current limitations

- Production deployment at `beatrice.eburon.ai` has not been verified by this
  repository alone.
- The Firebase task queue requires secure database rules and device pairing.
- Device task execution, microphone access inside Android WebView, and
  interruption/background behavior require physical-device smoke testing.
- Wake-word activation belongs to the Flutter app and is planned separately.
