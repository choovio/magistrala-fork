# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0
FROM golang:1.24-alpine AS builder
ARG MAIN
RUN test -n "$MAIN"
WORKDIR /src
RUN apk add --no-cache build-base git upx
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /exe "$MAIN" && upx /exe || true

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H -u 10001 app
USER 10001:10001
COPY --from=builder /exe /exe
ENTRYPOINT ["/exe"]
