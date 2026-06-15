---
name: devbox-claude
kind: Task
owner: dev-images-image-developer-1-qwen-local-1
status: active
---

# Task: devbox-claude derivative image

Depends on: `tasks/devbox.md` (local `FROM devbox` — build the base first, same image cache).

## Gate — devbox must be in place first

A hard precondition, not just build ordering. Before authoring or building anything here,
verify the base exists and builds:

- `images/devbox/Containerfile` is present on `mattr7m/dev-images` `main` (the `tasks/devbox.md`
  desired state is met / its PR merged) and
  `podman build -t devbox -f images/devbox/Containerfile .` succeeds from the repo root.
- If the base is absent or fails to build, **stop and report** — do not author this derivative
  against a missing or broken `FROM devbox`. Re-run once devbox lands.

The two execution-trigger Task CRs in the agent bundle are gated on this: the `devbox` pass
runs first; the `devbox-claude` pass checks this gate and no-ops with a report if devbox isn't
in place.

**Status (2026-06-14):** the devbox base is now merged to `main` (dev-images PR #2) and GHCR
package writes are enabled — the gate is **satisfied**, so this pass should proceed to author the
derivative and open the PR (the earlier pass correctly stopped here while the base was missing).
Build/publish then flows through the CI channel (`tasks/ci-channel.md`); the resulting
`devbox-claude` candidate digest is what unblocks the `agent-maintainer-1-claude-code-1` bundle
(PR5).

A devbox derivative that runs **Claude Code instead of opencode** inside a kubeopencode Agent
pod. The kubeopencode controller's server-pod command is hardcoded to exec
`/tools/opencode serve --port <N> --hostname 0.0.0.0`, and its `agentImage` init container
runs the image's default ENTRYPOINT with `TOOLS_DIR=/tools` expecting a binary to be copied
to `/tools/opencode`. This image exploits that contract: it plants a **boot script** as
`/tools/opencode`, so the hardcoded server command boots Claude Code. The same image serves
as both `spec.agentImage` and `spec.executorImage` on the consuming Agent CR.

## Desired state

- `images/devbox-claude/Containerfile` exists in `mattr7m/dev-images`, `FROM devbox` (local
  reference), and builds clean from the repo root after the base:
  `podman build -t devbox-claude -f images/devbox-claude/Containerfile .`
- Adds Claude Code CLI via `ARG CLAUDE_CODE_VERSION` + global npm install (prior art:
  `images/udi-tools-claude/Containerfile`). Node/npm presence is this image's concern, also
  ARG-pinned, if the base doesn't carry it.
- Ships two scripts (e.g. under `/usr/local/bin/`), copied from
  `images/devbox-claude/scripts/` in the repo:

  **1. Dispatcher ENTRYPOINT** (image default ENTRYPOINT):
  - If `TOOLS_DIR` is set: copy `claude-agent-boot.sh` to `$TOOLS_DIR/opencode`, `chmod +x`,
    exit 0. (This is the agentImage-init path.)
  - Else: behave as a plain devbox entrypoint (exec the passed command / default shell).

  **2. `claude-agent-boot.sh`** — invoked by the controller's hardcoded server command as
  `<script> serve --port <N> --hostname <H>`:
  1. Parse `--port` / `--hostname` from argv (ignore the `serve` verb).
  2. If `/bootstrap/CLAUDE.md` exists, copy it to `/workspace/CLAUDE.md`.
  3. Start the **health shim**: a python3-stdlib HTTP server bound to `<hostname>:<port>`
     answering `200` to any path (the controller probes HTTP `GET /session/status` for
     startup/readiness and TCP for liveness; these are not overridable).
  4. Start a `tmux` session named `main`, cwd `/workspace`, running `claude`. `HOME` is
     writable in-pod (`/tmp` per the devbox contract) so `~/.claude` state persists for the
     pod's lifetime.
  5. Keep PID 1 alive (wait on the shim; if the shim dies the pod should restart).
  - Honor `/etc/claude-code/managed-settings.json` if mounted (Claude Code reads this managed
    settings path natively — the script does not need to act, but must not disturb it).
  - **Never** starts or references opencode.

## Acceptance criteria

The agent authors config and opens the PR; **PR CI build/smoke is the gate** (the agent pod can't
build — see `image-developer`). Build/publish to ghcr is **gated on `tasks/ci-channel.md`** (which
also enforces the devbox-base **Gate** above). The checks below are what **PR CI runs**:

- [ ] `images/devbox-claude/Containerfile` + scripts authored, carrying
      `LABEL org.opencontainers.image.source="https://github.com/mattr7m/dev-images"`.
- [ ] Base-then-derivative build succeeds in CI.
- [ ] Init path: `podman run --rm -e TOOLS_DIR=/tmp/tools …` exits 0 and leaves an executable
      `opencode` file whose content is `claude-agent-boot.sh`.
- [ ] Plain path: `claude --version && tmux -V` works.
- [ ] Boot path: `/tools/opencode serve --port 4096 --hostname 0.0.0.0` →
      `localhost:4096/session/status` `200` and `tmux has-session -t main` → 0.
- [ ] `/bootstrap/CLAUDE.md` bind-mount appears at `/workspace/CLAUDE.md` after boot.
- [ ] PR open on `mattr7m/dev-images` referencing this task + `tasks/devbox.md`; **PR CI green**.
- [ ] First `devbox-claude` candidate built + published by the CI channel; digest recorded in
      `ci-channel.md`'s status log (unblocks PR5).

## Constraints / inputs

- Guidance chain: `image-developer-dev-images` → `image-developer` → `image-maintainer` →
  `repo-rules`, plus `common-agent/guidance/task-model.md`.
- Redirect the base-then-derivative `podman build`s to log files and read back only the
  tail/errors (per the *Keep build output out of context* rule) — a full build log will overrun
  this model and end the pass mid-build.
- Boundary rule: Claude-specific tooling stays in this derivative — no base edits.
- The consuming Agent CR shape (ConfigMap mounts, no standby, etc.) is documented in
  `kube-open-code-agent/guidance/agent-templating-claude-code.md`; this task owns only the
  image side of that contract.

## Status log

- **2026-06-15** — Config authored and merged to `mattr7m/dev-images` main (commit `98886c4`).
  `images/devbox-claude/Containerfile`, `dispatcher.sh`, and `claude-agent-boot.sh` are in place.
  CI workflows (`pr.yml`, `daily-prerelease.yml`, `cut-candidate.yml`, `release.yml`) and
  `Makefile` updated to build devbox + devbox-claude alongside udi-tools images. Acceptance:
  Containerfile LABEL ✅, no unpinned refs ✅, scripts executable ✅, PR CI jobs present ✅.
  Build/publish to ghcr gated on `tasks/ci-channel.md` — first candidate digest recording there
  unblocks PR5.

(append-only; dated entries by the owning agent)
