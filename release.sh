#!/usr/bin/env bash
set -euxo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

release_tag="${1:-""}"
commit="${2:-"origin/main"}"

if [[ -z "${release_tag}" ]]; then
  release_tag=$(date -u "+v%y.%m.%d" | sed 's/\.0*/./g; s/v0*/v/')
fi

if [[ ! "${release_tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]; then
  printf "error: tag '%s' must be vX.Y.Z with an optional -suffix\n" "${release_tag}" >&2
  exit 1
fi

git fetch --all --tags --prune --prune-tags

if [[ -z "$(git tag --list "${release_tag}")" ]]; then
  git tag "${release_tag}" "${commit}"
  git push origin "${release_tag}"
fi

git checkout --detach "${release_tag}"
git reset --hard "${release_tag}"
git clean -fdx

# Make sure git describe always generates the same release tag.
git_tag="$(git describe --tags --always --dirty)"
if [[ "${git_tag}" != "${release_tag}" ]]; then
  printf "error: git tag '%s' does not match release tag '%s'\n" "${git_tag}" "${release_tag}" >&2
  exit 1
fi

nd check

build_target="//seed/devprod/ndscm/cli"

platforms=(
  "darwin amd64"
  "darwin arm64"
  "linux amd64"
  "linux arm64"
)

mkdir -p "./.cache/release"

for platform in "${platforms[@]}"; do
  read -r kernel arch <<<"${platform}"
  platform_toolchain="@rules_go//go/toolchain:${kernel}_${arch}"

  bazel build --stamp --platforms="${platform_toolchain}" "${build_target}"
  executable="$(bazel cquery --platforms="${platform_toolchain}" "${build_target}" --output=files)"

  tar czvf "./.cache/release/ndscm-${kernel}-${arch}.tar.gz" -C "$(dirname "${executable}")" "$(basename "${executable}")"
done

# Publish the GitHub release and attach every built artifact. If the release
# already exists, leave it untouched and exit.
if gh release view "${release_tag}" >/dev/null 2>&1; then
  printf "release '%s' already exists, nothing to do\n" "${release_tag}"
  exit 0
fi

gh release create "${release_tag}" ./.cache/release/* \
  --title "${release_tag}" \
  --notes "" \
  --draft

# The GitHub release is staged as a draft, so leave the final publish step to
# the user once they've reviewed the draft.
printf "\ndraft release '%s' created. to finish publishing, run:\n" "${release_tag}"
printf "  gh release edit '%s' --draft=false\n" "${release_tag}"
