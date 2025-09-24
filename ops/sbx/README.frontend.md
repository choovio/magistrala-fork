# SBX Backend Endpoints (magistrala)

- Base HTTP: \http://http.sbx.gobee.io\
- Base WS:   \http://ws.sbx.gobee.io\

## Health contract
All services MUST expose \/health\ (200 = healthy).

### Quick checks
\\\ash
curl -i http://http.sbx.gobee.io/health
curl -i http://ws.sbx.gobee.io/health
\\\

> TLS: pending ACM issuance; will later be \https://\.

