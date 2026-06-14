---
name: image-maintainer-dev-images
description: Repo-specific image-maintainer guidance for mattr7m/dev-images and its private mirror — greenfield CI/channel state to establish, then curate.
tags: [image-maintainer]
inherits: image-maintainer
---

# dev-images Image Maintainer

Repo-specific layer on top of `image-maintainer` (and through it `repo-rules`, both in
`common-agent`). The parent block defines the two-track flow (daily floating → pinned candidate)
and the CI/CD checklist; this block says *what's missing in dev-images today and what to build
toward*. Read `guidance/overview.md` for the repo's shape first.

## Greenfield state to address (do these as separate PRs)

`dev-images` has no Makefile, no `.github/workflows/`, no candidate channel, no published tag
history. `dev-images-private` is an empty repo. The maintainer's job today is **establish, then
curate** — not just curate. Order matters:

1. **Tag scheme: Option B** (decided — see "Candidate channel" below).
2. **Land a Makefile + `VERSION`** (build/lint/push contract + semver source of truth).
3. **Seed the private mirror** (one-time bootstrap) + `sync-upstream.yml`.
4. **Land the CI workflow set** (one PR each — see "CI scaffolding targets" below).
5. From there: the parent block's trigger model runs the channel; the maintainer curates.

The build-out and its end-to-end proof are tracked as `tasks/ci-channel.md`; the daily-candidate
and weekly-release standing duties as `tasks/image-candidate-channel.md` /
`tasks/image-weekly-release.md`.

Until the daily/candidate workflows exist, image-developers can't branch from a candidate (they
work pre-candidate; see the developer block). Establishing the channel unblocks them.

## Build / lint scaffolding (first PR)

Add a `Makefile` modeled on `bootc-images/Makefile`:

- Parameterized `$(REGISTRY) ?= localhost` and per-image `$(TAG) ?= latest`.
- `build-udi-tools` and `build-udi-tools-claude` targets in dependency order
  (`build-udi-tools-claude: build-udi-tools`). Both build from the repo root (the Containerfile
  copies from `scripts/`).
- `build-all` aggregating both.
- `lint` running hadolint via podman across both Containerfiles.
- `push-<image>` and `push-all` (with `REGISTRY` required for push).
- `clean`.

This formalizes the build contract `image-developer` agents follow — until it lands, the
developer block has to document raw `podman build` commands.

## Candidate channel — Option B (decided)

Tag scheme is **Option B**: candidates `vX.Y.Z-rc.N`, releases clean `vX.Y.Z`, **one ghcr repo
per derivative** (`ghcr.io/mattr7m/{udi-tools,udi-tools-claude,devbox,devbox-claude}`), tagged
independently. Clean promotion semantics; matches the parent block. Migration cost: `devfile.yaml`
references `ghcr.io/mattr7m/udi-tools:v0.1.0-p3-claude` (applied manually) — update it to the
Option B tag as part of the cut-candidate PR, and coordinate with whoever maintains the devfile /
downstream consumers (call it out in the PR description). The legacy `vX.Y.Z-pN[-variant]` scheme
is retired.

`VERSION` is the semver source of truth: `cut-candidate` computes the next `-rc.N` off it, and the
release strips to clean `vX.Y.Z`. A `cut-candidate` run also **commits a version lock manifest**
(resolved base digest + ARG/RPM/pip versions) — the source for the weekly release's "Image version
changes" notes section.

## CI scaffolding targets (capture-as-scaffolding; one PR each)

Realizes the parent's trigger model against this repo (all greenfield). Model the GHCR-login /
event / scheduler patterns on `mattr7m/bootc-images-private` `build-images.yml` +
`sync-upstream.yml` and the `mattr7m/bootc-images` `Makefile` — they already run this shape. Two
deltas from bootc: push with the **built-in `GITHUB_TOKEN`** (bootc does; no PAT), and dev-images
adds the daily/candidate/promote phases bootc lacks (bootc rebuilds at release; dev-images
**promotes by digest**).

- [ ] **`build-images.yml`** — reusable (`on: workflow_call`) build+push engine; inputs `image`,
      `tags`, `push`, `pin`. `permissions: packages: write`; `redhat-actions/podman-login` with
      `${{ secrets.GITHUB_TOKEN }}`; builds from repo root (Containerfiles copy from `scripts/`),
      base before derivative. The only copy of the build steps.
- [ ] **`pr.yml`** — `on: pull_request`: call build-images `push:false` + `make lint` (hadolint)
      + `verify-pins` + one real CLI invocation. Required check.
