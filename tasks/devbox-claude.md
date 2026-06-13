---
name: devbox-claude
kind: Task
owner: dev-images-image-developer-1-qwen-local-1
status: active
---

# Task: devbox-claude derivative image

Depends on: `tasks/devbox.md` (local `FROM devbox` — build the base first, same image cache).

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

- [ ] Base-then-derivative build succeeds from repo root.
- [ ] Init path: `podman run --rm -e TOOLS_DIR=/tmp/tools -v ...: devbox-claude` (with a tmpfs
      tools dir) exits 0 and leaves an executable `opencode` file in the tools dir whose
      content is `claude-agent-boot.sh`.
- [ ] Plain path: `podman run --rm devbox-claude sh -c 'claude --version && tmux -V'` works.
- [ ] Boot path: running the planted script as
      `sh -c '/tools/opencode serve --port 4096 --hostname 0.0.0.0'` inside the container
      yields `curl -s -o /dev/null -w '%{http_code}' localhost:4096/session/status` → `200`
      and `tmux has-session -t main` → exit 0.
- [ ] If `/bootstrap/CLAUDE.md` is bind-mounted, it appears at `/workspace/CLAUDE.md` after boot.
- [ ] PR open on `mattr7m/dev-images`, description references this task and
      `tasks/devbox.md` as its dependency.

## Constraints / inputs

- Guidance chain: `image-developer-dev-images` → `image-developer` → `image-maintainer` →
  `repo-rules`, plus `common-agent/guidance/task-model.md`.
- Boundary rule: Claude-specific tooling stays in this derivative — no base edits.
- The consuming Agent CR shape (ConfigMap mounts, no standby, etc.) is documented in
  `kube-open-code-agent/guidance/agent-templating-claude-code.md`; this task owns only the
  image side of that contract.

## Status log

(append-only; dated entries by the owning agent)
