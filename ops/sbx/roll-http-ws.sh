#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.

set -euo pipefail

# Read intended digests from repo
HTTP_IMG="$(yq -r '.spec.template.spec.containers[0].image' ops/sbx/http.yaml)"
WS_IMG="$(yq -r   '.spec.template.spec.containers[0].image' ops/sbx/ws.yaml)"

echo "INTENDED http: $HTTP_IMG"
echo "INTENDED ws  : $WS_IMG"

# Force update live deployments to those images
kubectl -n magistrala set image deploy/http http="$HTTP_IMG"
kubectl -n magistrala set image deploy/ws   ws="$WS_IMG"

# Remove any stale ReplicaSets
kubectl -n magistrala delete rs -l app=http --ignore-not-found
kubectl -n magistrala delete rs -l app=ws   --ignore-not-found

# Wait for rollouts
kubectl -n magistrala rollout status deploy/http --timeout=180s
kubectl -n magistrala rollout status deploy/ws   --timeout=180s

# Show final images
echo "LIVE http: $(kubectl -n magistrala get deploy http -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "LIVE ws  : $(kubectl -n magistrala get deploy ws   -o jsonpath='{.spec.template.spec.containers[0].image}')"
