# dev-images Overview

Reference context for the dev-images project. **Not** part of either inheritance chain — both
`image-developer` and `image-maintainer` should read this to understand the repo's shape before
acting.

## Image hierarchy

```
quay.io/devfile/universal-developer-image:ubi9-e420701   (Red Hat UBI9 devfile image; upstream)
  └── udi-tools                  (images/udi-tools/Containerfile)
        └── udi-tools-claude     (images/udi-tools-claude/Containerfile)
```

`udi-tools` is the base; derivatives reference it locally (`FROM udi-tools`) rather than via a
registry tag, so derivative builds require the base to exist in the local image cache. Today only
one derivative (`udi-tools-claude`) exists.

**Future:** a parallel `devbox` set (kubeopencode-oriented) is anticipated under the same
base/derivative convention — `devbox` base + `devbox-<extra>` derivatives, following the
[kubeopencode devbox Dockerfile pattern](https://github.com/kubeopencode/kubeopencode/blob/main/agents/devbox/Dockerfile)
(see the developer block for invariants).

## Build today

No Makefile, no `scripts/build.sh`, no CI. Builds are direct `podman` / `docker` invocations from
the **repo root** (the Containerfile copies from `scripts/`, so the image-dir is not a valid build
context):

```bash
podman build -t udi-tools -f images/udi-tools/Containerfile .
podman build -t udi-tools-claude -f images/udi-tools-claude/Containerfile .
```

The dev-images `CLAUDE.md` documents this build contract for in-repo agents; this block just
mirrors it for reference.

## Tags / registry

- **Registry:** `ghcr.io/mattr7m/<image>`.
- **Current tag scheme in use:** `vX.Y.Z-pN[-variant]` — `devfile.yaml` references
  `ghcr.io/mattr7m/udi-tools:v0.1.0-p3-claude`. Applied manually today (no CI publishing).
- **Decision pending:** preserve this scheme vs. migrate to the parent block's `vX.Y.Z-rc.N`
  candidates + clean `vX.Y.Z` releases. See `image-maintainer-dev-images.md`.

## What floats today (targets for the release pipeline to pin)

- Base image: `quay.io/devfile/universal-developer-image:ubi9-e420701` (tag-pinned, not digest).
- `udi-tools/Containerfile` binaries — installed under explicit `ARG <NAME>_VERSION` for argocd,
  gh, roxctl, kubeseal, kustomize, kubecolor; but **`yq` pulls from `releases/latest`** (no pin)
  and **VSCode CLI pulls a rolling `?build=stable` URL** (no pin).
- dnf installs (`openldap-clients`, `pinentry`, `python3`, `python3-pip`): unpinned.
- pip installs (`ansible`, plus `scripts/requirements.txt`): unpinned.
- `colordiff` fetched from a raw `master` URL: unpinned, vulnerable to upstream changes.
- `udi-tools-claude` Claude Code CLI: pinned via `CLAUDE_CODE_VERSION` ARG.

## Existing CI/CD

**None.** No `.github/workflows/`, no published tag history. All the maintainer scaffolding targets
in `image-maintainer-dev-images.md` are greenfield. Use
`mattr7m/bootc-images-private/.github/workflows/{build-images,sync-upstream}.yml` as the migration
model — that's the closest sibling project that already runs the pattern.

## Public ↔ private relationship

`mattr7m/dev-images-private` is intended as a downstream private mirror that may carry env-specific
images and configs the public repo shouldn't expose (internal hostnames, candidate `config.toml`
content, credentials referenced by env, etc.). **Today it is empty** — zero commits. Initial
bootstrap (one-time seed) and ongoing public→private sync are `image-maintainer` work; the
migration target for the ongoing sync is a `sync-upstream.yml` GitHub Action modeled on the
bootc-images-private one.

## Out of scope from this agent

`mattr7m/dev-images` carries its own `AGENTS.md` (stub) and `CLAUDE.md` (substantive, build
contract + tooling conventions) aimed at agents operating *inside* the repo. Those documents are
authoritative for in-repo build conventions — link to them, don't duplicate them. They are
**not** edited from this agent.
