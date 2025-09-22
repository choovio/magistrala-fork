# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

FROM golang:1.24-alpine AS builder
ARG GOOS=linux
ARG GOARCH=amd64
ARG CGO_ENABLED=0
ARG MAIN

WORKDIR /src
RUN apk add --no-cache build-base git upx
COPY . .

# MAIN is mandatory — we pass it from the workflow after go-list discovery
RUN test -n "$MAIN"
RUN set -eux; GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED="$CGO_ENABLED" \
    go build -trimpath -ldflags="-s -w" -o /exe "$MAIN"; \
    upx /exe || true

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H -u 10001 app
USER 10001:10001
WORKDIR /
COPY --from=builder /exe /exe
ENTRYPOINT ["/exe"]
