# Copyright (c) Abstract Machines
# SPDX-FileCopyrightText: 2025 CHOOVIO Inc.
# SPDX-License-Identifier: MIT

# ---- builder ----
FROM golang:1.22-alpine AS builder
ARG SVC="ws-adapter"
ARG BIN_PATH="build/${SVC}"
WORKDIR /src

RUN apk add --no-cache build-base upx
ENV CGO_ENABLED=0 GO111MODULE=on
COPY go.mod go.sum ./
RUN go mod download
COPY . .

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
      elif [ -d "./cmd/ws" ]; then \
          go build -trimpath -ldflags="-s -w" -o "${BIN_PATH}" "./cmd/ws"; \
      else \
          echo "No build target or cmd path found for ${SVC}"; exit 3; \
      fi; \
  fi; \
  upx "${BIN_PATH}" || true

# ---- runner ----
FROM alpine:3.20
ARG BIN_PATH="build/ws-adapter"
WORKDIR /
COPY --from=builder /src/${BIN_PATH} /exe
ENTRYPOINT ["/exe"]
