<!--
Copyright (c) CHOOVIO Inc.
SPDX-License-Identifier: Apache-2.0
-->
# SBX Backend Endpoints (magistrala)

- Base HTTP proxy: https://sbx.gobee.io/http
- Base WS proxy:   https://sbx.gobee.io/ws

## Health contract
All services MUST expose `/health` (200 = healthy).

### Quick checks
```sh
curl -L https://sbx.gobee.io/http/health
curl -L https://sbx.gobee.io/ws/health
```

> Cloudflare terminates TLS; upstream certificates remain ACM-managed.

## DNS routing via Cloudflare

- `sbx.gobee.io` lives in the Cloudflare `gobee.io` zone as a **DNS-only** CNAME.
- Point the record at the sandbox Application Load Balancer (`magistrala-sbx-alb.<region>.elb.amazonaws.com`).
- Keep Cloudflare proxying disabled so traffic reaches the AWS ALB/Ingress stack directly.
