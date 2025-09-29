#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.

set -euo pipefail
AWS_ACC="595443389404"
AWS_REGION="us-west-2"
REPO_URL="https://github.com/choovio/magistrala-fork.git"
WORKDIR="magistrala-fork"
ECR_REPO="lora"

# Source image to mirror (explicit to avoid prompting). Update later if you switch upstream.
SRC_IMAGE="ghcr.io/mainfluxlabs/lora:latest"

# 0) ECR login
aws ecr get-login-password --region "$AWS_REGION" \
| docker login --username AWS --password-stdin "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 1) Mirror LoRa image → ECR and get digest
docker pull "$SRC_IMAGE"
docker tag  "$SRC_IMAGE" "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:tmp"
docker push "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:tmp"
DIGEST="$(aws ecr describe-images --repository-name "${ECR_REPO}" --image-ids imageTag=tmp --region "${AWS_REGION}" --query 'imageDetails[0].imageDigest' --output text)"
PINNED="${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}@${DIGEST}"

# 2) Sync repo and ensure compliant manifest
[ -d "$WORKDIR" ] || git clone "$REPO_URL" "$WORKDIR"
cd "$WORKDIR"
git fetch origin
git checkout main
git pull --rebase
mkdir -p ops/sbx

cat > ops/sbx/lora.yaml <<'YAML'
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lora
  namespace: magistrala
spec:
  replicas: 1
  selector:
    matchLabels: { app: lora }
  template:
    metadata:
      labels: { app: lora }
    spec:
      containers:
        - name: lora
          image: REPLACE_ME_WITH_ECR_DIGEST
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: CHIRPSTACK_API_URL
              value: "https://lns.gobee.io"
            - name: MAGISTRALA_MQTT_URL
              value: "mqtt://nats.magistrala.svc.cluster.local:1883"
            - name: CHIRPSTACK_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: chirpstack-secrets
                  key: apiToken
          readinessProbe:
            httpGet: { path: /health, port: http }
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet: { path: /health, port: http }
            initialDelaySeconds: 10
            periodSeconds: 20
            timeoutSeconds: 2
            failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: lora
  namespace: magistrala
spec:
  selector: { app: lora }
  ports:
    - name: http
      port: 8080
      targetPort: http
YAML

# Pin image
sed -i.bak -E "s#REPLACE_ME_WITH_ECR_DIGEST#${PINNED}#g" ops/sbx/lora.yaml
rm -f ops/sbx/lora.yaml.bak

# 3) Apply + rollout
kubectl -n magistrala apply -f ops/sbx/lora.yaml
kubectl -n magistrala rollout status deploy/lora --timeout=180s

# 4) Print live state
echo "LIVE lora image: $(kubectl -n magistrala get deploy lora -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "READINESS       : $(kubectl -n magistrala get deploy lora -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}'):"\
"$(kubectl -n magistrala get deploy lora -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')"
