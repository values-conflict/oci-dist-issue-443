# Missing: RFC References for 429 Rate-Limiting Behavior

**Priority:** Important  
**Affects:** All endpoints  
**Current spec location:** [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

## What Was Lost

The `TOOMANYREQUESTS` error code appears in the current spec's error table (code-14) with a
one-line description "too many requests" and no further guidance. The spec does not reference
the RFCs that define this behavior, leaving implementers without normative grounding.

The relevant standards are:
- **RFC 6585** — defines the `429 Too Many Requests` HTTP status code and its use with a
  `Retry-After` header.
- **RFC 9110 §10.2.3** — defines the `Retry-After` header semantics (already referenced in
  spec for Range support; §10.2.3 is the applicable sub-section for retry).

Both are not currently cited in the spec. Any implementer reading RFC 6585 would know that
429 SHOULD include a `Retry-After` header and that clients SHOULD back off accordingly — this
behavior does not need new normative prose, just the citations.

## Evidence From Implementations

The following implementations follow RFC 6585 behavior without being directed to by the spec:

- **olareg** — [`olareg.go#L184-L185`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/olareg.go#L184-L185)
  Emits `Retry-After: 1` with every 429 response.

- **regclient** — [`internal/reghttp/http.go#L663-L686`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/reghttp/http.go#L663-L686)
  Reads `Retry-After` and uses its value as the backoff duration.

- **containerd** — [`core/remotes/docker/resolver.go#L777`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/resolver.go#L777)
  Retries on 429, same as 408.

- **google/go-containerregistry** — [`pkg/v1/remote/transport/error.go#L133-L144`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/transport/error.go#L133-L144)
  `TOOMANYREQUESTS` in `temporaryErrorCodes` — triggers retry.

## Proposed Fix

No new normative prose is needed. Add RFC citations in two places:

### 1. Amend the `TOOMANYREQUESTS` row in [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

```markdown
| code-14 | `TOOMANYREQUESTS` | too many requests; see [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585#section-4) |
```

### 2. Add a sentence to [§Warnings](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#warnings) or §Error Codes

```markdown
When a registry returns `429 Too Many Requests`, it SHOULD follow
[RFC 6585 §4](https://www.rfc-editor.org/rfc/rfc6585#section-4), including providing a
`Retry-After` header per
[RFC 9110 §10.2.3](https://www.rfc-editor.org/rfc/rfc9110#section-10.2.3).
```
