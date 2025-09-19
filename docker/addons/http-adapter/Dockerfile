# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 CHOOVIO Inc.
# SPDX-License-Identifier: MIT

# Multi-stage build for Magistrala HTTP adapter (self-contained, no upstream images)

# ---- build stage ----
FROM golang:1.22-alpine AS build
WORKDIR /src

# System deps (git for modules). upx is optional; we won't fail if it can't compress.
RUN apk add --no-cache git upx

# Copy whole repo (monorepo layout; http adapter lives under ./cmd/http)
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags "-s -w" -o /exe ./cmd/http \
 && { upx /exe || true; }

# ---- runtime stage ----
FROM alpine:3.20
# Create nonroot user
RUN adduser -D -H -u 10001 app
USER 10001

# HTTP adapter typically listens on 8080
EXPOSE 8080

# Minimal root filesystem
COPY --from=build /exe /exe

ENTRYPOINT ["/exe"]
