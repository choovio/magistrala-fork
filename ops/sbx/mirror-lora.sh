#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.

set -euo pipefail

AWS_ACC="${AWS_ACC:-595443389404}"
AWS_REGION="${AWS_REGION:-us-west-2}"
: "${SRC_IMAGE:?Set SRC_IMAGE to the LoRa adapter you want to mirror}"

WORKDIR="${WORKDIR:-magistrala-fork}"
REPO_URL="${REPO_URL:-https://github.com/choovio/magistrala-fork.git}"
ECR_REPO="lora"

aws ecr get-login-password --region "$AWS_REGION" \
| docker login --username AWS --password-stdin "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com"
docker pull "$SRC_IMAGE"
docker tag  "$SRC_IMAGE" "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:tmp"
docker push "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:tmp"

DIGEST="$(aws ecr describe-images \
  --repository-name "${ECR_REPO}" \
  --image-ids imageTag=tmp \
  --region "${AWS_REGION}" \
  --query 'imageDetails[0].imageDigest' --output text)"
IMG="${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}@${DIGEST}"

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

sed -i.bak -E "s#REPLACE_ME_WITH_ECR_DIGEST#${IMG}#g" ops/sbx/lora.yaml
rm -f ops/sbx/lora.yaml.bak

kubectl -n magistrala apply -f ops/sbx/lora.yaml
kubectl -n magistrala rollout status deploy/lora --timeout=180s

echo "LIVE lora image: $(kubectl -n magistrala get deploy lora -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "READINESS       : $(kubectl -n magistrala get deploy lora -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}'):"\
"$(kubectl -n magistrala get deploy lora -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')"
