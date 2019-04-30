#!/usr/bin/env bash
set -exuo pipefail

cd "$( dirname "${BASH_SOURCE[0]}" )/.."
source .envrc

GOOS=linux go build -mod=vendor -ldflags="-s -w" -o bin/supply minio/supply/cli
GOOS=linux go build -mod=vendor -ldflags="-s -w" -o bin/finalize minio/finalize/cli
