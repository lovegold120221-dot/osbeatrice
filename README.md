# OSBeatrice

OSBeatrice is a split-stack voice-operated computer assistant:

- **Beatrice-Voice** — Next.js web app that acts as the conversational
  orchestrator. It runs in a browser and, when embedded, inside the Android
  private-agent via a WebView at `https://osbeatrice.vercel.app/`.
- **private-agent** — Flutter Android app that acts as the deterministic
  device-execution plane. It owns the install-scoped agent identity and runs
  tasks on the phone.

**Important:** Beatrice Voice is not becoming a separate app. The embedded
WebView URL architecture is preserved. The refactor changes the orchestration
contract underneath the WebView, not the UI delivery model.

The two apps coordinate through **Firebase Realtime Database**, not through
arbitrary model-generated commands.

```mermaid
flowchart TB
    subgraph User["User"]
        U["Voice / text intent"]
    end

    subgraph Flutter["Flutter private-agent"]
        BVScreen["BeatriceVoiceScreen"]
        WebView["Embedded WebView"]
        Identity["AgentIdentityService"]
        Profile["DeviceProfileService"]
        Runner["SkillRunner / ActionHandler"]
        Adapter["Device/App Adapter"]
        Verifier["Verifier"]
    end

    subgraph Shared["Shared Firebase state"]
        Bindings["webSessionBindings/{uid}"]
        Profiles["agentProfiles/{agentId}"]
        Pairs["devicePairs/{agentId}"]
        Queue["deviceTasks/{agentId}/{taskId}"]
        Conv["conversations/{ownerUid}/{conversationId}"]
    end

    subgraph Phone["Android OS"]
        Accessibility["Accessibility Service"]
        Apps["Target app / system UI"]
    end

    U -->|"opens"| BVScreen
    BVScreen -->|"hosts"| WebView
    WebView -->|"loads"| BV["Beatrice Voice URL\nNext.js + Gemini Live"]
    BV -->|"choose known skill + parameters"| Skills["Known Skill Registry"]
    BV -->|"device.webSession binds session"| Bindings
    BV -->|"enqueue structured skill invocation"| Queue
    Bindings -->|"authorizes"| Conv
    Profiles -->|"owns"| Identity
    Pairs -->|"pairs"| Identity
    Queue -->|"claims atomically"| Runner
    Identity -->|"provides agentId"| Runner
    Profile -->|"selects adapter"| Adapter
    Runner -->|"execute known workflow"| Adapter
    Adapter -->|"primitive actions"| Accessibility
    Accessibility -->|"tap/type/scroll/etc"| Apps
    Apps -->|"state / screenshot"| Verifier
    Verifier -->|"verified result / evidence"| Conv
    Conv -->|"truthful status"| BV
```

## Architecture rule

> Beatrice may choose a registered skill. The agent may execute a registered
> workflow. Neither may invent an execution path.
>
> No verifier evidence, no “done.”

## Repository layout

```
.
├── Beatrice-Voice/    # Next.js 16 web app
│   ├── src/app/        # page.tsx, task_api/route.ts
│   ├── src/services/  # gemini.ts, tools.ts, ollama.ts, flux.ts
│   └── README.md       # Web app details
└── private-agent/      # Flutter Android executor
    ├── lib/            # Dart UI and services
    ├── android/        # Kotlin native accessibility bridge
    └── README.md       # Android app details
```

## Current migration status

Phase 1 of the structured-skill migration is complete:

- Canonical `agentId` with legacy `deviceId` migration
- Device profile capture via native MethodChannel
- Atomic four-record pairing handshake
- WebView `task.create` removed; all execution through Firebase queue
- `/task_api` bound to `agentProfiles/{agentId}/ownerUid`

Beatrice Voice remains the **embedded WebView URL**, not a separate app.

See `private-agent/ROADMAP.md` and
`Beatrice-Voice/src/services/SKILL_PROTOCOL_NOTES.md` for the full plan.
