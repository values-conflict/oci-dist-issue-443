# Issue 443 — Content Lost in the c90b0f1 Reorganization

This directory catalogs technical content that was present in the OCI Distribution Spec
before commit [`c90b0f145ac6bc09d2636ee214486ac333edc284`](https://github.com/opencontainers/distribution-spec/commit/c90b0f145ac6bc09d2636ee214486ac333edc284)
("Reorganize distribution spec") and has not been restored in the current `spec.md`.

## History

The commit split a 4,603-line `spec.md` into a 425-line `spec.md` plus a new 3,761-line
`detail.md`. A subsequent commit ([`1877628`](https://github.com/opencontainers/distribution-spec/commit/187762882835c04ead2534af09d78fc846b966d5)) restored some sections, and
[`a92b62e`](https://github.com/opencontainers/distribution-spec/commit/a92b62ee17c3a89e3d18fd1288e6f7547a9696d5) folded more content back in. Then
[`edbe27f`](https://github.com/opencontainers/distribution-spec/commit/edbe27fcffdb28899fff98f81747f8b7980fd590) deleted `detail.md` entirely. A significant amount of
conformance-relevant protocol behavior was deleted and never restored.

The current `spec.md` is 921 lines. The pre-reorganization `spec.md` was 4,603 lines.

## Scope

Only findings that require **new normative language** (or an RFC citation not yet present)
are included. Behavior fully defined by an already-referenced RFC (RFC 2119, RFC 5988,
RFC 7231, RFC 7234, RFC 9110) is excluded on the grounds that it is derivable by any
implementer reading those documents. One exception is noted: `link-header-format.md` is
technically RFC 5988-defined but included because implementations demonstrably get it wrong.

## Issues

Each file documents one category of lost content, with:

- **What was lost** — quoted original text with pinned link to historical source
- **Why it matters** — conformance / interoperability impact
- **Evidence** — implementations in widely-used OCI client and registry projects that
  demonstrate the feature is deployed in practice, with pinned GitHub URLs
- **Proposed fix** — exact proposed wording and insertion point in `spec.md`

### Critical (spec contradicts deployed behavior)

| File | Topic |
|------|-------|
| [blob-redirect-307.md](blob-redirect-307.md) | `GET /blobs/<digest>` MAY return 307 redirect; spec currently says MUST be 200 |
| [range-header-format.md](range-header-format.md) | Upload state machine Range header uses bare `0-N` format, not RFC `bytes=0-N`; initial state is undefined |

### Important (missing protocol requirements)

| File | Topic |
|------|-------|
| [stream-mode-patch.md](stream-mode-patch.md) | PATCH without `Content-Range` (stream mode) was documented; now silently expected by servers |
| [416-response-headers.md](416-response-headers.md) | 416 response MUST include `Location`, `Range`, `Content-Length: 0` so client can resume |
| [upload-4xx-terminal.md](upload-4xx-terminal.md) | Any 4xx (except 416) during upload terminates the session |
| [upload-session-expiry.md](upload-session-expiry.md) | 404 on upload URL means session expired; client MUST restart |
| [5xx-retry-guidance.md](5xx-retry-guidance.md) | 502/503/504 are transient and retriable; other 5xx are terminal |
| [rate-limiting-semantics.md](rate-limiting-semantics.md) | RFC 6585 (429) and RFC 9110 §10.2.3 (Retry-After) not cited; add references |
| [mount-head-probe.md](mount-head-probe.md) | Client MAY HEAD-probe blob to distinguish "mount unsupported" from "blob absent" |
| [multiple-digest-params.md](multiple-digest-params.md) | PUT blob upload MAY include multiple `digest=` query params for multi-algorithm verification |
| [link-header-format.md](link-header-format.md) | Pagination `Link` header angle-bracket format (RFC 5988-defined but implementers get it wrong); absence means end of results; worked example |
| [digest-algorithm-domains.md](digest-algorithm-domains.md) | `Docker-Content-Digest` SHOULD NOT be trusted over locally-computed digest; "domains" concept |
| [blob-unknown-detail-schema.md](blob-unknown-detail-schema.md) | `BLOB_UNKNOWN` and `DIGEST_INVALID` `detail` field schema (`{digest: "<value>"}`) |
| [per-endpoint-error-codes.md](per-endpoint-error-codes.md) | Error codes that belong to each endpoint's 400/404/405 response are undocumented |
| [manifest-put-400-errors.md](manifest-put-400-errors.md) | PUT manifest can return 400 (`MANIFEST_INVALID`, `MANIFEST_BLOB_UNKNOWN`, `NAME_INVALID`); endpoint table omits this |
| [unknown-error-code-handling.md](unknown-error-code-handling.md) | Clients SHOULD treat unknown error codes as `UNKNOWN`; error codes only added, never removed |

## Repository Commits Used for Evidence

Client and registry citations are pinned to the following commits:

| Project | GitHub | Commit |
|---------|--------|--------|
| containerd | https://github.com/containerd/containerd | `46a7bd7` |
| cue-labs/oci | https://github.com/cue-labs/oci | `3adeb86` |
| distribution/distribution | https://github.com/distribution/distribution | `f3af4de` |
| docker/cli | https://github.com/docker/cli | `977ee83` |
| google/go-containerregistry | https://github.com/google/go-containerregistry | `d4f1050` |
| moby/moby | https://github.com/moby/moby | `dff719e` |
| regclient/regclient | https://github.com/regclient/regclient | `1a4d357` |
| containers/skopeo | https://github.com/containers/skopeo | `1a4a0f9` |
| olareg/olareg | https://github.com/olareg/olareg | `b50ccb7` |
| project-zot/zot | https://github.com/project-zot/zot | `9ba5955` |
