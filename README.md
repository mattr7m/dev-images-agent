# dev-images-agent

Repo-specific agent guidance for the **dev-images** project — container images used by Red Hat
Devspaces / Eclipse Che CDE workspaces (today: `udi-tools` base + `udi-tools-claude` derivative;
forthcoming: kubeopencode-oriented `devbox` + `devbox-<extra>` images). Follows the
**repo-as-agent** pattern and inherits reusable blocks from
[`common-agent`](https://github.com/mattr7m/common-agent).

This repo is the shared home for **two personas** that both operate against `mattr7m/dev-images`
and `mattr7m/dev-images-private`:

- **`image-developer`** — authors new images or updates existing ones; build/test locally in the
  agent pod, hand off via PR.
- **`image-maintainer`** — curates the daily-floating → pinned-candidate channel, keeps the
  private mirror in sync, and migrates manual steps into CI as they prove repeatable.

Both personas living here is by design: any agent working on these repos starts with the same
overview and picks up role-specific guidance via its persona tag.

## Layout

```
dev-images-agent/
├── README.md            (AGENTS.md, CLAUDE.md are symlinks to this)
├── repos/
│   ├── repos.yaml        # repos this agent operates on + agent deps
│   └── sync-repos.sh     # shallow, read-only clones into repos/<owner>/<name>
├── guidance/
│   ├── overview.md                       # the repo's shape, image set, current CI state
│   ├── image-developer-dev-images.md     # inherits image-developer; tags [image-developer]
│   └── image-maintainer-dev-images.md    # inherits image-maintainer; tags [image-maintainer]
└── tasks/                                # work specs per common-agent's task-model block
    ├── devbox.md                         # owner: image-developer-1; gated on ci-channel
    ├── devbox-claude.md                  # owner: image-developer-1; depends on devbox
    ├── ci-channel.md                     # owner: image-maintainer-1; build out + prove the CI channel
    ├── image-candidate-channel.md        # owner: image-maintainer-1; curate the CI daily/candidate channel
    └── image-weekly-release.md           # owner: image-maintainer-2; oversee the automatic weekly release
```

## Repos this agent operates on

See `repos/repos.yaml`. The agent works against both the public image definitions
(`mattr7m/dev-images`) and the private downstream mirror (`mattr7m/dev-images-private`), and pulls
shared guidance from `mattr7m/common-agent`.

Run `repos/sync-repos.sh` to clone/update read-only copies under `repos/`.

## Operating as one of the two personas

On startup:

1. Confirm your role — **`image-developer`** or **`image-maintainer`**.
2. Collect every `guidance/*.md` block — from this repo **and** from `common-agent` — whose
   frontmatter `tags` include your persona.
3. For each, resolve its `inherits:` chain root-first (parent before child); a child only *adds*
   to its parent.
4. Read `guidance/overview.md` regardless of persona — it's the repo's shape, not part of either
   inheritance chain.
5. Follow the composed guidance. The repo-specific block under this repo is the operative one for
   day-to-day work.

## Guidance & inheritance

```
common-agent: repo-rules
  └── common-agent: image-maintainer
         ├── common-agent: image-developer
         │      └── dev-images-agent: image-developer-dev-images   (this repo)
         └── dev-images-agent: image-maintainer-dev-images          (this repo)
```

`guidance/overview.md` is reference context (image set, build commands, CI state) shared by both
personas — not part of either inheritance chain.

## Tasks

`tasks/*.md` are work specs following `common-agent/guidance/task-model.md`: each declares a
desired state the `owner` Agent CR reconciles toward, with an append-only status log. Active
tasks are pinned in the owning CR's `config.instructions`; spec changes land here as PRs.

The agent set in the `dev-images-agent` namespace uses **persona-qualified CR names**
(`dev-images-<persona>-<n>-<model-slug>`): one `image-developer` agent and two
`image-maintainer` agents whose duties differ by task ownership (daily candidate channel vs.
weekly release), per `common-agent`'s image-maintainer channel guidance. The legacy
generalist `dev-images-1-qwen-local-1` (both personas pinned) remains until decommissioned.

| Task | Owner | Status |
|------|-------|--------|
| `tasks/devbox.md` | `dev-images-image-developer-1-qwen-local-1` | active (build/publish gated on ci-channel) |
| `tasks/devbox-claude.md` | `dev-images-image-developer-1-qwen-local-1` | active (depends on devbox; gated on ci-channel) |
| `tasks/ci-channel.md` | `dev-images-image-maintainer-1-qwen-local-1` | active (build out + prove the CI channel) |
| `tasks/image-candidate-channel.md` | `dev-images-image-maintainer-1-qwen-local-1` | active (curate the CI daily/candidate channel) |
| `tasks/image-weekly-release.md` | `dev-images-image-maintainer-2-qwen-local-1` | active (oversee the automatic weekly release) |

## Out of scope

`mattr7m/dev-images` carries its own `AGENTS.md` and `CLAUDE.md` aimed at agents operating *inside*
the repo (the project's own developer onboarding). Those are separate from this agent's guidance.
Don't edit them from here.
