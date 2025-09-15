/* SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 2025 CHOOVIO Inc.
 */

# ---- builder ----
FROM alpine:3.20 AS builder
ARG SVC
ARG GOARCH
ARG GOARM
ARG VERSION
ARG COMMIT
ARG TIME
WORKDIR /go/src/github.com/absmach/supermq

RUN apk add --no-cache build-base go upx

ENV GOARCH=${GOARCH} \
    GOARM=${GOARM} \
    VERSION=${VERSION} \
    COMMIT=${COMMIT} \
    TIME=${TIME}

COPY . .
RUN make "${SVC}" \
 && test -f "build/${SVC}" \
 && { upx "build/${SVC}" || true; }

# ---- runner ----
FROM alpine:3.20
ARG SVC
WORKDIR /
COPY --from=builder /go/src/github.com/absmach/supermq/build/${SVC} /exe
ENTRYPOINT ["/exe"]
