#!/usr/bin/env bash
set +e

if [ -n "${BACKEND_IMAGE:-}" ] && [ -n "${IMAGE_TAG:-}" ]; then
    docker image rm -f "${BACKEND_IMAGE}:${IMAGE_TAG}" >/dev/null 2>&1
fi

if [ -n "${FRONTEND_IMAGE:-}" ] && [ -n "${IMAGE_TAG:-}" ]; then
    docker image rm -f "${FRONTEND_IMAGE}:${IMAGE_TAG}" >/dev/null 2>&1
fi
