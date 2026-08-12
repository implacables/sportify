# Sportify App — Your Action Items (human-only)

These are the things **only you** can do. None of them block the automated scaffold work.
Last updated: 2026-07-05.

## Now (quick, ~2 min) — the boot check
- [ ] Confirm the app runs on your phone:
  ```bash
  cd /home/valen/Documents/sportify/sportify-app
  pnpm start
  ```
  Scan the QR with your iPhone Camera (opens Expo Go). Phone + computer on the **same Wi-Fi**.
  Expected: a centered **"Sportify / Coming soon"** screen.
  - If Expo Go says *"unsupported SDK"* → update Expo Go from the App Store (we're on the new SDK 57).
  - Tell Claude what you see (success or the exact error).

## Soon (async, no rush) — accounts
- [ ] Create a free **Expo account** at https://expo.dev — needed later for EAS builds + OTA updates.
- [ ] Enroll in the **Apple Developer Program** ($99/yr) at https://developer.apple.com/programs/ —
      approval can take **days**, so start early. Needed before any iOS App Store submission.

## Later (not urgent)
- [ ] **Google Play Console** ($25 one-time) — only when Android work starts (you have no Android device yet).
- [ ] Lock the app **bundle id** (`com.implacables.sportify`) before the first store submission.
      It's freely changeable until then; fine as-is for now.

---
*Nothing here blocks Claude's current work. The scaffold (spec + plan) lives in
`docs/superpowers/specs/` and `docs/superpowers/plans/`.*
