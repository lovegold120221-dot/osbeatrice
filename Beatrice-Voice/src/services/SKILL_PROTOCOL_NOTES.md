# Skill Protocol Migration Notes

This document tracks the architecture migration described in the OSBeatrice
contributor brief. Phase 1 is implemented; later phases are planned.

## Embedded WebView architecture is preserved

Beatrice Voice remains a **Next.js app loaded inside the Flutter private-agent
via an embedded WebView**. The only change is the contract between the embedded
web app and the native agent.

```text
Flutter private-agent
        │
        ├── BeatriceVoiceScreen
        │
        └── Embedded WebView
                 │
                 ▼
        https://osbeatrice.vercel.app/
                 │
                 ├── voice conversation
                 ├── Gemini Live
                 ├── Beatrice UI
                 └── skill orchestration
```

The WebView bridge still handles:

- `device.ready` — native tells the web app the canonical `agentId` and owner.
- `device.webSession` — web app anonymously signs in and binds its session.
- `device.identity` / `agent.identity` / `agent.capabilities` — native confirms
  ownership and device capabilities.
- `task.cancel` — requests cancellation (handled through the shared queue).
- WebView lifecycle and microphone permission passthrough.

What changed: `task.create` is no longer handled directly by the WebView bridge.
All skill execution is written to the shared Firebase queue so history and
status cannot be bypassed.

## Phase 1 — Identity, Profile, and Binding (implemented)

- `AgentIdentity` + `AgentIdentityService` replace the ad-hoc
  `firebase_task_device_id` with a canonical install-scoped `agentId`.
  Existing installs keep their old id; new installs get a random UUID.
- `DeviceProfile` + `DeviceProfileService` capture the Android device model,
  API level, display metrics, and runtime capabilities via the existing
  `ai.eburon.beatrice/accessibility` MethodChannel.
- `BeatriceVoiceScreen` now sends `device.ready` with `agentId` and responds to
  `device.webSession` by atomically writing:
  - `agentProfiles/{agentId}`
  - `devicePairs/{agentId}`
  - `users/{ownerUid}/devices/{agentId}`
  - `webSessionBindings/{webSessionUid}`
- Direct `task.create` via WebView is removed. All execution flows through
  `deviceTasks/{agentId}` in Firebase Realtime Database.
- `Beatrice-Voice/src/services/tools.ts` verifies both the web session binding
  and the agent profile owner before enqueuing a legacy free-form task.
- `/task_api` now validates that the authenticated Firebase UID owns the
  claimed `agentId` by reading `agentProfiles/{agentId}`.

## Phase 2 — Shared Conversation and Events (planned)

- Retire local chat history in `private-agent` as the authority.
- Create `conversations/{ownerUid}/{conversationId}` and
  `agentInvocations/{agentId}/{invocationId}` as the shared source of truth.
- Replace the current `device task update` text injection with deterministic
  event types: `skill.requested`, `skill.accepted`, `skill.started`,
  `skill.progress`, `skill.awaiting_user`, `skill.verifying`, `skill.succeeded`,
  `skill.failed`, `skill.cancelled`.

## Phase 3 — Skill Protocol and Structured Queue (planned)

- Define `SkillManifest`, `SkillInvocation`, `SkillStep`, and `Verifier` models.
- Add `SkillRunner` in `private-agent` that executes known workflows with
  app/device adapters instead of letting the LLM invent UI paths.
- Queue structured invocations alongside legacy `execute_task` goals, behind a
  feature flag.

## Phase 4–7 (planned)

- Implement foundational skills: `agent.identity.get`, `agent.capabilities.get`,
  `app.open`, `screen.read`, `screen.screenshot`, `system.volume.set`,
  `system.brightness.set`, `ui.home`, `ui.back`, `skill.status.get`,
  `skill.cancel`.
- Add per-skill verifiers; no verifier evidence means no "done".
- Progressively add Samsung/Pixel/app-specific adapters.
- Disable legacy free-form `execute_task` once structured skills are proven.
