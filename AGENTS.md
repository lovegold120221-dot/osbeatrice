# Repository Guidelines

This repository contains two sibling apps that make up the OSBeatrice stack:

- **Beatrice-Voice** — Next.js 16 web app: conversational voice assistant with Gemini Live, image/TTS, and Firebase persistence.
- **private-agent** — Flutter Android executor: device automation, screen accessibility events, AI provider settings, and task execution bridge.

Each subproject has its own `AGENTS.md` with deeper architecture and quirk details (`Beatrice-Voice/AGENTS.md`, `private-agent/AGENTS.md`). Treat this document as the contributor entry point.

## Project Structure & Module Organization

```
.
├── Beatrice-Voice/          # Next.js web app
│   ├── src/
│   │   ├── app/               # page.tsx, layout.tsx, globals.css
│   │   ├── lib/               # Firebase client singleton
│   │   └── services/          # gemini.ts, ollama.ts, flux.ts, tools.ts
│   ├── public/                # Static assets
│   ├── package.json           # npm scripts and dependencies
│   └── .env.example           # Required env template
└── private-agent/             # Flutter Android app
    ├── lib/                   # Dart source and UI
    ├── android/               # Kotlin native code
    ├── local_plugins/         # Vendored flutter_overlay_window
    ├── test/                  # Flutter widget/unit tests
    ├── assets/                # Images and local config
    ├── pubspec.yaml           # Flutter dependencies
    └── AGENTS.md              # Android-specific quirks
```

Root-level files (`README.md`, `.gitignore`) are minimal. All source, tests, and assets live inside the two app folders.

## Build, Test, and Development Commands

### Beatrice-Voice

```bash
cd Beatrice-Voice
npm install          # Install dependencies
npm run dev          # Start dev server on port 3000 (0.0.0.0)
npm run build        # Production build via next build
npm run start        # Start production server
npm run lint         # Type-check via tsc --noEmit
```

Copy `.env.example` to `.env.local` and set `GEMINI_API_KEY` at minimum.

### private-agent

```bash
cd private-agent
flutter pub get                # Install dependencies
flutter analyze                # Static analysis
flutter test                   # Run widget/unit tests
flutter build apk --release    # Build release APK
```

Android builds require a configured Flutter/Android toolchain. The vendored `local_plugins/flutter_overlay_window` is wired through a path override in `pubspec.yaml`.

## Coding Style & Naming Conventions

- **Beatrice-Voice** — TypeScript/React. Use the existing project indentation. Run `npm run lint` before opening a PR.
- **private-agent** — Dart/Flutter. Follow `flutter_lints` and `analysis_options.yaml`. Run `flutter analyze` and `flutter test`.
- Prefer descriptive names. Keep the Next.js app in `src/services/` and `src/app/`. Keep Flutter screens/providers/services under `lib/`.
- Do not add new Python or JSONL files; they are globally gitignored in `private-agent`.

## Testing Guidelines

- **Beatrice-Voice**: TypeScript type checks with `tsc --noEmit`. There is no Jest/test suite currently.
- **private-agent**: Uses `flutter_test`. Run `flutter test`. CI in `.github/workflows/android-release.yml` runs this before building.
- `private-agent/test_parse.dart` is an experimental scratch file, not part of the test suite.
- Test files should live in `private-agent/test/` and follow `*_test.dart` naming.

## Commit & Pull Request Guidelines

- Write clear, present-tense commit messages that describe what changed and why.
- Keep PRs scoped to one app when possible; name the app in the PR title (e.g., `[Beatrice-Voice] ...` or `[private-agent] ...`).
- Include the output of `npm run lint`, `flutter analyze`, or `flutter test` if you changed code in that app.
- Do not commit secrets, Firebase configs, or `assets/local_config/ai_test_config.json`.
- This is a brand new repo root with no Git history yet. Establish conventions from the first commit onward.

## Security & Configuration Tips

- **Never embed API keys in source or APKs.** Use `.env.local` for Beatrice-Voice and the bundled-but-gitignored `assets/local_config/ai_test_config.json` only for developer-local Flutter builds.
- For shared Firebase credentials, rely on `NEXT_PUBLIC_FIREBASE_*` env vars in the web app and proper platform configuration in the Flutter app.
- CI builds APKs in debug/signing-only mode; production signing requires a configured keystore and is not automated.

## Agent-Specific Instructions

- When editing code, verify which app is being modified. Do not conflate web app logic with Android executor behavior.
- Preserve existing UI controls (e.g., local dictation in Beatrice-Voice) unless source inspection confirms the target control.
- For Android tasks, refer to `private-agent/AGENTS.md` for native bridge details and known quirks before changing `android/` or `local_plugins/`.
- Report build and runtime status separately: web lint/build, APK build, and physical device behavior are distinct verification steps.

## Architecture Migration

The repository is migrating from free-form LLM-driven Android automation to a
structured skill protocol. Phase 1 (identity, device profile, and secure
owner-agent binding) is implemented. See `private-agent/ROADMAP.md` and
`Beatrice-Voice/src/services/SKILL_PROTOCOL_NOTES.md` for the full plan.
