# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

# Multi-stage build for Magistrala WebSocket adapter (self-contained, no upstream images)

# ---- build stage ----
FROM golang:1.22-alpine AS build
WORKDIR /src
RUN apk add --no-cache git upx
COPY . .

# Build static binary for ./cmd/ws
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags "-s -w" -o /exe ./cmd/ws \
 && { upx /exe || true; }

# ---- runtime stage ----
FROM alpine:3.20
RUN adduser -D -H -u 10001 app
USER 10001

# WS adapter also serves on 8080 by default
EXPOSE 8080
COPY --from=build /exe /exe
ENTRYPOINT ["/exe"]
