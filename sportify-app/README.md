# Sportify App

Player-facing mobile client (Expo + React Native + TypeScript, SDK 57). **Foundation scaffold** —
no product features yet; those follow the player/venue interviews. See the
[Foundation spec](../docs/superpowers/specs/2026-07-05-sportify-app-foundation-design.md).

## Prerequisites

- Node 20+ and pnpm via Corepack: `corepack enable pnpm`
- Expo Go on a phone (iOS today; Android deferred)

## Run

```bash
pnpm install
pnpm start        # scan the QR in Expo Go
```

## Check

```bash
pnpm typecheck
pnpm lint
pnpm test
```

## Release pipeline (deferred)

`app.config.ts` + `eas.json` define identity and channels. Online EAS setup
(`eas init`, `eas update:configure`, builds/submits) is not wired yet — it needs an
Expo account and Apple/Google enrollment.

## Data-layer seam

Features depend on interfaces in `src/data/repositories.ts`. v0 ships only in-memory
implementations (`src/data/memory/`). A real backend slots in behind the same interfaces later.

## Project layout

- `src/app/` — Expo Router routes (file-based)
- `src/data/` — repository interfaces + in-memory implementations
- `__tests__/` — Jest unit/component tests
- `.maestro/` — Maestro E2E flow (run on device later)
