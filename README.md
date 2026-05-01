# Hermes App

A minimalist Flutter client (Android · iOS · Web) for piloting your own self-hosted [**Hermes Agent**](https://github.com/NousResearch/Hermes-Agent) instance — chat, history, and cron jobs from your phone, without going through Telegram, Slack, or Discord.

> Hermes Agent is an autonomous LLM agent runtime by Nous Research. This app is a personal-use client only — bring your own server, bring your own Bearer token.

```
┌────────────────────┐
│   Your device      │  Android · iOS · Web
└─────────┬──────────┘
          │ HTTPS + Bearer token
          ▼
┌────────────────────┐
│   Hermes Agent     │  /v1/runs (SSE) · /api/jobs · /v1/chat/completions
└────────────────────┘
```

## Stack

- Flutter 3.41 · Dart 3
- [Riverpod](https://riverpod.dev/) — state management
- [go_router](https://pub.dev/packages/go_router) — navigation with `StatefulShellRoute`
- [Dio](https://pub.dev/packages/dio) — HTTP client (with native SSE on mobile)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) — Bearer token kept off-disk
- [shared_preferences](https://pub.dev/packages/shared_preferences) — local sessions index
- [gpt_markdown](https://pub.dev/packages/gpt_markdown) + [flutter_highlight](https://pub.dev/packages/flutter_highlight) — markdown rendering with IDE-style code blocks
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) — system notifications on job completion
- [fuzzywuzzy](https://pub.dev/packages/fuzzywuzzy) — typo-tolerant search across history

## Features

- **Chat** with real-time SSE streaming, tool progress events, code blocks, copy buttons, stop button
- **History** of past sessions stored locally (Hermes Agent doesn't expose a list endpoint), with fuzzy search and resume
- **Jobs** (cron) full CRUD: create, edit, pause, resume, run now, delete — with sparkline of recent runs
- **Smart polling** schedules a one-shot timer until `next_run_at`, then 5 s polling, stops on the first observed change — no needless requests
- **Notifications** on job completion: native on Android/iOS/macOS, in-app toast on Web
- **Persistent chat state** across reloads via local session store
- **Single-color minimalist** dark UI (indigo accent, surfaces from `#0B0C0F` to `#22262E`)

## Architecture

```
lib/
├── main.dart                    Entry point, theme, splash gating
├── router.dart                  GoRouter + StatefulShellRoute (bottom nav)
├── providers.dart               Riverpod (settings, chat, sessions, jobs)
├── config/constants.dart        Compile-time URL + path constants
├── services/
│   ├── hermes_service.dart      Dio client, Runs API, jobs CRUD, SSE
│   ├── session_store.dart       LocalSession persistence (shared_preferences)
│   ├── notifications.dart       Cross-platform notifications (toast on web)
│   ├── sse.dart                 Conditional SSE client (Dio native / dart:html web)
│   ├── sse_web.dart             dart:html HttpRequest streaming
│   └── sse_web_stub.dart        Stub for non-web compile
├── theme/
│   ├── tokens.dart              Color/spacing/radii tokens
│   └── text_styles.dart         Typography scale
├── widgets/                     hermes_logo, status_dot, composer,
│                                message_bubble, code_block, copy_button,
│                                sparkline, bottom_nav, animated_splash
└── screens/                     setup, chat, history, jobs, job_form_sheet
```

## Configuration

The app embeds **no URL and no key**. Both are provided either at build time (default URL via `--dart-define`) or at runtime (user enters them in the Setup screen, stored in the platform keychain).

### Default base URL (optional)

Pre-fill the Setup screen with your instance URL using a build-time constant:

```bash
flutter run -d chrome --dart-define=HERMES_DEFAULT_BASE_URL=https://your-hermes-instance.com
```

For convenience, copy `.env.example` to `.env` (gitignored) and use the helper script:

```bash
cp .env.example .env
# Edit .env with your URL
./run.sh chrome
```

### Bearer token

Never read from a file or env var — entered once in the Setup screen and stored via `flutter_secure_storage`:
- iOS / macOS: Keychain
- Android: EncryptedSharedPreferences (AES-256 via Tink)
- Web: IndexedDB encrypted with SubtleCrypto

## Building & running

```bash
flutter pub get
flutter analyze
flutter test

# Web
flutter run -d chrome --dart-define=HERMES_DEFAULT_BASE_URL=https://your-hermes-instance.com
flutter run -d web-server --web-port 8080 --dart-define=HERMES_DEFAULT_BASE_URL=https://your-hermes-instance.com

# iOS
flutter run -d "iPhone"        # simulator
flutter run -d "<UDID>"        # real device (Xcode signing required)

# Android
flutter emulators --launch <id>
flutter run -d <emulator-id>

# Release builds
flutter build web --dart-define=HERMES_DEFAULT_BASE_URL=https://your-hermes-instance.com
flutter build apk --release --dart-define=HERMES_DEFAULT_BASE_URL=https://your-hermes-instance.com
flutter build ios --dart-define=HERMES_DEFAULT_BASE_URL=https://your-hermes-instance.com
```

## Hermes Agent server requirements

The app talks to whatever endpoint you point it at — but your Hermes Agent server needs to:

1. **Accept Bearer auth** on `/v1/runs`, `/v1/chat/completions`, `/api/jobs/*`
2. **Send these headers in responses** so the browser JS can use them:
   - `Access-Control-Allow-Origin` — set to your app origin or `*`
   - `Access-Control-Expose-Headers` — must include `x-hermes-session-id`
   - `Access-Control-Allow-Headers` — must include `Authorization`, `Content-Type`, `Accept`, `X-Hermes-Session-Id`
   - `Access-Control-Allow-Methods` — `GET, POST, PATCH, DELETE, OPTIONS`

These CORS headers are **only needed for the Web build** (mobile platforms don't enforce CORS). If you serve Hermes behind a reverse proxy, add the headers there. Example for Traefik (skip if you're not using Traefik):

```yaml
labels:
  - "traefik.http.middlewares.hermes-cors.headers.accesscontrolalloworiginlist=*"
  - "traefik.http.middlewares.hermes-cors.headers.accesscontrolallowmethods=GET,POST,PATCH,DELETE,OPTIONS"
  - "traefik.http.middlewares.hermes-cors.headers.accesscontrolallowheaders=Authorization,Content-Type,Accept,X-Hermes-Session-Id"
  - "traefik.http.middlewares.hermes-cors.headers.accesscontrolexposeheaders=Content-Type,x-hermes-session-id"
  - "traefik.http.routers.hermes.middlewares=hermes-cors@docker"
```

For Nginx, Caddy, or another proxy, the same headers apply — adapt to your config. If you're running Hermes Agent directly without a proxy, configure CORS in the Hermes server itself.

## Endpoints used

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Smoke test |
| `POST` | `/v1/runs` | Submit an agent run (returns `run_id`) |
| `GET` | `/v1/runs/{run_id}/events` | SSE stream of run events |
| `POST` | `/v1/runs/{run_id}/stop` | Cancel a running run |
| `POST` | `/v1/chat/completions` | Legacy OpenAI-compatible (fallback / kept for compat) |
| `GET` | `/api/jobs` | List jobs |
| `POST` | `/api/jobs` | Create job |
| `GET` | `/api/jobs/{id}` | Job details |
| `PATCH` | `/api/jobs/{id}` | Update job |
| `DELETE` | `/api/jobs/{id}` | Delete job |
| `POST` | `/api/jobs/{id}/run` | Trigger now |
| `POST` | `/api/jobs/{id}/pause` | Pause |
| `POST` | `/api/jobs/{id}/resume` | Resume |

The session continuity header `X-Hermes-Session-Id` is sent on subsequent runs to continue the same conversation context.

## Personal use disclaimer

This is a **personal-use** client. There is no multi-user mode, no auth flow beyond a single Bearer, no team/role model, no sync between devices. Each device has its own local session index. If you need multi-tenant or shared state, this app is not what you want.

## License

MIT — do whatever you want with it.
