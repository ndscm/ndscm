#!/usr/bin/env bash
set -euxo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

release_tag="${1:-""}"
commit="${2:-"origin/main"}"

if [[ -z "${release_tag}" ]]; then
  release_tag=$(date -u "+v%y.%m.%d" | sed 's/\.0*/./g; s/v0*/v/')
fi

git fetch --all --tags --prune --prune-tags

if [[ -z "$(git tag --list "${release_tag}")" ]]; then
  git tag "${release_tag}" "${commit}"
  git push origin "${release_tag}"
fi

git checkout --detach "${release_tag}"
git reset --hard "${release_tag}"
git clean -fdx

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
