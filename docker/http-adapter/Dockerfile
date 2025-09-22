# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

FROM golang:1.24-alpine AS builder
ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0
ARG MAIN=""   # optional, e.g. ./cmd/http-adapter

WORKDIR /src
RUN apk add --no-cache build-base git upx
COPY . .

# Build strategy:
# 1) If MAIN is set, build that.
# 2) Else if Makefile has 'http-adapter', run it and copy the binary.
# 3) Else probe common locations.
RUN set -eux; \
  if [ -n "$MAIN" ]; then \
    GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED="$CGO_ENABLED" go build -trimpath -ldflags="-s -w" -o /exe "$MAIN"; \
  elif [ -f Makefile ] && grep -qE '^[[:space:]]*http-adapter[[:space:]]*:' Makefile; then \
    make http-adapter; test -f build/http-adapter; cp build/http-adapter /exe; \
  else \
    for p in ./cmd/http-adapter ./http-adapter ./cmd/http ./services/http-adapter; do \
      if [ -f "$p/main.go" ] || [ -d "$p" ]; then \
        GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED="$CGO_ENABLED" go build -trimpath -ldflags="-s -w" -o /exe "$p"; \
        break; \
      fi; \
    done; \
    test -x /exe; \
  fi; \
  upx /exe || true

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H -u 10001 app
USER 10001:10001
WORKDIR /
COPY --from=builder /exe /exe
ENTRYPOINT ["/exe"]
