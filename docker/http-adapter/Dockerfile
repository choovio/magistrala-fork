# Copyright (c) Abstract Machines
# SPDX-FileCopyrightText: 2025 CHOOVIO Inc.
# SPDX-License-Identifier: MIT

# ---- builder ----
FROM alpine:3.20 AS builder
ARG SVC="http-adapter"
ARG BIN_PATH="build/${SVC}"

WORKDIR /src
RUN apk add --no-cache build-base upx
COPY . .

# Build and (optionally) compress; tolerate UPX failures.
RUN make "${SVC}" \
 && test -f "${BIN_PATH}" \
 && upx "${BIN_PATH}" || true

# ---- runner ----
FROM alpine:3.20
ARG BIN_PATH="build/http-adapter"
WORKDIR /
COPY --from=builder /src/${BIN_PATH} /exe

# Run the binary directly; no /bin/sh dependency.
ENTRYPOINT ["/exe"]

