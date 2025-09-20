# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

FROM golang:1.24-alpine AS builder

WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /bin/ws-adapter ./cmd/ws-adapter

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /bin/ws-adapter /bin/ws-adapter

ENTRYPOINT ["/bin/ws-adapter"]
