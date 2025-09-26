#!/usr/bin/env bash
set -euo pipefail

# 1) Read intended digests from repo
if [ ! -d magistrala-fork ]; then
  git clone https://github.com/choovio/magistrala-fork.git
fi
cd magistrala-fork && git fetch origin && git checkout main && git pull --rebase

HTTP_IMG="$(yq -r '.spec.template.spec.containers[0].image' ops/sbx/http.yaml)"
WS_IMG="$(yq -r   '.spec.template.spec.containers[0].image' ops/sbx/ws.yaml)"

echo "INTENDED http: $HTTP_IMG"
echo "INTENDED ws  : $WS_IMG"

# 2) Force update live deployments to those images
kubectl -n magistrala set image deploy/http http="$HTTP_IMG"
kubectl -n magistrala set image deploy/ws   ws="$WS_IMG"

# 3) Nuke old ReplicaSets to avoid stale pods (safe; deployments recreate them)
kubectl -n magistrala delete rs -l app=http --ignore-not-found
kubectl -n magistrala delete rs -l app=ws   --ignore-not-found

# 4) Wait for successful rollouts
kubectl -n magistrala rollout status deploy/http --timeout=180s
kubectl -n magistrala rollout status deploy/ws   --timeout=180s

# 5) Show final live images
echo "LIVE http: $(kubectl -n magistrala get deploy http -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "LIVE ws  : $(kubectl -n magistrala get deploy ws   -o jsonpath='{.spec.template.spec.containers[0].image}')"