- [ ] **`daily-prerelease.yml`** — `schedule` + `workflow_dispatch`: bump floating refs in
      `udi-tools/Containerfile` (the `yq` `releases/latest` URL, the VSCode `?build=stable` URL,
      the `colordiff` `master` URL, unpinned dnf/pip), `make build-all` + `make lint`, push rolling
      `:nightly`.
- [ ] **`cut-candidate.yml`** — `schedule` + `workflow_dispatch`: resolve the base
      (`quay.io/devfile/universal-developer-image:ubi9-e420701` → digest) and assert every
      `ARG <NAME>_VERSION` is explicit; **commit a version lock manifest** (resolved base digest +
      RPM NEVRAs + pip versions); push `:candidate` + `vX.Y.Z-rc.N`; create the git tag.
- [ ] **`release.yml`** — `schedule` + `workflow_dispatch`: pick the candidate (latest `*-rc.*`,
      or a developer feature-release tag), derive clean `vX.Y.Z` from `VERSION`,
      `gh release create --generate-notes`, then **prepend an "Image version changes" section**
      diffed from the version manifest; skip if already released.
- [ ] **`promote.yml`** — `on: release: [published]`: `skopeo copy` / `crane cp` the chosen
      candidate **by digest** to `vX.Y.Z` + `:latest`. No rebuild.
- [ ] **`verify-pins.yml`** — fail if any candidate Containerfile still has `releases/latest`, a
      bare `:ubi9-<short>` rolling tag, a `master`-branch raw URL, or a `curl | bash` install.
      Required check on candidate cuts.

Reference skeleton for the reusable engine (port from bootc, swap to `GITHUB_TOKEN`):

```yaml
# build-images.yml
on:
  workflow_call:
    inputs:
      image: { type: string }
      tags:  { type: string }
      push:  { type: boolean, default: false }
      pin:   { type: boolean, default: false }
permissions: { contents: read, packages: write }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: redhat-actions/podman-login@v1
        with: { registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }} }
      - run: |   # build from repo root, base before derivative; heavy logs → file, not stdout
          make build-${{ inputs.image }} REGISTRY=ghcr.io/${{ github.repository_owner }}
          [ "${{ inputs.push }}" = "true" ] && make push-${{ inputs.image }} REGISTRY=ghcr.io/${{ github.repository_owner }} || true
```

## Public ↔ private mirror discipline

`dev-images-private` is currently empty (no commits). Two phases:

**Phase 1 — bootstrap (one-time).** Seed the private mirror with current public content. Don't
add env-specific divergence in the bootstrap commit — keep it as a clean fork point so future
rebases work. Confirm with the project owner what env-specific content (if any) goes in private
*before* the bootstrap, so it doesn't accidentally end up public via merge confusion.

**Phase 2 — ongoing sync.** Land a `sync-upstream.yml` GitHub Action modeled on
`bootc-images-private/.github/workflows/sync-upstream.yml`:

- Every-6h rebase of private's `main` onto `mattr7m/dev-images`'s `main`.
- Force-push to `origin/main`.
- Support a `UPSTREAM_PAT` secret in case the public repo becomes private.

Once that lands, this section's manual procedure shrinks to "verify the action is green." Until
then, do the rebase by hand on a defined cadence and capture the manual steps in a runbook so
they migrate cleanly into the workflow.

**Keep the public repo clean** through the curation:

- No env-specific paths (no `/home/matt/…`, no internal hostnames).
- No credentials, ever. Reference secrets by env-var name in the Containerfile, never bake values.
- No `config.toml`-style files with real values; only `.example` templates.
- If a contribution to `dev-images` (developer PR) leaks any of the above, send it back; don't
  paper over with a follow-up cleanup commit.

## Maintainer checklist (dev-images specifics)

Layered on the parent's checklist:

- [ ] Tag scheme is **Option B** (recorded above); `devfile.yaml` migrated off `v0.1.0-p3-claude`
      in the cut-candidate PR.
- [ ] `Makefile` + `VERSION` land before the first developer PR / candidate cut that depends on them.
- [ ] Each workflow PR reduces a section of this block to "verify it's green" rather than running
      it by hand; CI pushes with `GITHUB_TOKEN` (no registry PAT).
- [ ] Private mirror is bootstrapped exactly once; ongoing sync runs from the workflow.
- [ ] No floating ref ships in a candidate; `verify-pins.yml` is a required check.
- [ ] The channel is **proven end-to-end** (per `tasks/ci-channel.md`), not just authored.
