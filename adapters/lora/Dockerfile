# SPDX-License-Identifier: Apache-2.0
# Copyright (c) CHOOVIO Inc.

# syntax=docker/dockerfile:1.7
FROM golang:1.24.5-bookworm AS builder
WORKDIR /src

# module files (adapter only)
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# source
COPY cmd/lora ./cmd/lora
COPY pkg/lora ./pkg/lora

# ensure sums are generated for module; safe with empty deps
RUN --mount=type=cache,target=/root/.cache/go-build go mod tidy

# build
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -buildvcs=false -o /out/lora ./cmd/lora

FROM gcr.io/distroless/base-debian12:nonroot
COPY --from=builder /out/lora /usr/local/bin/lora
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/lora"]
