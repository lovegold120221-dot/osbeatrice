# OSBeatrice Agent Architecture Roadmap

## Embedded WebView architecture is preserved

Beatrice Voice is **not** becoming a separate app. It stays loaded inside the
Flutter private-agent as the embedded WebView at
`https://osbeatrice.vercel.app/`. The refactor changes the orchestration
contract underneath that WebView, not the UI delivery model.

```text
Flutter private-agent
        │
        ├── BeatriceVoiceScreen
        │
        └── Embedded WebView
                 │
                 ▼
        Beatrice Voice URL
        (existing Next.js app)
                 │
                 ├── voice conversation
                 ├── Gemini Live
                 ├── Beatrice UI
                 └── skill orchestration
```

When the user opens the Beatrice screen, the embedded web app automatically
knows:

- "This is my owner."
- "This is my exact private-agent instance (agentId)."
- "This is our active shared conversation/session."
- "These are the skills this device supports."

Both sides read and write the same Firebase backend for history and status.

## Non-negotiable rule

> Beatrice may choose a registered skill. The agent may execute a registered
> workflow. Neither may invent an execution path.
>
> No verifier evidence, no “done.”

## Phases

### Phase 1 — Identity, profile, and binding ✅

- Canonical `agentId` via `AgentIdentityService` (legacy `deviceId` migration).
- `DeviceProfileService` and native `getDeviceProfile` MethodChannel.
- Atomic four-record pairing handshake in `BeatriceVoiceScreen`.
- Remove direct WebView `task.create`; all execution via Firebase queue.
- Bind `/task_api` to `agentProfiles/{agentId}/ownerUid`.

### Phase 2 — Shared conversation and events

- Firebase `conversations/{ownerUid}/{conversationId}` as source of truth.
- Deterministic skill event vocabulary.

### Phase 3 — Skill protocol

- `SkillManifest`, `SkillInvocation`, `SkillStep`, `Verifier`.
- `SkillRunner` + adapters behind a feature flag.

### Phase 4 — Foundational skills

- `agent.identity.get`, `agent.capabilities.get`
- `app.open`, `screen.read`, `screen.screenshot`
- `system.volume.set`, `system.brightness.set`
- `ui.home`, `ui.back`
- `skill.status.get`, `skill.cancel`

### Phase 5 — Beatrice uses only structured skills

### Phase 6 — Disable legacy `execute_task`

### Phase 7 — Device/app adapters (Samsung, Pixel, generic)
