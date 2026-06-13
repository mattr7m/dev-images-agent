---
name: image-weekly-release
kind: Task
owner: dev-images-image-maintainer-2-qwen-local-1
status: active
---

# Task: devbox-set weekly release (interim until CI)

Run the **weekly release pass** for the devbox image set per `image-maintainer`'s "Weekly
release and the promotion rule" — interim agent-executed channel until a CI release
workflow exists.

Depends on: `tasks/image-candidate-channel.md` (the candidate stream this pass promotes;
until at least one candidate exists, a pass logs "no candidate yet" and ends).

## Desired state

After each weekly pass, for every image in the devbox set with a published candidate:

- The promotion source is selected per the rule:
  1. **Feature-release tag override**: if a git tag matching `candidate-YYYYMMDD-<feature>`
     exists on `mattr7m/dev-images` and is newer than the last release, build/promote from
     that tag.
  2. **Default**: promote the latest green `:candidate-YYYYMMDD` (digest as recorded in
     `tasks/image-candidate-channel.md`'s status log — promote the digest, do not rebuild).
- The chosen image is published to `ghcr.io/mattr7m/<image>` as:
  - floating release tag `:stable` (moved forward), and
  - immutable tag `:release-YYYYMMDD`.
- The pass's status-log entry records: provenance (which candidate tag or feature tag, and
  why), tags pushed, digests — appended to this file via the normal PR flow.
- **Ad-hoc release** (bootstrap/hotfix, outside the cadence): a human fires an off-schedule
  pass via the recurring trigger's manual-trigger mechanism; same promotion rule applies.
  The "release immediately on developer PR merge" CI action remains a documented future
  enhancement — do not build it from this task.

Release tag scheme harmonization (vs. udi-tools `vX.Y.Z-pN[-variant]`) is the pending
decision in `guidance/overview.md` / `repo-rules` §12; the dated scheme above is the
explicit interim.

## Acceptance criteria (per pass)

- [ ] `podman pull ghcr.io/mattr7m/<image>:stable` resolves to the digest recorded in the
      status log.
- [ ] Provenance entry names the promoted candidate/feature tag and its digest.
- [ ] Status-log entry merged via PR.

## Constraints / inputs

- Guidance chain: `image-maintainer-dev-images` → `image-maintainer` → `repo-rules`, plus
  `common-agent/guidance/task-model.md`.
- Registry write: `podman login ghcr.io -u mattr7m --password-stdin <<< "$GHCR_TOKEN"`
  (this agent's own `-ghcr` credential Secret; per-CR Secrets, nothing shared with
  cohabitants).
- Promote by digest where possible — a release must not silently differ from the candidate
  it claims to promote.
- `done` when a CI release workflow carries this pass (suspend the recurring trigger in the
  same change).

## Status log

(append-only; dated entries by the owning agent)
