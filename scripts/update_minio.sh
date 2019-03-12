#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cd "$( dirname "${BASH_SOURCE[0]}" )/.."

go install github.com/krishicks/yaml-patch

minio_url_prefix="https://dl.minio.io/server/minio/release/linux-amd64"
mc_url_prefix="https://dl.minio.io/client/mc/release/linux-amd64"

declare -a minio_shasum=(`curl -s $minio_url_prefix/minio.sha256sum`)
declare -a mc_shasum=(`curl -s $mc_url_prefix/mc.sha256sum`)

minio_url="$minio_url_prefix/archive/${minio_shasum[1]}"
minio_sha256="${minio_shasum[0]}"

mc_url="$mc_url_prefix/archive/${mc_shasum[1]}"
mc_sha256="${mc_shasum[0]}"

original_manifest_content=$(cat manifest.yml)

ops_file_content=$(cat <<EOF
- op: replace
  path: /dependencies/name=minio/uri
  value: "$minio_url#suffix=.sh"
- op: replace
  path: /dependencies/name=minio/sha256
  value: $minio_sha256
- op: replace
  path: /dependencies/name=mc/uri
  value: "$mc_url#suffix=.sh"
- op: replace
  path: /dependencies/name=mc/sha256
  value: $mc_sha256
EOF
)

yaml-patch --ops-file <(echo "$ops_file_content") < <(echo "$original_manifest_content") > manifest.yml
