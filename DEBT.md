# Technical Debt

## Legacy iOS quality-gate baseline
- Gap: Several existing Swift files already exceed the default 1200 LOC maintainability ceiling, and a small set of legacy force unwraps already exists in regional runtime and horizon view code.
- Risk: These areas remain harder to review and more crash-prone than the remediated P0/P1 modules, even though this pass prevents further regression.
- Owner: App engineering

## Local Firestore emulator verification environment
- Gap: Local Firestore rules tests require a working JDK, and this Mac currently has no usable Java runtime, so the emulator-backed rules suite cannot complete locally in this pass.
- Risk: Firestore authorization regression proof is currently CI-backed rather than fully reproducible on this machine until Java is installed.
- Owner: Dev tooling

## Full local iOS sanitizer verification
- Gap: The targeted iOS suites compile cleanly, but this machine's simulator/runtime layer is still unstable enough to block a clean full XCTest + sanitizer sweep in this pass.
- Risk: Remaining runtime-only race or install/boot issues may not surface until CI or the next stabilized local simulator run.
- Owner: App engineering

## EMAIL DIGEST IDEMPOTENCY — DB CONSTRAINT GAP

**File:** backend/functions/src/email.ts lines 333-354
**Risk:** Weekly digest deduplication is enforced via a Firestore transaction on a deterministic reservation document. This provides application-level atomicity within a single transaction, but Firestore has no unique-constraint primitive. A bug in the reservation path, a direct Firestore admin write, or a future code change bypassing the transaction could send duplicate digests to users.
**Mitigation in place:** Deterministic document ID + Firestore transaction makes concurrent duplicates extremely unlikely under normal operation.
**Remaining risk:** Not protected against out-of-band writes or transaction bypass.
**Owner:** Backend
**Recommended resolution:** If migrating to a SQL-backed store in future, add a true unique constraint on (userId, emailType, isoWeek, year). Until then, any change to the digest send path must be reviewed against this constraint gap.
