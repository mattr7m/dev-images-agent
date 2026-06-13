---
name: image-candidate-channel
kind: Task
owner: dev-images-image-maintainer-1-qwen-local-1
status: active
---

# Task: devbox-set candidate channel (daily, interim until CI)

Run the **daily candidate pass** for the devbox image set per `image-maintainer`'s
"Interim: agent-executed channel (before CI)" — `mattr7m/dev-images` has no CI yet, so this
task carries the channel until `daily-prerelease` / `cut-candidate` workflows exist.

Depends on: `tasks/devbox.md` and `tasks/devbox-claude.md` (the Containerfiles this pass
builds; until they land in `main`, a pass logs "sources not present" and ends).

## Desired state

After each pass, for every image in the devbox set present in `mattr7m/dev-images` `main`
(today: `devbox`, then `devbox-claude` — build in that dependency order):

- A fresh build from `main` HEAD passes its smoke tests (reuse the acceptance-criteria
  commands from the corresponding developer task — UID/workspace checks for devbox; init /
  plain / boot paths for devbox-claude).
- The result is published to `ghcr.io/mattr7m/<image>` as:
  - floating channel tag `:candidate` (moved forward), and
  - immutable dated tag `:candidate-YYYYMMDD` (provenance; feature-release tags append to
    this form per `image-developer`).
- The pass's status-log entry records: source commit SHA, tags pushed, and each image's
  digest — appended to this file via the normal PR flow.
- On build/test failure: **stop and report** (status-log entry + issue/PR per
  `image-maintainer`); do not push a broken candidate; `:candidate` keeps pointing at the
  last good pass.

Full `vX.Y.Z-rc.N` candidate semantics (lockfile, `verify-pins`) arrive with the CI
migration; the dated-tag scheme above is the explicit interim and feeds the repo's pending
tag-scheme decision (`guidance/overview.md`).

## Acceptance criteria (per pass)

- [ ] `podman pull ghcr.io/mattr7m/<image>:candidate` resolves to the digest recorded in the
      status log.
- [ ] Dated tag exists for the pass; digests in the log match the registry.
- [ ] Status-log entry merged via PR.

## Constraints / inputs

- Guidance chain: `image-maintainer-dev-images` → `image-maintainer` → `repo-rules`, plus
  `common-agent/guidance/task-model.md`.
- Registry write: `podman login ghcr.io -u mattr7m --password-stdin <<< "$GHCR_TOKEN"`
  (`GHCR_TOKEN` injected from this agent's `-ghcr` credential Secret). Registry credentials
  are maintainer-only — never share with developer agents.
- This task **builds and publishes**; it does not edit Containerfiles. Config changes are
  the developer's PRs.
- The first published `devbox-claude` candidate digest unblocks the
  `agent-maintainer-1-claude-code-1` bundle (its CR pins that digest) — flag it prominently
  in the status log.
- `done` when the corresponding CI workflows carry the daily pass (suspend the recurring
  trigger in the same change).

## Status log

(append-only; dated entries by the owning agent)
