#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cd "$( dirname "${BASH_SOURCE[0]}" )/.."

go get github.com/krishicks/yaml-patch/...

go build -o yaml_patch_linux src/github.com/krishicks/yaml-patch/cmd/yaml-patch/*.go

tmpdir=$(mktemp -d)
tmpops=$(mktemp $tmpdir/XXX)
trap "rm -r $tmpdir" EXIT

minio_url_prefix="https://dl.minio.io/server/minio/release/linux-amd64"
mc_url_prefix="https://dl.minio.io/client/mc/release/linux-amd64"

declare -a minio_shasum=(`curl -s $minio_url_prefix/minio.sha256sum`)
declare -a mc_shasum=(`curl -s $mc_url_prefix/mc.sha256sum`)

minio_url="$minio_url_prefix/archive/${minio_shasum[1]}"
minio_sha256="${minio_shasum[0]}"

mc_url="$mc_url_prefix/archive/${mc_shasum[1]}"
mc_sha256="${mc_shasum[0]}"

cat > $tmpops <<EOF
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

yaml-patch --ops-file $tmpops < manifest.yml > manifest.yml.new
