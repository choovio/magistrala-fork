#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.
set -euo pipefail

# This script builds the LoRa adapter image from this repository and pushes it to AWS ECR.
# It mirrors the manual steps described in the user workflow and requires AWS CLI, Docker,
# and access to the specified AWS account/region.

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <aws-account-id> <aws-region> <repository-name>" >&2
  exit 64
fi

AWS_ACC=$1
AWS_REGION=$2
REPO=$3

# Ensure ECR repository exists
if ! aws ecr describe-repositories --repository-name "${REPO}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name "${REPO}" --region "${AWS_REGION}" >/dev/null
fi

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com"

TAG="lora-$(git rev-parse --short HEAD)"
IMAGE="${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}:${TAG}"

if [[ ! -f adapters/lora/Dockerfile ]]; then
  echo "Expected adapters/lora/Dockerfile to exist" >&2
  exit 66
fi

docker build -t "${IMAGE}" adapters/lora
docker push "${IMAGE}"

DIGEST=$(aws ecr describe-images --repository-name "${REPO}" --region "${AWS_REGION}" \
  --image-ids imageTag="${TAG}" --query 'imageDetails[0].imageDigest' --output text)

cat <<RESULTS
========== RESULTS ==========
ENV.REPO : SBX.magistrala-fork
PUSHED   : ${IMAGE}
DIGEST   : ${DIGEST}
FULL     : ${AWS_ACC}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}@${DIGEST}
========== RESULTS ==========
RESULTS
