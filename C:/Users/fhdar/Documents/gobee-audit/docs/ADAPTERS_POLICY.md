# Adapters Policy — GoBee Audit

**Canonical rules for http-adapter and ws-adapter deployment**

1. **Source of Truth**
   - All adapters are built from the `choovio/magistrala-fork` repository (`cmd/http-adapter`, `cmd/ws-adapter`).
   - No upstream-only or ghost sources allowed.

2. **Registry**
   - All adapter images must be pushed to:
     ```
     595443389404.dkr.ecr.us-west-2.amazonaws.com/<adapter>
     ```
   - No GHCR, DockerHub, or other registries.

3. **Image Reference**
   - Only pinned digests are valid:
     ```
     ...@sha256:<digest>
     ```
   - Tags (e.g. `:main`, `:1f48a...`) are forbidden.

4. **Audit Output**
   - Audit scripts must expand AWS account ID to `595443389404`.
   - All RESULTS blocks log the **real account ID**.

5. **Ingress Policy**
   - Allowed: `/api/http`, `/api/ws`.
   - Forbidden: `/api/http-adapter` or `/api/ws-adapter`.

6. **Process Rule**
   - **Repo updates** must always be done by **Codex Code tasks**.
   - **Cluster verification** must always be done by **PowerShell 7** audit scripts.

---

_Last updated: 2025-09-22_
