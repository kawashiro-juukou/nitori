#!/usr/bin/env bash
# Release helper: compare local pubspec versions against the latest published
# versions on pub.dev. For every package whose local version is newer, create
# an annotated tag <package>-v<version> on HEAD and push it. The tags are what
# pub.dev's trusted publishing is bound to, so they must exist before the
# publish workflow runs.
#
# Called by .github/workflows/release.yml. Run with RELEASE_DRY_RUN=1 to only
# print what would be tagged.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

DRY_RUN="${RELEASE_DRY_RUN:-0}"

# semver compare: $1 > $2
version_gt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | tail -n1)" = "$1" ]
}

# latest published version on pub.dev; empty if never published
pub_dev_latest() {
  local pkg="$1"
  curl -fsS --max-time 20 "https://pub.dev/api/packages/$pkg" 2>/dev/null \
    | python3 -c 'import sys, json; print(json.load(sys.stdin)["latest"]["version"])' || true
}

tagged=()
tag_names=()
for spec in pkgs/*/pubspec.yaml; do
  name="$(grep -m1 '^name:' "$spec" | awk '{print $2}')"
  version="$(grep -m1 '^version:' "$spec" | awk '{print $2}')"
  latest="$(pub_dev_latest "$name")"
  tag="$name-v$version"

  # skip if already published or the tag already exists upstream
  if [ -n "$latest" ] && ! version_gt "$version" "$latest"; then
    echo "skip  $name $version (published: ${latest:-none})"
    continue
  fi
  if git ls-remote --tags origin "$tag" | grep -q "$tag"; then
    echo "skip  $name $version (tag $tag already exists)"
    continue
  fi

  # pub.dev wants the version listed in CHANGELOG.md
  if ! grep -q "^## $version" "pkgs/$name/CHANGELOG.md" 2>/dev/null; then
    echo "FAIL  $name $version: CHANGELOG.md has no '## $version' entry" >&2
    exit 1
  fi

  echo "tag   $name $version -> $tag"
  if [ "$DRY_RUN" = "1" ]; then
    continue
  fi

  git tag -a "$tag" -m "$tag" HEAD
  git push origin "$tag"
  tagged+=("$name $version")
  tag_names+=("$tag")
done

echo "---"
if [ "${#tagged[@]}" -gt 0 ]; then
  printf '%s\n' "${tagged[@]}"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf 'tags=%s\n' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1].split()))' "${tag_names[*]}")" >> "$GITHUB_OUTPUT"
  fi
fi