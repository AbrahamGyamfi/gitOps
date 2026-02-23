#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:?Usage: build-image.sh <image-name> <image-tag> <context-dir>}"
IMAGE_TAG="${2:?Usage: build-image.sh <image-name> <image-tag> <context-dir>}"
CONTEXT_DIR="${3:?Usage: build-image.sh <image-name> <image-tag> <context-dir>}"

echo "Building ${IMAGE_NAME}:${IMAGE_TAG} from ${CONTEXT_DIR}..."
docker build \
    --pull \
    --cache-from "${IMAGE_NAME}:latest" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_NUMBER="${BUILD_NUMBER:-local}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -t "${IMAGE_NAME}:latest" \
    "${CONTEXT_DIR}"
