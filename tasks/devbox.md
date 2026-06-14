---
name: devbox
kind: Task
owner: dev-images-image-developer-1-qwen-local-1
status: active
---

# Task: devbox base image

Stand up the kubeopencode-oriented `devbox` base image in `mattr7m/dev-images`. This is the
base of the forthcoming `devbox-<extra>` derivative set (see `guidance/overview.md`); the
first derivative is `tasks/devbox-claude.md`, which depends on this task.

## Desired state

- `images/devbox/Containerfile` exists in `mattr7m/dev-images` and builds clean from the repo
  root: `podman build -t devbox -f images/devbox/Containerfile .`
- The image follows the **devbox-pattern invariants** in
  `guidance/image-developer-dev-images.md` (the kubeopencode
  [`agents/devbox/Dockerfile`](https://github.com/kubeopencode/kubeopencode/blob/main/agents/devbox/Dockerfile)
  contract), at minimum:
  - pinned-date Debian slim base (`debian:bookworm-<date>-slim`);
  - every network-touching `RUN` in a retry loop; apt uses `--no-install-recommends` + list
    cleanup;
  - arbitrary-UID contract: `USER 1000:0`, `HOME=/tmp`, XDG dirs under `/tmp`, `/workspace`
    world-writable;
  - per-tool `ARG <NAME>_VERSION` pins — no inline versions in `RUN`;
  - layer ordering by concern per the guidance block.
- Tool set: start from the kubeopencode devbox tool list, **minus opencode-specific
  delivery** (the opencode binary arrives via init-container in the runtime, not baked here).
  Include `git`, `curl`, `jq`, `python3`, `tmux`, and the retry helper. Defer language
  runtimes / cloud CLIs unless already in the upstream pattern — keep the base lean per the
  boundary rule (derivatives carry extras).
- The image is **owned**, not pinned-from-upstream: per the own-vs-pin rule in
  `common-agent/guidance/image-developer.md` it qualifies for owning (open source,
  self-contained plain `podman build`, fits the agent environment), so the Containerfile is
  authored in-repo rather than `FROM`-ing the upstream kubeopencode image.
- `mattr7m/dev-images` `CLAUDE.md` build contract is extended with the devbox build command
  (same style as the udi-tools entries).
- Landed via PR per `repo-rules` (config only — no published tags; publishing is
  maintainer/CI work).

## Acceptance criteria

- [ ] `podman build -t devbox -f images/devbox/Containerfile .` succeeds from repo root.
- [ ] `podman run --rm devbox id -u` → `1000`; `podman run --rm devbox sh -c 'touch /workspace/x'` succeeds.
- [ ] `podman run --rm devbox sh -c 'git --version && python3 --version && tmux -V'` succeeds.
- [ ] No unpinned network fetches (`grep -n latest images/devbox/Containerfile` reviewed).
- [ ] PR open on `mattr7m/dev-images`, description references this task.

## Constraints / inputs

- Guidance chain: `image-developer-dev-images` → `image-developer` → `image-maintainer` →
  `repo-rules`, plus `common-agent/guidance/task-model.md` for this file's conventions.
- Don't retrofit the devbox contract onto `udi-tools` (explicit guidance rule).
- Redirect the `podman build` to a log file and read back only the tail/errors (per the
  *Keep build output out of context* rule) — a full build log will overrun this model and end
  the pass mid-build.

## Status log

(append-only; dated entries by the owning agent)
