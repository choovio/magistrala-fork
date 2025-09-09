# ADR-0001: Service Sourcing for SBX Console

**Status:** Proposed  
**Date:** 2025-02-21

## Context

- The repository contains no local code for `users`, `clients`, `domains`, `certs`, `http-adapter`, or `ws-adapter`. `docs/SOURCES.md` maps each service to a `supermq/*:latest` image and marks the “Local Source” column as `_none_`​:codex-file-citation[codex-file-citation]{line_range_start=5 line_range_end=10 path=docs/SOURCES.md git_url="https://github.com/choovio/magistrala-fork/blob/main/docs/SOURCES.md#L5-L10"}​.  
- `ops/matrix/sources.json` mirrors this by flagging `missingSource: true` for all six services and referencing `supermq/*:latest` images on ports `9002`, `9006/7006`, `9003/7003`, `9019`, `8008`, and `8186`​:codex-file-citation[codex-file-citation]{line_range_start=1 line_range_end=7 path=ops/matrix/sources.json git_url="https://github.com/choovio/magistrala-fork/blob/main/ops/matrix/sources.json#L1-L7"}​.  
- Project handoff notes specify SBX ingress routes for these services (e.g., `/users`, `/clients`, `/domains`, etc.). Without buildable images or manifests, those routes remain empty, blocking the console.  
- `ops/matrix/matrix.json` marks each service `unresolved: true`, preventing inclusion in the build matrix (file contents noted in handoff).  
- The Matrix Scout workflow is designed to fail while any service remains unresolved, halting CI until sources or images are provided​:codex-file-citation[codex-file-citation]{line_range_start=87 line_range_end=105 path=.github/workflows/matrix-scout.yml git_url="https://github.com/choovio/magistrala-fork/blob/main/.github/workflows/matrix-scout.yml#L87-L105"}​.

## Option A – Vendor Source (subtree or submodule)

**Description:** Import upstream repositories for the six services into this fork.

**Pros**
- Local source enables patching, code review, and SBOM generation.
- Unified build pipeline with consistent tagging.
- Security scanning (SCA) runs against source and binaries.
- K8s manifests derive `targetPort` directly from checked-in Dockerfiles or `run.sh`.

**Cons**
- Larger repo size and more complex merges.
- Ongoing upstream sync effort.
- Longer path to unblock the console.

**CI Impact**
- Expand build matrix; publish tagged images (e.g., `vX.Y.Z`).
- Run SCA and unit tests per service.
- Update tags in Matrix Scout and release workflows.

**Security Impact**
- Full SCA coverage; ability to patch CVEs quickly.
- Must monitor upstream repos for updates.

**SBX K8s Impact**
- Generate manifests under `ops/sbx/<service>/` using known `targetPort` values from `docker/supermq-docker` compose definitions.
- Ingress points become resolvable once images build.

## Option B – Pin Upstream Images (no source)

**Description:** Consume vendor images directly, but pin exact versions.

**Pros**
- Fastest path to unblock console.
- Minimal repository changes.
- Keeps fork lean while upstream matures.

**Cons**
- Limited auditability; source remains external.
- Patch turnaround depends on vendor.
- Reproducibility tied to vendor’s retention of tags.

**Image Pinning Policy**
- Prohibit `latest`; use digest (`sha256:...`) or semantic version tags.

**CI Impact**
- Skip image builds; CI only scans and mirrors pinned images.
- Matrix Scout validates metadata but not Dockerfiles.

**SBX K8s Impact**
- Manifests reference pinned images; `targetPort` values taken from compose or `run.sh`.
- No source-derived SBOM; rely on vendor-provided checks.

## Decision Drivers

1. Speed to unblock console access.
2. Auditability and provenance of artifacts.
3. Reproducibility of builds and deployments.
4. Ability to patch or hotfix critical issues.

## Recommendation

Adopt **Option B – Pin Upstream Images** as a short-term measure to restore console functionality quickly, then re-evaluate vendoring once the system stabilizes.

### TODOs

- [ ] Select and pin digests or semver tags for `supermq/users`, `clients`, `domains`, `certs`, `http`, and `ws`.
- [ ] Update `ops/matrix/matrix.json` to record pinned images and mark services resolved.
- [ ] Adjust CI to skip builds and mirror/scan pinned images only.
- [ ] Create SBX K8s manifests with the pinned images and known `targetPort` values.
- [ ] Schedule a spike to assess vendoring upstream sources for longer-term maintainability.

## References

- [`docs/SOURCES.md`](docs/SOURCES.md) – service/image mapping  
- [`ops/matrix/sources.json`](ops/matrix/sources.json) – metadata from compose  
- [`ops/matrix/matrix.json`](ops/matrix/matrix.json) – service resolution matrix  
- [`matrix-scout.yml`](.github/workflows/matrix-scout.yml) – CI workflow verifying matrix entries
