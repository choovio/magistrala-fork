# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 CHOOVIO Inc.

# ---- builder ----
FROM alpine:3.20 AS builder
ARG SVC
# Optional: override if the binary path differs
ARG BIN_PATH="build/${SVC}"

WORKDIR /src
RUN apk add --no-cache build-base upx
COPY . .

# Build the service and (optionally) compress the binary.
# Do not fail if upx cannot compress this binary (PIE, etc.).
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
