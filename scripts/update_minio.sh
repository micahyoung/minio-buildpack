#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cd "$( dirname "${BASH_SOURCE[0]}" )/.."

go install github.com/krishicks/yaml-patch

minio_url_prefix="https://dl.minio.io/server/minio/release"
mc_url_prefix="https://dl.minio.io/client/mc/release/linux-amd64"

declare -a minio_linux_shasum=(`curl -s $minio_url_prefix/linux-amd64/minio.sha256sum`)
declare -a minio_windows_shasum=(`curl -s $minio_url_prefix/windows-amd64/minio.exe.sha256sum`)
declare -a mc_shasum=(`curl -s $mc_url_prefix/mc.sha256sum`)

minio_linux_url="$minio_url_prefix/linux-amd64/archive/${minio_linux_shasum[1]}"
minio_linux_sha256="${minio_linux_shasum[0]}"
minio_windows_url="$minio_url_prefix/windows-amd64/archive/${minio_windows_shasum[1]}"
minio_windows_sha256="${minio_windows_url[0]}"

mc_url="$mc_url_prefix/archive/${mc_shasum[1]}"
mc_sha256="${mc_shasum[0]}"

original_manifest_content=$(cat manifest.yml)

ops_file_content=$(cat <<EOF
- op: replace
  path: /dependencies/name=minio-linux/uri
  value: "$minio_linux_url#suffix=.sh"
- op: replace
  path: /dependencies/name=minio-linux/sha256
  value: $minio_linux_sha256
- op: replace
  path: /dependencies/name=minio-windows/uri
  value: "$minio_windows_url#suffix=.sh"
- op: replace
  path: /dependencies/name=minio-windows/sha256
  value: $minio_windows_sha256
- op: replace
  path: /dependencies/name=mc/uri
  value: "$mc_url#suffix=.sh"
- op: replace
  path: /dependencies/name=mc/sha256
  value: $mc_sha256
EOF
)

yaml-patch --ops-file <(echo "$ops_file_content") < <(echo "$original_manifest_content") > manifest.yml
