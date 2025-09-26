#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-magistrala}

if [[ -t 1 ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  RESET=""
fi

info() {
  echo -e "${BLUE}$*${RESET}"
}

highlight_line() {
  local color=$1
  shift
  echo -e "${color}$*${RESET}"
}

get_json_field() {
  local value=${1-}
  if [[ -z $value ]]; then
    echo 0
  else
    echo "$value"
  fi
}

info "== Deployments ==="
mapfile -t DEPLOYMENTS < <(kubectl -n "$NS" get deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)

if [[ ${#DEPLOYMENTS[@]} -eq 0 ]]; then
  echo "No deployments found in namespace '$NS'."
else
  for d in "${DEPLOYMENTS[@]}"; do
    image=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.template.spec.containers[0].image}')
    ready=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.status.readyReplicas}')
    desired=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.replicas}')

    ready=$(get_json_field "$ready")
    desired=$(get_json_field "$desired")

    line="$d | image=${image:-<none>} | ready=$ready/$desired"

    if [[ "$desired" == "0" ]]; then
      highlight_line "$YELLOW" "$line (scaled down)"
    elif [[ "$ready" == "$desired" ]]; then
      highlight_line "$GREEN" "$line"
    else
      highlight_line "$RED" "$line"
    fi
  done
fi

echo
info "== Pods (conditions) =="
mapfile -t PODS < <(kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)

if [[ ${#PODS[@]} -eq 0 ]]; then
  echo "No pods found in namespace '$NS'."
else
  printf "%-55s %-10s %-7s %-8s %-s\n" "NAME" "PHASE" "READY" "RESTARTS" "STATUS"
  printf '%0.s-' {1..120}
  echo

  for pod in "${PODS[@]}"; do
    if ! pod_json=$(kubectl -n "$NS" get pod "$pod" -o json 2>/dev/null); then
      highlight_line "$YELLOW" "Failed to fetch details for pod/$pod"
      continue
    fi
    POD_JSON="$pod_json" python3 - "$pod" "$RED" "$GREEN" "$YELLOW" "$RESET" <<'PY'
import json
import os
import sys

pod_json = json.loads(os.environ["POD_JSON"])
pod_name = sys.argv[1]
red = sys.argv[2]
green = sys.argv[3]
yellow = sys.argv[4]
reset = sys.argv[5]

phase = pod_json.get("status", {}).get("phase", "unknown")
container_statuses = pod_json.get("status", {}).get("containerStatuses", [])
restarts = sum(cs.get("restartCount", 0) for cs in container_statuses)
ready_total = len(container_statuses)
ready_count = sum(1 for cs in container_statuses if cs.get("ready"))

status_fragments = []
for cs in container_statuses:
    name = cs.get("name")
    ready = cs.get("ready")
    state = cs.get("state", {})
    detail = ""
    if "waiting" in state:
        wait = state["waiting"]
        reason = wait.get("reason") or "waiting"
        message = wait.get("message")
        detail = f"{reason}: {message}" if message else reason
    elif "terminated" in state:
        term = state["terminated"]
        reason = term.get("reason") or "terminated"
        message = term.get("message")
        detail = f"{reason}: {message}" if message else reason
    elif "running" in state:
        run = state["running"]
        started = run.get("startedAt")
        detail = f"running since {started}" if started else "running"

    readiness = "ready" if ready else "not-ready"
    status_fragments.append(f"{name}={readiness} ({detail})")

status_text = "; ".join(status_fragments) if status_fragments else "no container status"

ready_str = f"{ready_count}/{ready_total}" if ready_total else "0/0"
row = f"{pod_name:<55} {phase:<10} {ready_str:<7} {restarts:<8} {status_text}"

if ready_total == 0:
    color = yellow
elif ready_count == ready_total:
    color = green
else:
    color = red

print(f"{color}{row}{reset}")
PY
  done
fi

echo
info "== NotReady pod reasons =="
mapfile -t NOT_READY_PODS < <(kubectl -n "$NS" get pods --no-headers 2>/dev/null | awk '{split($2,a,"/"); if (a[1] != a[2]) print $1}')

if [[ ${#NOT_READY_PODS[@]} -eq 0 ]]; then
  echo "All pods are ready."
else
  for pod in "${NOT_READY_PODS[@]}"; do
    highlight_line "$RED" "-- $pod"
    if ! kubectl -n "$NS" describe pod "$pod" 2>/dev/null | sed -n '/Events:/,$p'; then
      echo "Failed to describe pod/$pod" >&2
    fi
  done
fi

echo
info "== Tail logs (last 100 lines) for failing pods =="

if [[ ${#NOT_READY_PODS[@]} -eq 0 ]]; then
  echo "No failing pods to tail logs for."
else
  for pod in "${NOT_READY_PODS[@]}"; do
    highlight_line "$RED" "-- logs: pod/$pod"
    if ! kubectl -n "$NS" logs "$pod" --all-containers --tail=100; then
      echo "Failed to retrieve logs for pod/$pod" >&2
    fi
    echo
  done
fi
