# GoBee SBX Backend Contract (Magistrala-based)

> **Purpose:** Single source of truth for the Next.js frontend to integrate with SBX.  
> **Status:** Template complete; fill placeholders with verified SBX values.  
> **Principles:** No guessing • Per-tenant isolation • RBAC enforced • Simple, versioned contract.

---

## OpenAPI Specification

- [SBX OpenAPI spec](sbx-openapi.yaml)

### Browse locally

- **Redoc:** `npx redoc-cli serve docs/sbx-openapi.yaml`
- **Swagger UI:** `docker run --rm -p 8080:8080 -e SWAGGER_JSON=/spec.yaml -v $(pwd)/docs/sbx-openapi.yaml:/spec.yaml swaggerapi/swagger-ui`

---

## 1) Environments
- **Sandbox Base URL:** `https://sbx.gobee.io`
- **Health Probe:** `GET /health` → `200 OK`
- **API Gateway / Ingress:** `https://sbx.gobee.io`
  - _Routing:_ `/api/*` → backend services (confirm)
- **WebSocket (if any):** `wss://…` (alerts/status live updates) _(confirm)_
- **Telemetry Stores:** Timescale/Postgres readers (read-only HTTP) _(confirm exact paths)_

---

## 2) Auth
*(unchanged)*

---

## 3) Core Services & Endpoints
*(unchanged)*

---

## 4) Messaging (MQTT/NATS)
*(unchanged)*

---

## 5) Data Shapes (Sample Schemas)
*(unchanged)*

---

## 6) AI Integration (Phase-ready; implement after full UI)
*(unchanged)*

---

## 7) Testing Aids
- `GET /health` → 200
- `GET /api/status/summary` → keys: services, uptime
- `GET /api/devices` → array (empty OK)
- Multi-tenant sanity: switching `X-Tenant-ID` yields distinct lists.
- Demo dataset: seed or MQTT publish recipe (document separately)

---

## 8) RBAC Permission Matrix
*(unchanged)*

---

## 9) Frontend Coverage Map
*(unchanged)*

---

## 10) Open Questions
*(unchanged)*

---

## 11) Ownership
*(unchanged)*
