# Release Gates

Last updated: 2026-02-11

A build is release-candidate eligible only if all gates are green.

Fast path command:

- `bash Scripts/release_gate_check.sh`
- Optional legal host override for staging: `ARRIVAL_LEGAL_BASE_URL=https://staging.arrivaluk.app bash Scripts/release_gate_check.sh`
- Optional remote config override for fallback validation: `ARRIVAL_REMOTE_CONFIG_URL=https://staging-api.arrivaluk.app/config.json bash Scripts/release_gate_check.sh`

## Gate A: Source Integrity

- Content payload validation passes.
- No insecure patterns blocked by `Scripts/quality_gate.sh`.

## Gate B: iOS Build Quality

- `xcodebuild ... build` passes on iPhone 15 simulator.
- `xcodebuild ... analyze` passes.
- `Scripts/strict_smoke.sh` passes.
- Crash symbolication wiring is valid:
  - `bash Scripts/verify_crash_symbolication.sh`

## Gate C: Backend Quality

- `npm run lint`
- `npm run build`
- `npm test`
- `npm audit --omit=dev`

All must pass.

## Gate D: Security and Privacy

- No open P0/P1 security findings.
- Secrets not committed.
- URL/network trust policies unchanged or reviewed.
- Store privacy disclosures still accurate.
- Legal pages are reachable with 2xx/3xx responses:
  - `bash Scripts/verify_legal_urls.sh`
- Remote config has a valid local fallback contract (network-safe startup path):
  - `bash Scripts/verify_remote_config_fallback.sh`

## Gate E: Regression Sanity

Manual critical path check (latest RC build):

1. Home screen renders and scrolls smoothly.
2. Category opens/closes correctly.
3. Task toggle persists.
4. Add personal task works.
5. Profile sheet open/save/logout works.
6. External source links open via policy-compliant flow.

## Gate F: Release Metadata

- Version + build number updated.
- Release notes drafted.
- Rollback plan identified.

## Gate Status Template

- A: PASS/FAIL
- B: PASS/FAIL
- C: PASS/FAIL
- D: PASS/FAIL
- E: PASS/FAIL
- F: PASS/FAIL

Release allowed only when all are PASS.
