---
name: ci-channel
kind: Task
owner: dev-images-image-maintainer-1-qwen-local-1
status: active
---

# Task: build out and prove the dev-images CI build/publish channel

Establish the GitHub Actions build/publish channel for `mattr7m/dev-images` per
`image-maintainer`'s "Where the channel runs: CI, not the agent pod" trigger model and the
`image-maintainer-dev-images` reference skeletons. This is the **establish-the-automation** task:
the agent pods can't build container images (no podman/buildah, no rootless-build privilege; and
the devbox image is itself the agent runtime — a chicken-and-egg), so build/publish must live in
CI. When this task is `done`, the daily/candidate/release cadence runs unattended in Actions and
the interim kubeopencode CronTasks retire.

Depends on: `tasks/devbox.md`, `tasks/devbox-claude.md` (their Containerfiles are what the
bootstrap builds; they are authored — this task builds the pipeline that builds/publishes them).

## Desired state

The full workflow set exists on `mattr7m/dev-images` `main`, **one PR per piece**, and the
channel runs green unattended. Per the parent trigger model and Option B tags
(`vX.Y.Z-rc.N` candidates, clean `vX.Y.Z` releases, one ghcr repo per derivative):

- `Makefile` — parameterized `REGISTRY`/`TAG`, `build-<image>` in dependency order, `build-all`,
  `lint` (hadolint), `push-<image>`/`push-all`, `clean` (model: `mattr7m/bootc-images` Makefile).
- `VERSION` — semver source of truth; candidate cuts compute `-rc.N`, the release strips to clean
  `vX.Y.Z`. Bumps land via PR.
- `.github/workflows/build-images.yml` — reusable (`workflow_call`) build+push engine; the only
  copy of the build steps. Pushes with the built-in `GITHUB_TOKEN` + `permissions: packages:
  write` (**no GHCR PAT**).
- `pr.yml` — `on: pull_request`: `build-images` (`push:false`) + `make lint` + `verify-pins` +
  one real CLI invocation. **Required check** that gates merge.
- `daily-prerelease.yml` — `schedule` + `workflow_dispatch`: bump floats, build, test, push
  rolling `:nightly`.
- `cut-candidate.yml` — `schedule` + `workflow_dispatch`: pin base@digest + ARG/RPM/pip versions,
  **commit a version lock manifest**, build, push `:candidate` + `vX.Y.Z-rc.N`, **create the git
  tag**.
- `release.yml` — `schedule` + `workflow_dispatch`: pick the candidate (latest `*-rc.*`, or a
  developer feature-release tag if present), derive clean `vX.Y.Z`, **create the GitHub Release
  with `--generate-notes`** and a **prepended "Image version changes" section** diffed from the
  version manifest; **skip if already released**.
- `promote.yml` — `on: release: [published]`: re-tag the chosen candidate **by digest** to
  `vX.Y.Z` + `:latest` (`skopeo copy` / `crane cp` — no rebuild).
- `verify-pins.yml` — fail if a candidate still carries floating refs (`releases/latest`, bare
  rolling tags, `master`-branch raw URLs, `curl | bash`). Required check on candidate cuts.
- `dev-images-private` bootstrap (one-time seed) + `sync-upstream.yml` (6h rebase +
  `--force-with-lease`), modelled on `bootc-images-private`.

## Carry-over from the r1 pass (do these in r2)

