# Sportify App — v0 Foundation (Scaffold) Design

**Status:** Draft — awaiting review
**Date:** 2026-07-05
**Owner:** Valentín Villa
**Scope:** Client scaffold only. No product features. No backend.

---

## 1. Purpose

Establish the **foundation** for the **Sportify App** — the player-facing mobile client — as a
runnable, testable, buildable skeleton. This spec covers *only* that skeleton. It deliberately
contains **no product features**; the actual v0 feature set is pending player/venue interviews and
will be specced separately, then slot into this skeleton **without rework**.

Strategic frame: the v0 app is the **soft-launch beachhead** (thesis Ch. 1, *Barrera 4 — Tasa de
Adopción*). Its job is to capture early players/venues/accounts *before* matchmaking exists. This
foundation is the vessel for whatever minimal-but-genuinely-useful feature set the research yields.

## 2. Scope

**In scope (this spec):**

- An Expo + React Native + TypeScript project at `sportify-app/`.
- Navigation shell (Expo Router) with a single placeholder route.
- A **data-layer seam**: repository interface pattern + one in-memory example, so features can add
  persistence later behind a stable boundary (see §5).
- Tooling: format, lint, typecheck, unit/component tests, E2E harness configuration.
- EAS configuration (Update / Build / Submit) — **configured, not executed** today.
- Running on **iOS via Expo Go on a physical device**.
- CI: GitHub Actions running typecheck + lint + test on PRs.

**Out of scope (deferred, deliberately):**

- Any product screen or feature beyond the placeholder route — *pending interviews*.
- **Backend / persistence** — deferred behind the seam (§5). Likely Supabase when the first feature needs it.
- **Android** emulator/device verification — no Android device available; config is present, verification deferred.
- **Web** — that surface is the Business Administration (BAS) frontend, a separate project.
- **Store submission / production build** — gated on Apple Developer + Google Play enrollment.
- Client state/data-fetching libraries (Zustand, TanStack Query) — added *with the first feature that needs them* (YAGNI).

## 3. Stack (ratified)

| Slot | Choice | Notes |
|------|--------|-------|
| Language | **TypeScript** (`strict: true`) | |
| Framework | **Expo** (managed) + **React Native** | Latest stable SDK |
| Navigation | **Expo Router** | File-based routes under `app/` |
| Package manager | **pnpm** | Requires `.npmrc` with `node-linker=hoisted` for React Native; installed via Corepack (ships with Node) — no global install |
| Format / lint | **Prettier + ESLint** | Expo template config as baseline |
| Unit / component tests | **Jest** + **React Native Testing Library** | via `jest-expo` preset |
| E2E tests | **Maestro** | YAML flows; config present, one smoke flow, run later |
| OTA / build / submit | **EAS Update + EAS Build + EAS Submit** | Configured this session, not executed |
| CI | **GitHub Actions** | typecheck + lint + test on PR |

## 4. Directory layout

New top-level sibling to the pipeline — matches `docs/repo-structure.md`'s `sportify-<subsystem>` convention and touches nothing in the Python pipeline:

```
sportify/
├── sportify-game-reconstruction/    # existing — untouched
└── sportify-app/                     # NEW
    ├── app/                          # Expo Router routes
    │   ├── _layout.tsx               # root layout
    │   └── index.tsx                 # placeholder landing screen
    ├── src/
    │   └── data/                     # the data-layer seam (§5)
    │       ├── types.ts              # domain types
    │       ├── repositories.ts       # repository interfaces
    │       └── memory/               # in-memory implementations
    │           └── app-info.memory.ts
    ├── components/                   # shared UI (empty for now)
    ├── __tests__/                    # Jest unit/component tests
    ├── .maestro/                     # E2E flows (one smoke flow)
    ├── assets/                       # icons/splash (Expo defaults)
    ├── app.config.ts                 # Expo app config (IDs, EAS)
    ├── eas.json                      # EAS build/submit/update profiles
    ├── package.json
    ├── tsconfig.json
    ├── .npmrc                         # node-linker=hoisted (RN + pnpm)
    ├── .gitignore                    # Expo-generated (node_modules, .expo, etc.)
    └── README.md
```

Isolation: `sportify-app/` has its own `package.json`, its own `node_modules` (git-ignored by the
app-local `.gitignore`), and its own toolchain. The root Python `.gitignore` is **not** modified.

## 5. Data-layer seam

The one architectural element that makes backend-deferral safe. Features never call a backend
directly; they depend on **repository interfaces**. v0 ships an **in-memory implementation**, so the
app runs and tests end-to-end today with zero backend. When the first researched feature needs
persistence, we add a second implementation (e.g. Supabase) behind the same interface — consumers do
not change.

