# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

# ---- builder ----
FROM alpine:3.20 AS builder
ARG SVC
ARG BIN_PATH="build/${SVC}"

WORKDIR /src
RUN apk add --no-cache build-base upx
COPY . .

# Build the service and (optionally) compress; tolerate UPX failures.
RUN test -n "${SVC}" || (echo "Missing build arg SVC" && exit 2) \
 && make "${SVC}" \
 && test -f "${BIN_PATH}" \
 && upx "${BIN_PATH}" || true

# ---- runner ----
FROM alpine:3.20
ARG SVC
ARG BIN_PATH="build/${SVC}"
WORKDIR /
COPY --from=builder /src/${BIN_PATH} /exe

# Run the binary directly; no /bin/sh dependency.
ENTRYPOINT ["/exe"]
