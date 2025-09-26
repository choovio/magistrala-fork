#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.

set -euo pipefail

# Resolve repository root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

# Read intended digests from repo without yq
grep_image() {
  local manifest_path="$1"
  grep -E '^[[:space:]]*image:[[:space:]]' "${manifest_path}" | head -1 | awk '{print $2}'
}

HTTP_MANIFEST="ops/sbx/http.yaml"
WS_MANIFEST="ops/sbx/ws.yaml"

HTTP_IMG="$(grep_image "${HTTP_MANIFEST}")"
WS_IMG="$(grep_image "${WS_MANIFEST}")"

if [[ -z "${HTTP_IMG}" || -z "${WS_IMG}" ]]; then
  echo "Failed to determine intended images" >&2
  exit 1
fi

echo "INTENDED http: ${HTTP_IMG}"
echo "INTENDED ws  : ${WS_IMG}"

# Apply manifests to ensure resources are present
kubectl -n magistrala apply -f "${HTTP_MANIFEST}"
kubectl -n magistrala apply -f "${WS_MANIFEST}"

# Force update live deployments to those images
kubectl -n magistrala set image deploy/http "http=${HTTP_IMG}"
kubectl -n magistrala set image deploy/ws   "ws=${WS_IMG}"

# Remove any stale ReplicaSets
kubectl -n magistrala delete rs -l app=http --ignore-not-found
kubectl -n magistrala delete rs -l app=ws   --ignore-not-found

# Wait for rollouts
kubectl -n magistrala rollout status deploy/http --timeout=180s
kubectl -n magistrala rollout status deploy/ws   --timeout=180s

# Show final images
LIVE_HTTP="$(kubectl -n magistrala get deploy http -o jsonpath='{.spec.template.spec.containers[0].image}')"
LIVE_WS="$(kubectl -n magistrala get deploy ws   -o jsonpath='{.spec.template.spec.containers[0].image}')"

echo "LIVE http: ${LIVE_HTTP}"
echo "LIVE ws  : ${LIVE_WS}"

if [[ "${LIVE_HTTP}" != "${HTTP_IMG}" ]]; then
  echo "http deployment image mismatch" >&2
  exit 1
fi

if [[ "${LIVE_WS}" != "${WS_IMG}" ]]; then
  echo "ws deployment image mismatch" >&2
  exit 1
fi
