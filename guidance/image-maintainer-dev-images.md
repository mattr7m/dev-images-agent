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

1. **Decide the tag scheme** (see "Candidate channel — decision required" below).
2. **Land a Makefile** (build/lint/push contract).
3. **Seed the private mirror** (one-time bootstrap).
4. **Land the four CI workflows** (one PR each).
5. From there: the parent block's daily/candidate discipline applies as written.

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

## Candidate channel — decision required

`devfile.yaml` already references `ghcr.io/mattr7m/udi-tools:v0.1.0-p3-claude`, applied manually.
Choose one and document the choice in this block before scaffolding `cut-candidate.yml`:

**Option A — preserve `vX.Y.Z-pN[-variant]`.** Treat `-pN` as the candidate marker; the `[-variant]`
suffix is the derivative selector (e.g. `-claude`). Releases drop the `-pN` and become
`vX.Y.Z[-variant]`. Pro: continuity with what's already published / referenced in `devfile.yaml`.
Con: variant-in-tag means one ghcr repo per base with N tags per release; parent block's
`rc.N` semantics don't translate cleanly.

**Option B — migrate to parent's `vX.Y.Z-rc.N`.** Each derivative becomes a separate ghcr repo
(`ghcr.io/mattr7m/udi-tools`, `ghcr.io/mattr7m/udi-tools-claude`), tagged independently with
clean `vX.Y.Z` releases and `vX.Y.Z-rc.N` candidates. Pro: matches the parent block; cleaner
semantics for promotion. Con: requires updating `devfile.yaml` and any downstream consumer; the
existing `v0.1.0-p3-claude` doesn't have a one-shot rename target.

Recommendation: **B**, but the migration cost is real — capture it in the PR description and
coordinate with whoever maintains the devfile / consumer references.

## CI scaffolding targets (capture-as-scaffolding; one PR each)

Realizes the parent's checklist against this repo. All four are greenfield — there is no existing
workflow to extend. Model on `bootc-images-private/.github/workflows/{build-images,sync-upstream}.yml`
for the actual GHCR-login / repo-event / scheduler patterns.

- [ ] **`daily-prerelease.yml`** — scheduled. Bump floating refs in `udi-tools/Containerfile`
      (today: the `yq` `releases/latest` URL, the VSCode `?build=stable` URL, the `colordiff`
      `master` URL, and dnf/pip installs that lack pins). `make build-all` + `make lint`. Push
      rolling tag.
- [ ] **`cut-candidate.yml`** — on green daily (or manual). Resolve the base
      `quay.io/devfile/universal-developer-image:ubi9-e420701` to a digest pin; assert all
      `ARG <NAME>_VERSION` lines are explicit; record a manifest of resolved RPM NEVRAs + pip
      versions for reproducibility; tag + publish candidate per the chosen scheme.
- [ ] **`build-images.yml`** — release-event-triggered build + push to GHCR. Tag both the
      release tag and `:latest`. Direct port of `bootc-images-private/.github/workflows/build-images.yml`.
- [ ] **`verify-pins.yml`** — fail if any candidate Containerfile still contains
      `releases/latest`, a bare `:ubi9-<short>` rolling tag, a `master`-branch raw URL, or a
      `curl | bash` install. Run as a required check on candidate-cut PRs.

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

- [ ] Tag-scheme decision documented in this block (Option A or B), with a PR description on
      `devfile.yaml` if Option B.
- [ ] Makefile contract lands before the first developer PR that depends on it.
- [ ] Each of the four workflow PRs reduces a section of this block to "verify it's green"
      rather than running it by hand.
- [ ] Private mirror is bootstrapped exactly once; ongoing sync runs from the workflow.
- [ ] No floating ref ships in a candidate; `verify-pins.yml` is a required check.
