---
name: image-weekly-release
kind: Task
owner: dev-images-image-maintainer-2-qwen-local-1
status: active
---

# Task: oversee the automatic weekly release

The weekly release is **fully automatic CI** (`release.yml` creates the GitHub Release on a
schedule; `promote.yml` re-tags the candidate by digest on `release: published`) per
`image-maintainer`'s "Weekly release and the promotion rule". This task is the maintainer's
**oversight/curation** duty — confirm each release is correct and intervene on failure; it does
**not** publish images by hand.

Depends on: `tasks/ci-channel.md` (authors `release.yml`/`promote.yml`) and
`tasks/image-candidate-channel.md` (the candidate stream the release promotes).

## Desired state

- Each weekly run produces a clean `vX.Y.Z` **GitHub Release** with **generated notes plus the
  "Image version changes" section** (diffed from the candidate's version manifest), and
  `promote.yml` re-tags the chosen candidate **by digest** to `vX.Y.Z` + `:latest` (no rebuild).
- The **promotion selection** was correct: the latest `vX.Y.Z-rc.N` by default, or a developer
  **feature-release tag** (`<candidate>-<short-feature>`) when one exists and is newer.
- The **skip-if-already-released** guard behaves on a quiet week (no empty release).
- The maintainer intervenes on a failed/skipped/mis-selected release (diagnose from `gh run`,
  fix, re-`workflow_dispatch`) and records notable releases + interventions in this file's status
  log via PR.
- **Ad-hoc release** (bootstrap/hotfix) = a manual `workflow_dispatch` of `release.yml`
  (human-initiated, gated tier); same promotion rule.

## Acceptance criteria

- [ ] Latest weekly `vX.Y.Z` Release exists with generated notes + the version-changes section.
- [ ] `ghcr.io/mattr7m/<image>:latest` resolves to the promoted candidate's digest (by-digest, no
      rebuild).
- [ ] Release oversight for the period logged via PR.

## Constraints / inputs

- Guidance chain: `image-maintainer-dev-images` → `image-maintainer` → `repo-rules`, plus
  `common-agent/guidance/task-model.md`. Tag scheme is **Option B** (clean `vX.Y.Z` releases).
- **No in-pod publish, no registry PAT.** Promotion is CI by digest with `GITHUB_TOKEN`; the
  maintainer oversees and dispatches, it does not push.
- Standing duty — stays `active` while the release is agent-overseen.

## Status log

(append-only; dated entries by the owning agent)
