# GoBee SBX Backend Contract (Magistrala-based)

This contract summarizes the expectations for the sandbox (SBX) deployment of the GoBee console when it is backed by Magistrala services. The focus is on ensuring that the console and supporting tooling have a stable surface to integrate against while back-end services continue to evolve.

## 0) Summary
- **Audience:** Console engineers, QA automation, and integration partners.
- **Scope:** High-level environment metadata, service inventory, and REST contract highlights.
- **Source of truth:** `openapi/sbx.yaml` in this repository (supplemented by Magistrala upstream docs).

## 1) Environments
- **Sandbox Base URL:** `https://sbx.gobee.io`
- **Health Probe:** `GET /health` → `200 OK`
- **API Gateway / Ingress:** `https://sbx.gobee.io`
  - _Routing:_ `/api/*` → backend services (confirm)
  - _Routing:_ `/ui/*` → console static assets

## 2) Authentication & Authorization
- Primary authentication leverages Magistrala-issued user tokens (JWT access tokens issued via the users service).
- Console flows assume OAuth 2.0 Authorization Code with PKCE for browser interactions.
- Service-to-service calls (e.g., CLI tooling) may rely on client credentials scoped to the sandbox environment.
- Role-based authorization is derived from Magistrala "member" and "owner" roles; additional console-specific roles are TBD.

## 3) Service Inventory & Endpoints
- **Users / Auth:** `/api/users/*` for profile and session management (proxied to Magistrala `users` service).
- **Devices:** `/api/devices` (list) and `/api/devices/{id}` (detail) proxied to the Magistrala readers pipeline.
- **Tenants:** `/api/tenants/*` proxies to Magistrala provisioning service for tenant onboarding.
- **Status Summary:** `/api/status/summary` aggregates liveness/uptime information from Magistrala subsystem health endpoints.
- **WebSockets:** `/ws/*` proxied to Magistrala WS adapter for live telemetry.

## 4) Data Contracts
- Device resources follow Magistrala's canonical `Device` schema (`id`, `name`, `status`, `tags`, `created_at`, `updated_at`).
- Tenants expose `id`, `name`, `slug`, and `plan` fields aligned with the provisioning API.
- Status summary aggregates return JSON `{ "services": {"<service>": "up"|"down"}, "uptime": "<duration>" }`.
- Errors conform to Magistrala's RFC 7807-style problem document with `type`, `title`, `status`, and optional `detail`.

## 5) Error Handling Expectations
- All REST endpoints should return machine-parseable error documents (problem+json) when requests fail validation or authorization.
- Unauthorized access returns `401 Unauthorized`; insufficient permissions return `403 Forbidden` with console-specific remediation hints when possible.
- Rate limiting, if enforced, surfaces as `429 Too Many Requests` with a `Retry-After` header.

## 6) Observability & Instrumentation
- Each upstream Magistrala service exposes Prometheus metrics at `/metrics`; the console ingests aggregate metrics for dashboards.
- Distributed tracing is propagated via `traceparent` headers; services must forward tracing context to maintain spans.
- Structured logs are emitted in JSON (minimum keys: `ts`, `level`, `svc`, `msg`, `trace_id`).

## 7) Testing Aids
- `GET /health` → 200
- `GET /api/status/summary` → keys: services, uptime
- `GET /api/devices` → array (empty OK)
- `POST /api/devices/_search` → filter by tag, returns array
- `GET /ws/devices/stream` → Upgrades to WebSocket when device telemetry is available
