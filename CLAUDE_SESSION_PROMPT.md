# Claude Code Kickoff Prompt (Arrival UK)

Use this repository as the only source of truth:
`/Users/abdulhannan/Desktop/arrival uk`

Read this first:
1. `/Users/abdulhannan/Desktop/arrival uk/CLAUDE_PROJECT_BRIEF.md`
2. `/Users/abdulhannan/Desktop/arrival uk/ARCHITECTURE_DECISIONS.md`
3. `/Users/abdulhannan/Desktop/arrival uk/DEVELOPER_HANDOFF.md`
4. `/Users/abdulhannan/Desktop/arrival uk/CODEBASE_MAP.md`

## Mission
Preserve all current progress and improve production readiness with zero regression and zero data loss.

## Non-Negotiable Rules
1. Do not delete, overwrite, or revert prior work unless explicitly requested.
2. Preserve current behavior and UX unless a change is directly requested.
3. Work in small, auditable batches and validate each batch before moving on.
4. Never do broad rewrites when targeted fixes are possible.
5. Keep architecture extensible for future Android parity, chat/groups/community features.
6. Report findings with exact file and line references.

## Workflow
1. Baseline
- Run and record:
  - `git status --short --branch`
  - `bash /Users/abdulhannan/Desktop/arrival uk/Scripts/line_counts.sh`

2. Audit First (No Code Changes Yet)
- Produce:
  - `/Users/abdulhannan/Desktop/arrival uk/REPORT_AUDIT.md`
  - `/Users/abdulhannan/Desktop/arrival uk/REPORT_BACKLOG.csv`
  - `/Users/abdulhannan/Desktop/arrival uk/REPORT_EXEC_SUMMARY.md`
- Rank issues as `Critical`, `High`, `Medium`, `Low`.
- For each issue include:
  - exact `file:line`
  - root cause
  - impact
  - concrete fix
  - regression risk

3. Fix in Controlled Batches
- Batch order:
  - Batch 1: Critical
  - Batch 2: High
  - Batch 3: Medium (high-value only)
- After each batch:
  - list changed files
  - explain why each change is safe
  - run validations

4. Required Validations Per Batch
- Content validation:
  - `swift /Users/abdulhannan/Desktop/arrival uk/Scripts/validate_content.swift`
- iOS build:
  - `xcodebuild -project "/Users/abdulhannan/Desktop/arrival uk/arrival uk.xcodeproj" -scheme "arrival uk" -destination "platform=iOS Simulator,name=iPhone 15" CODE_SIGNING_ALLOWED=NO build`
- Smoke:
  - `bash /Users/abdulhannan/Desktop/arrival uk/Scripts/strict_smoke.sh`
- Backend (when backend files change):
  - `cd "/Users/abdulhannan/Desktop/arrival uk/backend/functions" && npm run lint && npm run build`

## Collaboration Safety
1. Assume another coding agent may also be active in this repo.
2. Before editing, re-check `git status`.
3. If unexpected unrelated edits appear in files you are about to modify, stop and report conflict risk.
4. Commit small logical units with clear messages.

## Priority Focus Areas
1. Security hardening and policy correctness.
2. Stability and startup reliability.
3. Performance bottlenecks and scalability.
4. Maintainability, modularity, and code clarity.
5. Preserve visual/interaction consistency on Home + Category Detail flows.

## Deliverables
1. `/Users/abdulhannan/Desktop/arrival uk/REPORT_FINAL_CHANGES.md`
2. `/Users/abdulhannan/Desktop/arrival uk/REPORT_TEST_RESULTS.md`
3. `/Users/abdulhannan/Desktop/arrival uk/REPORT_NEXT_STEPS.md`

## Acceptance Criteria
1. App builds successfully on iPhone 15 simulator.
2. No functional regression in existing task/category/profile flows.
3. No data/progress loss.
4. No newly introduced auth/privacy vulnerabilities.
5. All changes are documented and test-verified.

