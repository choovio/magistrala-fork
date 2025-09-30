# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

# syntax=docker/dockerfile:1.7

FROM golang:1.24.5-bookworm AS builder
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown
ENV GO111MODULE=on CGO_ENABLED=0 GOTOOLCHAIN=auto
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd/lora ./cmd/lora
COPY pkg/lora ./pkg/lora
RUN go list ./cmd/lora
RUN go build -trimpath -buildvcs=false \
  -ldflags="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.buildDate=${BUILD_DATE}" \
  -o /out/lora ./cmd/lora

FROM gcr.io/distroless/base-debian12:nonroot AS runtime
ENV PORT=8080
EXPOSE 8080
COPY --from=builder /out/lora /app/lora
USER nonroot:nonroot
ENTRYPOINT ["/app/lora"]
