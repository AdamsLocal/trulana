# Working Order — Engineering

This GitHub org is where Working Order ships code. The goal is simple: build dependable systems that don't lie (about data, audit trails, or what they did), and can be run and debugged without heroics.

If something here feels vague, fix it. Ambiguity is technical debt.

## What lives here

- **Product repos**: customer-facing apps and services. Trulana is the flagship — a local-first, privacy-by-default personal context server.
- **Core platform**: shared libraries, infra, tooling, CI/CD, and the "Kernel" pieces (encrypted local vault, audit log, auth layer).
- **Prototypes**: experiments that may get promoted or deleted.

If a repo is "important," it must say so in its own README (what it does, how it runs, how it's deployed, who owns it).

## What we build

Working Order builds **local-first, privacy-preserving software** — primarily in Flutter/Dart for desktop and mobile. Products are designed around the principle that the device is the trust boundary: apps get answers, not raw data.

Where AI and agent tooling is involved, we expose context over standard transports (REST, MCP) with on-device redaction before anything leaves the machine. This shapes the security posture of every repo here.

## Non-negotiables (engineering rules)

1. **Reproducible local dev**  
   A new machine should be able to run the system with documented steps and pinned versions. For Dart/Flutter repos, `pubspec.lock` is committed and must match the documented Flutter SDK version.

2. **Deterministic behavior where it matters**  
   Especially for audit logs, evidence exports, and anything compliance-adjacent. Timestamps are UTC. Ordering is explicit. Hash chains are documented.

3. **No secret state**  
   If it affects behavior, it belongs in code, config, or an explicit data store — not a developer's laptop, not an undocumented env var, not a hardcoded default that quietly ships.

4. **Zero PII surface**  
   Never log, print, or emit user context, vault data, prompts, or query content to any log sink. Use `SafeLogger` (or equivalent) exclusively. This applies in tests too. If a log line could contain PII, it should not exist.

5. **Security is default**  
   Least privilege, explicit secrets handling, biometric-gated access where appropriate, and a clear incident path. Encryption at rest is not optional for anything touching user data.

6. **Ship small**  
   Small PRs, fast review, boring releases.

## Getting access

- Ask an org admin for:
  - org membership
  - team membership
  - repo permissions (read/write/admin as needed)
- Use SSO if enabled.
- Use SSH keys (preferred) or fine-grained PATs where required.

## Repo standards (minimum bar)

Every repo must have:

- `README.md` with:
  - what it is
  - how to run locally (with pinned SDK/tool versions)
  - how to test
  - how to deploy (or where deployment is defined)
- `LICENSE` — BUSL-1.1 for commercial products, or an explicit proprietary statement. Open-source components should use MIT or Apache 2.0.
- `CODEOWNERS` (single owner is fine; "nobody" is not)
- CI checks that run on PRs (lint + analyze + tests at minimum)
- A place for operational notes: `docs/` or `/runbook`

Recommended:

- `CONTRIBUTING.md` — especially the "where the project stands" and "what to work on next" sections
- `SECURITY.md` — threat model, trust boundaries, acceptable risks
- `CHANGELOG.md` (or release notes via tags)
- `.cursorrules` or equivalent — full style guide and AI assistant conventions for the repo

## Branching + PR workflow

Default branch: `main`

- Feature work:
  - `feat/<short-name>`
  - `fix/<short-name>`
  - `chore/<short-name>`
- PRs must:
  - explain *why* (not just what)
  - include test plan (what you ran, or why you didn't)
  - include screenshots/recordings for UI changes
  - include migration notes when data/schema changes

Merging:
- Prefer squash merges unless the repo explicitly wants merge commits.
- No direct pushes to `main` unless a repo is explicitly marked as "solo dev / fast lane."

Solo/fast-lane repos must say so in their README. Trulana is currently fast-lane for core development.

## Commit messages

Prefer conventional-ish clarity:

- `feat: ...`
- `fix: ...`
- `chore: ...`
- `docs: ...`
- `refactor: ...`
- `test: ...`

If the change touches data integrity, auditing, PII handling, or security, say that explicitly in the PR description.

## CI/CD

Baseline expectations for Flutter/Dart repos:

```yaml
# Minimum CI jobs on every PR:
- flutter pub get
- flutter analyze --fatal-infos     # zero analyzer warnings
- flutter test --coverage           # all tests green
```

For macOS desktop apps, add a build job:

```yaml
- flutter build macos --release     # confirm release build compiles
```

For REST/MCP servers, verification scripts (e.g. `scripts/demo_client.sh`, `scripts/test_mcp.sh`) should be documented and ideally wired into CI or a manual smoke-test step.

Build artifacts must be traceable to a commit SHA. Code signing and notarization are manual steps — document where that procedure lives.

Where to find pipelines:
- GitHub Actions: `.github/workflows/`
- Or repo-specific CI docs under `docs/ci.md`

## Secrets and config

Rules:

- **Never** commit secrets. Not "temporarily." Not "just this once."
- Use GitHub environments + secrets, or the approved secret manager.
- For local dev: `.env.example` is allowed; `.env` is not (gitignored).
- Keys that belong in the OS keychain stay there — do not round-trip them through env vars or config files.

Rotation:
- If a secret leaks, rotate immediately and document the incident.

## Data + audit posture (Kernel-level repos)

Some repos carry stronger guarantees. If your system writes audit logs or evidence trails, document:

- **Canonical encoding**: timestamps are UTC ISO-8601, ordering is explicit (not insertion-order assumed)
- **Storage**: encrypted at rest (AES-256 minimum); keys stored in OS Keychain / Secure Enclave, never in the database
- **Tamper-evidence strategy**: hash chain, signatures, WORM storage, or append-only DB constraints — pick one and document it
- **Append-only enforcement**: DB constraints or immutable storage, not just convention
- **Export format and verification steps**: if you can't explain how to verify integrity end-to-end, you don't have integrity

For MCP and REST transports that serve context data:
- Every request must produce an audit log entry: agent ID, intent, action (approved / blocked / redacted), timestamp
- Tokens are in-memory only and must not survive process restart
- Scope enforcement must happen at query time, not just at auth time

## Local development

Each repo should include a "Quickstart" section. Expected shape for Flutter repos:

1. Install Flutter SDK (pin the version — use `.fvm` or document the exact version in README)
2. `flutter pub get`
3. Copy `.env.example` → `.env` and set required vars (if applicable)
4. `flutter run -d macos` (or target platform)
5. `flutter test` — all tests should pass on a clean checkout

Verification gates (if the repo has them):
```bash
./scripts/demo_client.sh    # REST smoke tests
./scripts/test_mcp.sh       # MCP smoke tests
```

If a repo requires Docker for supporting services (databases, queues), include:
- `docker compose up`
- which services
- where data persists
- how to reset cleanly

## Releases

- Tag releases with semantic versions when it's a library or service others depend on.
- For apps, release notes must map to a commit SHA.
- Database migrations require:
  - rollback plan (even if "restore snapshot")
  - a note on data backfills or irreversibility
- For macOS distribution: code signing, notarization, and stapling steps must be documented in `docs/` or the README.

## Security and reporting

If you find a security issue:
- Do not open a public issue.
- Notify the org security contact or an admin.
- Include reproduction steps and impact.
- If PII may have been exposed, that is automatically a severity-1 incident.

Security contact:
- Email: `security@workingorder.ai`
- Backup: `ops@workingorder.ai`

## Support / ownership

If you don't know who owns a repo:
- Check `CODEOWNERS`
- Check the repo "About" / topics
- Check `docs/` or the README header

If it's still unclear, that's a repo hygiene bug — fix it.

## Org layout

```
.github/
  profile/README.md       ← org profile (this document or a summary)
  CODEOWNERS
  workflows/              ← shared CI patterns
docs/
  architecture/           ← system design, trust boundary diagrams
  runbooks/               ← operational procedures
  standards/              ← this document and related references
templates/
  repo-starter/           ← starter README, CONTRIBUTING, SECURITY templates
  issue-templates/
  pr-templates/
```

---

### Quick links

- Engineering docs: `docs/`
- Runbooks / ops notes: `docs/runbooks/`
- Architecture diagrams: `docs/architecture/`
- New repo checklist: `docs/standards/new-repo-checklist.md`
- Trulana repo: [github.com/AdamsLocal/trulana](https://github.com/AdamsLocal/trulana)
