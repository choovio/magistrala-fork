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
COPY go.mod go.sum ./
RUN go mod download

# copy rest
COPY . .

# If a Makefile has a matching target, use it; otherwise build from a conventional cmd path.
# Try common locations: ./cmd/http-adapter or ./http-adapter/cmd or ./cmd/http
# Adjust/add more paths later if your repo differs.
RUN set -eux; \
  if grep -qE "^[[:space:]]*${SVC}:" Makefile 2>/dev/null; then \
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
