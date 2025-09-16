# Copyright (c) Abstract Machines
# SPDX-FileCopyrightText: 2025 CHOOVIO Inc.
# SPDX-License-Identifier: MIT

# ---- builder ----
FROM golang:1.22-alpine AS builder
ARG SVC="http-adapter"
ARG BIN_PATH="build/${SVC}"
WORKDIR /src

# toolchain + upx
RUN apk add --no-cache build-base upx

# cache-friendly go env
ENV CGO_ENABLED=0 GO111MODULE=on

# Copy Go module files from the *root* of the repo (requires build context = repo root)
# go.sum may or may not exist; the wildcard makes it optional.
COPY go.mod go.sum* ./
RUN go mod download

# copy the rest of the repo
COPY . .

# Try make target if it exists; otherwise build from common cmd paths.
RUN set -eux; \
  if [ -f Makefile ] && grep -qE "^[[:space:]]*${SVC}:" Makefile; then \
      make "${SVC}"; \
      test -f "${BIN_PATH}" || (echo "Expected ${BIN_PATH} after make" && exit 2); \
  else \
      mkdir -p build; \
      if [ -d "./cmd/${SVC}" ]; then \
          go build -trimpath -ldflags="-s -w" -o "${BIN_PATH}" "./cmd/${SVC}"; \
      elif [ -d "./${SVC}/cmd" ]; then \
          go build -trimpath -ldflags="-s -w" -o "${BIN_PATH}" "./${SVC}/cmd"; \
      elif [ -d "./cmd/http" ]; then \
          go build -trimpath -ldflags="-s -w" -o "${BIN_PATH}" "./cmd/http"; \
      else \
          echo "No build target or cmd path found for ${SVC}"; exit 3; \
      fi; \
  fi; \
  # optional compression
  upx "${BIN_PATH}" || true

# ---- runner ----
FROM alpine:3.20
ARG BIN_PATH="build/http-adapter"
WORKDIR /
COPY --from=builder /src/${BIN_PATH} /exe
ENTRYPOINT ["/exe"]