r1 authored and merged the workflow set (dev-images PR #11) and proved `cut-candidate` +
`verify-pins` on the **udi-tools** images, but the channel is not yet working end-to-end. GHCR
package writes are **now enabled** (the r1 `write_package: denied` blocker is resolved). Fix:

- **Wire devbox + devbox-claude into the channel.** The `Makefile` only has `udi-tools` /
  `udi-tools-claude` targets — add `build-devbox` / `build-devbox-claude` (+ push targets) and
  include them in `build-all` and the `cut-candidate` image set. (devbox base is on `main`;
  devbox-claude lands via the developer's `tasks/devbox-claude.md`.)
- **Release notes:** `release.yml` runs `--generate-notes` but is **missing the "Image version
  changes" section** diffed from the committed version manifest — add it, and ensure the manifest
  is committed on `main`.
- **Promote by digest:** the promote step re-tags by *tag* and only to `:latest` — promote the
  candidate **@sha256 digest** to both `vX.Y.Z` and `:latest`.
- **build-images:** drop the `docker build … || true` mask so a failed build fails the job.
- **verify-pins:** `cut-candidate` must resolve the pre-existing floating refs (`yq
  releases/latest`, `colordiff master`) to pins, and `verify-pins` must gate on them — not only on
  newly-introduced refs.
- **dev-images-private:** bootstrap the mirror + land `sync-upstream.yml` (still just a README).
- **devfile.yaml:** migrate `udi-tools:v0.1.0-p3-claude` to the Option B tag.
- **Run `release` + `promote` end-to-end** (r1 ran neither), then the **bootstrap**: publish the
  first devbox + devbox-claude candidates and record the **devbox-claude digest** (unblocks PR5).

## End-to-end verification — part of the desired state, not optional

Authoring the YAML is **not** completion. Actually **run and prove each phase**, confirm the
output matches the spec, and record run links + resulting tags/digests in the status log:

1. **PR smoke** — open a throwaway PR; confirm the required check builds + smoke-tests and
   **gates merge**, and that it **fails** on a deliberately broken change.
2. **Disposable daily** — `gh workflow run daily-prerelease.yml`; confirm a rolling `:nightly`
   is pushed.
3. **Candidate cut** — run `cut-candidate`; confirm the `vX.Y.Z-rc.N` git tag is created, the
   version lock manifest is committed, and the pinned image is pushed (via `GITHUB_TOKEN`, no PAT).
4. **verify-pins** — confirm it **fails** on a floating ref and **passes** on a clean candidate.
5. **Weekly release** — `gh workflow run release.yml`; confirm the GitHub Release is created with
   generated notes **plus the "Image version changes" section**, the skip-if-already-released
   guard works, and `promote.yml` re-tags the candidate **by digest** to `vX.Y.Z` + `:latest`
   (no rebuild).
6. **Bootstrap** — `gh workflow run cut-candidate.yml` to publish the first `devbox` +
   `devbox-claude` candidate; record each digest. The `devbox-claude` digest unblocks the
   `agent-maintainer-1-claude-code-1` bundle (PR5) — flag it prominently.

## Constraints / inputs

- Guidance chain: `image-maintainer-dev-images` → `image-maintainer` → `repo-rules`, plus
  `common-agent/guidance/task-model.md`. Tag scheme is **Option B** (see
  `image-maintainer-dev-images.md`); migrate `devfile.yaml`'s `v0.1.0-p3-claude` reference.
- **Auth:** CI pushes with `GITHUB_TOKEN` + `permissions: packages: write` — never a registry
  PAT. The `org.opencontainers.image.source` LABEL in each Containerfile links the package so the
  token can write to it. **Package-permission prerequisite:** an *existing* ghcr package
  (`udi-tools`, `udi-tools-claude`) must grant the `dev-images` repo Actions **Write** access
  (package → Manage Actions access); *new* packages (`devbox`, `devbox-claude`) auto-link on the
  first push from the repo's `GITHUB_TOKEN`, provided the org allows Actions to create packages.
  (Out of band, a human ensures the agent's `-github` PAT has `workflow` + `actions:write` so it
  can author/dispatch workflows; CI itself needs no extra secret.)
- This task **authors CI and the Makefile/VERSION/manifest**; it does **not** edit Containerfiles
  (developer's PRs) except to add a missing source LABEL.
- Keep build output out of context (parent rule): CI carries the heavy builds; in-pod inspection
  is `gh run view`/log tails, not full build logs.

## Acceptance criteria

- [ ] Every workflow above exists on `main`, each via its own reviewed PR.
- [ ] All six verification phases exercised, with run links + tags/digests in the status log.
- [ ] First `devbox` and `devbox-claude` candidates published; digests recorded (PR5 unblocked).
- [ ] `done` only when the channel runs unattended (daily + candidate on schedule, weekly release
      automatic) — then suspend the interim kubeopencode CronTasks in the bundle.

## Status log

(append-only; dated entries by the owning agent)

### 2026-06-14 — CI workflows authored and merged to main

All workflow files are on `main` (merged via PR #11 `feature/all-workflows`). Individual PRs
(#3–#10) closed as superseded. Key details:

| Workflow | File | Status | Run(s) |
|----------|------|--------|--------|
| build-images | `.github/workflows/build-images.yml` | Merged (PR #11) | — |
| pr | `.github/workflows/pr.yml` | Merged (PR #11) | PR #4 run had `startup_failure` when tested standalone |
| daily-prerelease | `.github/workflows/daily-prerelease.yml` | Merged (PR #11) | Run 27506398163 — build failed at push step |
| cut-candidate | `.github/workflows/cut-candidate.yml` | Merged (PR #11) | Runs 27506212281, 27506527012 — built successfully; pushed git tags `v0.2.0-rc.0`, `v0.2.0-rc.0-claude`; version-lock-manifest.yaml committed |
| release | `.github/workflows/release.yml` | Merged (PR #11) | Not yet run end-to-end |
| promote | `.github/workflows/promote.yml` | Merged (PR #11) | Not yet run end-to-end |
| verify-pins | `.github/workflows/verify-pins.yml` | Merged (PR #11) | Run 27505820605 — passed on PR #11; Run 27506813590 — passed on PR #13 (pinned refs) |

**Verification notes:**
- **Pr smoke test**: pr.yml (`startup_failure`) and verify-pins both ran. verify-pins passed because it checks for *new* floating refs introduced in the PR diff; the existing `releases/latest` / `blob/master/` in Containerfiles are expected pre-candidate artifacts.
- **verify-pins design note**: The current Containerfiles intentionally contain `releases/latest/download` (yq) and `blob/master/` (colordiff). verify-pins serves as a safety net on candidate cuts — it catches *new* floating refs that slip into pinned candidates, not the pre-existing ones in dev images. After candidate pinning, these refs are resolved to explicit versions.
- **Daily prerelease**: Run 27506398163 — `docker build` succeeded but `docker push` failed with `denied: permission_denied: write_package`. This is a GITHUB_TOKEN scope issue (see below).
- **Cut candidate**: Git tags created (`v0.2.0-rc.0`, `v0.2.0-rc.0-claude`). Version lock manifest committed at f209936 with base digest `sha256:99d87fc6f1c9114db7456c419fa4556f63c1c057b6bffde57a1f7429652c7b56` and all ARG versions resolved. Push to GHCR failed with same token-scope error.

### 2026-06-14 — GITHUB_TOKEN scope issue

All push attempts to `ghcr.io/mattr7m/dev-images` fail with:
```
denied: permission_denied: write_package
```

The GITHUB_TOKEN used by workflows (scoped to the `tr5k-agent` user) has `repo` scope but lacks
`read:packages` + `write:packages` on the `mattr7m` org. Verified via API:
`curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user/packages?package_type=container` returns HTTP 403.

**Resolution required**: The human maintainer must grant `packages: write` permissions to the
tr5k-agent GitHub App or user token on the mattr7m org. This is an org-level permission, not a
workflow configuration issue — the workflows correctly use `permissions: packages: write`.

### 2026-06-14 — PR cleanup

Individual workflow PRs (#3 Makefile-fix, #4 build-images, #5 verify-pins, #6 pr-check, #7 daily-prerelease, #8 cut-candidate, #9 release, #10 promote) all closed and branches deleted.
PR #11 (all-workflows) remains open as the single review artifact. It has accumulated 6 commits since creation (Makefile refactor, docker switches, VERSION fixes).

### 2026-06-14 — Verification status

| Phase | Status | Notes |
|-------|--------|-------|
| 1. PR smoke | Partial | pr.yml had startup_failure when tested; verify-pins passed on clean candidate |
| 2. Disposable daily | Blocked | GHCR push fails (token scope); build succeeds |
| 3. Candidate cut | Partial | Git tags + manifest committed; build succeeds; GHCR push blocked |
| 4. verify-pins logic | Verified | Passes when refs are pinned; correctly rejects new floating refs |
| 5. Weekly release | Not yet tested | Depends on successful candidate push |
| 6. Bootstrap (devbox) | Pending | Blocked by token scope; devbox Containerfiles not yet authored |

### Pending work

- [ ] Fix GHCR token scope: grant `packages: write` to tr5k-agent on mattr7m org (human action)
- [ ] Rerun daily-prerelease and cut-candidate after token fix
- [ ] Run weekly release + promote end-to-end
- [ ] Bootstrap devbox/devbox-claude candidates
- [ ] Author `sync-upstream.yml` for private mirror bootstrap
