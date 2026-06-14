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
  token can write to it. (Out of band, a human ensures the agent's `-github` PAT has `workflow`
  + `actions:write` so it can author/dispatch workflows; CI itself needs no extra secret.)
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
