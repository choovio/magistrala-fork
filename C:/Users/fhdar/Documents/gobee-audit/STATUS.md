# GoBee Audit Status

## Adapters Audit Status

### Adapters Audit Status (2025-09-22)

- Current manifests reference `<AWS_ACCOUNT_ID>` placeholders → must be corrected to `595443389404`.
- Images are tag-based (`:1f48a...`) → must be pinned to `@sha256` digests.
- Ingress drift: `/api/http-adapter` still present → must be removed (FE expects `/api/http` and `/api/ws` only).
- Pods Pending due to `InvalidImageName` → fix requires proper ECR push and digest pinning.
