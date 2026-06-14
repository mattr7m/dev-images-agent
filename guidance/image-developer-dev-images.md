---
name: image-developer-dev-images
description: Repo-specific image-developer guidance for mattr7m/dev-images (udi-tools base + derivatives, forthcoming devbox set).
tags: [image-developer]
inherits: image-developer
---

# dev-images Image Developer

Repo-specific layer on top of `image-developer` (and through it `image-maintainer` and
`repo-rules`, all in `common-agent`). The parent block defines the cross-repo / in-repo
consumption modes, local build/test loop, and PR-handoff contract; this block says *what those
mean in dev-images specifically*. Read `guidance/overview.md` for the repo's shape first.

## Naming conventions (this repo)

- **Base:** `udi-tools` (Red Hat UDI tooling set).
- **Derivatives:** `udi-tools-<extra>` (e.g. `udi-tools-claude` adds the Claude Code CLI).
- **Future devbox set** (kubeopencode-oriented): `devbox` base + `devbox-<extra>` derivatives,
  same boundary rule.
- **Boundary rule:** if extra tooling doesn't belong in everyone's base, **create a new
  derivative** rather than fattening the base. A larger base ripples to every derivative.

## Local `FROM` reference for derivatives

Derivatives reference the base **locally** (e.g. `FROM udi-tools` in
`udi-tools-claude/Containerfile`) — not via registry tag. Consequences:

- Build base **before** derivative in the same pod / same image cache.
- The dev-images `CLAUDE.md` documents the build commands (`podman build -t udi-tools …` from the
  repo root, because the Containerfile copies from `scripts/`). Follow that contract — don't
  invent a build invocation here.
- If the maintainer is curating a candidate of the base, rebuild the base locally **from that
  candidate** before iterating on a derivative change (see "Branching" below).

## Devbox-pattern invariants (for *new* devbox-style images authored here)

When authoring a new devbox image (kubeopencode-oriented), follow the kubeopencode
[`agents/devbox/Dockerfile`](https://github.com/kubeopencode/kubeopencode/blob/main/agents/devbox/Dockerfile)
invariants — they are the contract its runtime expects:

- **Base:** pinned-date Debian slim (`debian:bookworm-<date>-slim`); not `:stable`, not `:latest`.
- **Network discipline:** every network-touching `RUN` wrapped in a retry loop
  (`for i in $(seq 1 $RETRY_COUNT); do … || sleep …; done`); apt installs use
  `--no-install-recommends` and end with `rm -rf /var/lib/apt/lists/*`.
- **Arbitrary-UID / OpenShift contract:** `USER 1000:0`, no `useradd`, `HOME=/tmp`, XDG dirs
  (`XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`) all under `/tmp`, Go caches under
  `/tmp`, `/workspace` world-writable (`chmod 777`) so the K8s `securityContext` can take over.
- **Version sources of truth:** `ARG`s (`GO_VERSION`, `OPENCODE_VERSION`, etc.) — never inline a
  version inside a `RUN`.
- **Layer ordering by concern:** retry-helper / core utils / CLI tooling / language runtimes /
  cloud CLIs / LSPs / auth scripts / workspace+user, in that order.

**The existing `udi-tools` images do not follow this contract** — they inherit Red Hat UBI
conventions (`USER 0`, `HOME=/home/user`). The contract above applies to *new* devbox-style
images. **Don't retrofit it onto `udi-tools`** as a side effect of a feature PR; that's a
maintainer-level decision.

## Tool delivery model for devbox derivatives

Prefer a **minimal sibling image + init-container mount** (the
[`agents/opencode/`](https://github.com/kubeopencode/kubeopencode/tree/main/agents/opencode)
pattern: a two-stage carrier whose binary lands at a known path) over bolting tools onto the
devbox base. Reserve devbox edits for runtime / LSP needs shared across *all* agents.

The same logic applies inside udi-tools: an "extra tooling" need that's only used by some
workspaces is a new derivative, not a base edit.

## Local build/test loop in the agent pod

**The authoritative build/smoke is PR CI, not the pod** (see `image-developer`): the dev-images
agent pods generally have no container-build tooling, so a local build may be impossible — author
the config, open the PR, and let the `pull_request` check build/smoke it. The commands below are a
fast inner check *when the pod can build*; "couldn't build locally" is not a blocker.

Concrete commands per Containerfile (run from the repo root). Redirect the verbose build
output to a log file and read back only the tail/errors — per the inherited *Keep build output
out of context* rule (`image-maintainer`), a full `podman build` log will overrun a
small-context model and kill the pass mid-build:

```bash
# Base — redirect, then inspect narrowly
podman build -t udi-tools -f images/udi-tools/Containerfile . > build-udi-tools.log 2>&1 \
  || { tail -n 40 build-udi-tools.log; grep -niE 'error|fail|cannot' build-udi-tools.log | tail; }

# Derivative (requires udi-tools to exist locally)
podman build -t udi-tools-claude -f images/udi-tools-claude/Containerfile . \
  > build-udi-tools-claude.log 2>&1 || tail -n 40 build-udi-tools-claude.log
```

Keep the `build-*.log` files in the workspace as build evidence; reference them in the status
log / PR rather than pasting full logs. The same redirect applies to the `devbox` /
`devbox-claude` builds.

Exercise behavior before considering the build "done":

```bash
podman run --rm udi-tools argocd version --client
podman run --rm udi-tools gh --version
podman run --rm udi-tools-claude claude --version
```

"It built" is not evidence the change works — confirm at least the CLI the change targets
invokes. Don't push from the agent pod; it's throwaway.

## Branching for an update

- **Pre-candidate (today):** no candidate channel exists yet (the maintainer hasn't established
  it — see `image-maintainer-dev-images.md`). Branch off `main` and **call out in the PR
  description that you started pre-candidate**, so the maintainer knows your work hasn't been
  reconciled against a known-good base.
- **Once the candidate channel exists:** branch off the latest candidate. If your derivative
  rebuild depends on a base candidate that hasn't shipped yet, ask the maintainer to cut one
  rather than pinning around it.

## PR target

- **`mattr7m/dev-images`** — public-relevant work (new derivative, version bump, devbox image,
  documentation, build script). Default target.
- **`mattr7m/dev-images-private`** — env-specific work that **should never** leave the private
  mirror: internal hostnames, internal-only credentials referenced by env, env-pinned variants
  intended only for the local environment. If in doubt about whether it's private-only, ask the
  maintainer before opening the PR — public/private placement is a maintainer concern.

## Developer checklist (dev-images specifics)

Layered on the parent's checklist:

- [ ] Build base before derivative; both pass `podman run … <cli> --version`.
- [ ] If adding a new derivative, the boundary rule applies — extras stay out of the base.
- [ ] If adding a new devbox-pattern image, the arbitrary-UID OpenShift contract is intact.
- [ ] No new floating refs introduced beyond what already floats today (see overview's "What
      floats" — adding more makes the maintainer's eventual pinning job worse).
- [ ] PR target is right (public vs. private mirror); PR description names the candidate or
      `pre-candidate` baseline the work was developed against.
