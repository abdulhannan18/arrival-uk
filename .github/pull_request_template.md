## Summary

- What changed:
- Why:
- Risk level: Low / Medium / High

## Change Type

- [ ] Feature
- [ ] Security hardening
- [ ] Refactor
- [ ] Bug fix
- [ ] Data/schema/content update
- [ ] CI/ops

## Architecture Contract

- [ ] Change respects `/Users/abdulhannan/Desktop/arrival uk/ARCHITECTURE_CONTRACT.md`
- [ ] No cross-layer shortcut introduced
- [ ] If boundary exception exists, documented in PR

## Validation

- [ ] `bash Scripts/quality_gate.sh`
- [ ] `swift Scripts/validate_content.swift` (if content touched)
- [ ] `xcodebuild ... build` (iOS)
- [ ] `xcodebuild ... analyze` (iOS)
- [ ] `./Scripts/strict_smoke.sh` (iOS)
- [ ] `npm run lint && npm run build && npm test` (backend if touched)
- [ ] `npm audit --omit=dev` (backend if touched)

## Security/Privacy

- [ ] Checked `/Users/abdulhannan/Desktop/arrival uk/SECURITY_BASELINE.md`
- [ ] Checked `/Users/abdulhannan/Desktop/arrival uk/PRIVACY_COMPLIANCE.md`
- [ ] No secrets/tokens in source or logs
- [ ] No new P0/P1 risk introduced

## Release Gates

- [ ] This PR keeps `/Users/abdulhannan/Desktop/arrival uk/RELEASE_GATES.md` passable

## Rollback Plan

- How to revert if needed:

