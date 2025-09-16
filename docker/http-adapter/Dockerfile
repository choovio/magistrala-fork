# Copyright (c) Abstract Machines
# SPDX-License-Identifier: Apache-2.0

# ---- builder ----
FROM golang:1.24-alpine AS builder

# Build args (optional)
ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0

WORKDIR /src
RUN apk add --no-cache build-base git upx

# Bring the whole repo as context; avoid brittle COPY order
COPY . .

# Prefer Make if present; otherwise search common main paths
RUN set -eux; \
    if grep -qE '^\s*http-adapter\s*:' Makefile 2>/dev/null; then \
        make http-adapter; \
        test -f build/http-adapter; \
        cp build/http-adapter /exe; \
    else \
        for p in ./cmd/http-adapter ./http-adapter ./cmd/http ./services/http-adapter; do \
            if [ -f "$p/main.go" ] || [ -d "$p" ]; then \
                GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED="$CGO_ENABLED" \
                  go build -trimpath -ldflags="-s -w" -o /exe "$p"; \
                break; \
            fi; \
        done; \
        test -x /exe; \
    fi; \
    upx /exe || true

# ---- runtime ----
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H -u 10001 app
USER 10001:10001
WORKDIR /
COPY --from=builder /exe /exe
ENTRYPOINT ["/exe"]
