---
name: image-candidate-channel
kind: Task
owner: dev-images-image-maintainer-1-qwen-local-1
status: active
---

# Task: curate the daily candidate channel

Curate the **daily pre-release + pinned candidate** channel for the devbox image set, which runs
in **GitHub Actions** (`daily-prerelease.yml`, `cut-candidate.yml`) per `image-maintainer`'s
trigger model — not as an in-pod build. The maintainer's standing job is to keep that channel
green and current, not to build images by hand.

Depends on: `tasks/ci-channel.md` (which authors and proves the workflows). Until they exist this
task is dormant; once the channel is live this is the ongoing curation duty.

## Desired state

- The `daily-prerelease` and `cut-candidate` workflows run green on schedule; the `:candidate`
  floating tag and the immutable `vX.Y.Z-rc.N` tags advance **only** on green.
- The maintainer responds to what the daily surfaces — a floating ref that drifted or broke
  upstream (fix the pin/source via a PR to `mattr7m/dev-images`), a failed candidate cut
  (diagnose from `gh run` output, fix, re-run `workflow_dispatch`), a `verify-pins` regression.
- Each candidate carries its **committed version lock manifest** (the source for release notes)
  and a clean `vX.Y.Z-rc.N` tag (Option B); no floating ref ships in a candidate.
- Notable interventions (a broken upstream, a pin bump, a skipped cut, a re-run) are recorded in
  this file's status log via the normal PR flow.

## Acceptance criteria

- [ ] The candidate channel is green: latest `vX.Y.Z-rc.N` built clean and `verify-pins` passed.
- [ ] `ghcr.io/mattr7m/<image>:candidate` resolves to the latest candidate digest.
- [ ] Interventions for the period are logged via PR.

## Constraints / inputs

- Guidance chain: `image-maintainer-dev-images` → `image-maintainer` → `repo-rules`, plus
  `common-agent/guidance/task-model.md`. Tag scheme is **Option B**.
- **No in-pod build, no registry PAT.** CI builds and pushes with `GITHUB_TOKEN`; the maintainer
  curates via config/pin PRs and `workflow_dispatch`, reading `gh run` output (not full build
  logs — keep build output out of context).
- This task **curates**; it does not edit Containerfiles (developer PRs) or author the workflows
  (that's `ci-channel.md`).
- Standing duty — stays `active` while the channel is agent-curated.

## Status log

(append-only; dated entries by the owning agent)
