# Copyright (c) Abstract Machines
# SPDX-License-Identifier: Apache-2.0

FROM golang:1.24-alpine AS builder
ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0
ARG MAIN=""   # e.g., ./cmd/ws-adapter

WORKDIR /src
RUN apk add --no-cache build-base git upx
COPY . .

RUN set -eux; \
    if [ -n "$MAIN" ]; then \
      GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED="$CGO_ENABLED" go build -trimpath -ldflags="-s -w" -o /exe "$MAIN"; \
    elif grep -qE '^\s*ws-adapter\s*:' Makefile 2>/dev/null; then \
      make ws-adapter; test -f build/ws-adapter; cp build/ws-adapter /exe; \
    else \
      for p in ./cmd/ws-adapter ./ws-adapter ./cmd/ws ./services/ws-adapter; do \
        if [ -f "$p/main.go" ] || [ -d "$p" ]; then \
          GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED="$CGO_ENABLED" go build -trimpath -ldflags="-s -w" -o /exe "$p"; \
          break; \
        fi; \
      done; \
    fi; \
    test -x /exe; upx /exe || true

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H -u 10001 app
USER 10001:10001
WORKDIR /
COPY --from=builder /exe /exe
ENTRYPOINT ["/exe"]
