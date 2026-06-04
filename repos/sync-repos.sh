#!/usr/bin/env bash
# Shallow, read-only clone/update of every repo listed in repos.yaml into repos/<owner>/<name>.
# Requires: git, and a YAML reader. Uses `yq` if present, else a minimal grep fallback.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
yaml="${here}/repos.yaml"

# Emit "owner/name" for every `repo:` entry under any category/owner.
list_repos() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.repos[][][] | .repo' "$yaml"
  else
    grep -E '^\s*-\s*repo:\s*' "$yaml" | sed -E 's/^\s*-\s*repo:\s*//'
  fi
}

while read -r slug; do
  [ -n "$slug" ] || continue
  dest="${here}/${slug}"
  if [ -d "${dest}/.git" ]; then
    echo "updating ${slug}"
    git -C "${dest}" fetch --depth 1 origin
    git -C "${dest}" reset --hard '@{upstream}'
  else
    echo "cloning ${slug}"
    mkdir -p "$(dirname "${dest}")"
    git clone --depth 1 "https://github.com/${slug}.git" "${dest}"
  fi
done < <(list_repos)
