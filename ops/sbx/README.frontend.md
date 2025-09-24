# SBX Backend Endpoints (single host)

**Base host:** \sbx.gobee.io\

- HTTP API path: \/http\ (health: \/http/health\)
- WS path:      \/ws\   (health: \/ws/health\)

All services MUST expose \/health\ (200 = healthy).  
Ingress uses nginx regex+rewrite so \/http/*\ and \/ws/*\ map to backend paths without the prefix.

### Quick checks
\\\ash
curl -i http://sbx.gobee.io/http/health
curl -i http://sbx.gobee.io/ws/health
\\\

> TLS: pending ACM/Cloudflare policy. For now HTTP is fine; we’ll enable HTTPS once cert is wired.
