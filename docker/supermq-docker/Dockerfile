# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 CHOOVIO Inc.

# ---- builder ----
FROM alpine:3.20 AS builder
# SuperMQ may use a different make target/binary name; parameterize:
ARG SVC="supermq"
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
ARG BIN_PATH="build/supermq"
WORKDIR /
COPY --from=builder /src/${BIN_PATH} /exe

ENTRYPOINT ["/exe"]
