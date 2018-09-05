#!/bin/bash
set -euo pipefail

MINIO_VERSION="RELEASE.2018-09-01T00-38-25Z"
export MinioInstallDir=$1

if [ ! -f $MinioInstallDir/minio ]; then
MINIO_SHA256="6bb7534ab5837d263a107ed3d7c17f63845a4d4e1b7fe2f68f41ee8f502f9353"

URL=https://dl.minio.io/server/minio/release/linux-amd64/archive/minio.$MINIO_VERSION

echo "-----> Download minio ${MINIO_VERSION}"
curl -s -L --retry 15 --retry-delay 2 $URL -o /tmp/minio

DOWNLOAD_SHA256=$(shasum -a256 /tmp/minio | cut -d ' ' -f 1)
if [[ $DOWNLOAD_SHA256 != $MINIO_SHA256 ]]; then
echo "       **ERROR** SHA256 mismatch: got $DOWNLOAD_SHA256 expected $MINIO_SHA256"
exit 1
fi

mv /tmp/minio $MinioInstallDir/minio
chmod +x $MinioInstallDir/minio
fi
if [ ! -f $MinioInstallDir/minio ]; then
echo "       **ERROR** Could not download minio"
exit 1
fi
