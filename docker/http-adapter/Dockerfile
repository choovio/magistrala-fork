# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

FROM golang:1.24-alpine AS builder

WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /bin/http-adapter ./cmd/http-adapter

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /bin/http-adapter /bin/http-adapter

ENTRYPOINT ["/bin/http-adapter"]