```ts
// src/data/repositories.ts
export interface AppInfoRepository {
  getReleaseChannel(): Promise<string>;   // illustrative; proves the pattern
}

// src/data/memory/app-info.memory.ts
export class InMemoryAppInfoRepository implements AppInfoRepository {
  async getReleaseChannel() { return "development"; }
}
```

`AppInfoRepository` is a **placeholder to demonstrate the seam** and give the first component test
something real to render. It will be replaced by real repositories (players, venues, …) once
features are defined. No feature logic lives here in v0.

## 6. Tooling & scripts

`package.json` scripts (run via `pnpm`):

| Script | Command | Purpose |
|--------|---------|---------|
| `start` | `expo start` | Dev server + QR for Expo Go |
| `ios` | `expo start --ios` | (later, needs macOS/EAS) |
| `typecheck` | `tsc --noEmit` | Strict TS check |
| `lint` | `eslint .` | Lint |
| `format` | `prettier --write .` | Format |
| `test` | `jest` | Unit/component |
| `test:e2e` | `maestro test .maestro/` | E2E (run later on device) |

## 7. Release pipeline (EAS) — configured, not executed

- **Identity:** slug `sportify-app`; iOS bundle id + Android package `com.implacables.sportify`.
- **`eas.json` profiles:** `development`, `preview`, `production`.
- **EAS Update channels** aligned to those profiles — this is the "self-updatable" mechanism (OTA JS/asset updates without store re-review).
- **Today:** running in **Expo Go does not require any EAS build** — `expo start` → scan QR → runs on
  the phone. EAS config is prepared for later dev/preview/production builds and OTA. **No cloud build
  is triggered this session.**

## 8. Environment & prerequisites

| Prerequisite | Status | Action |
|--------------|--------|--------|
| Node | ✅ present | — |
| pnpm | via Corepack | `corepack enable pnpm` — no separate global install |
| Expo Go on phone (iOS) | ✅ present | run target for today |
| Expo account | needed for EAS | free signup |
| EAS CLI (`eas-cli`) | to install | `pnpm add -g eas-cli` (or `pnpm dlx eas-cli`) when we reach EAS config |
| Apple Developer Program ($99/yr) | **async** | enroll today — approval can take days |
| Google Play Console ($25 once) | **async** | enroll when Android work starts |

## 9. Testing strategy

- **Unit/component (Jest + RNTL):** in v0, a **render smoke test** of the placeholder screen, plus a
  test of `InMemoryAppInfoRepository`. Proves the harness and the seam work.
- **E2E (Maestro):** one smoke flow committed (`app launches, landing screen visible`); executed on a
  device later, not required to be green in CI today.
- **Typecheck + lint** run in CI and locally.

## 10. CI

GitHub Actions workflow (`.github/workflows/app-ci.yml`) triggered on PRs touching `sportify-app/`:
`pnpm/action-setup` + `setup-node` (cache: pnpm) → `pnpm install --frozen-lockfile` → `typecheck` → `lint` → `test`. E2E and EAS builds are **not** in CI yet.

## 11. Acceptance criteria — scaffold is "done" when

1. `sportify-app/` exists with the layout in §4.
2. `pnpm start` serves; the app **opens in Expo Go on the phone** and shows the placeholder screen.
3. `pnpm typecheck` passes (strict).
4. `pnpm lint` passes.
5. `pnpm test` passes (render smoke test + repository test, both green).
6. `.maestro/` smoke flow and `eas.json` + `app.config.ts` are present and valid (not executed).
7. `.github/workflows/app-ci.yml` present.
8. Nothing under `sportify-game-reconstruction/`, root `scripts/`, or root `.gitignore` is modified.

## 12. Isolation guarantees

- Separate `package.json` / `node_modules` / toolchain under `sportify-app/`.
- App-local `.gitignore` (Expo-generated) handles Node artifacts; **root `.gitignore` untouched**.
- No interaction with the Python pipeline, `SPORTIFY_DATA_ROOT`, or `scripts/sportify-env.sh`.
- Lands via a `feature/sportify-app-scaffold` branch per `docs/branching-strategy.md`.

## 13. Decisions & remaining notes

- **Package manager:** pnpm (resolved — §3).
- **App display name:** "Sportify" (resolved).
- **Bundle/package id:** `com.implacables.sportify` as a **working default**. Freely changeable
  until the first store submission (nothing is published yet); **lock before submitting**. Revisit if
  a company domain is registered (would prefer `com.<domain>.sportify`).
