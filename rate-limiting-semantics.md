# Missing: 429 Rate-Limiting Response Body and Semantics

**Priority:** Important  
**Affects:** All endpoints  
**Current spec location:** [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

## What Was Lost

The `TOOMANYREQUESTS` error code appears in the current spec's error table (code-14), but:

1. There is no description of *when* it should be returned.
2. There is no requirement that the 429 response include a JSON error body.
3. There is no mention of the `Retry-After` header that registries use to signal backoff delay.
4. There is no guidance on whether clients should retry after receiving 429.

The deleted `detail.md` documented `429 Too Many Requests` with a `TOOMANYREQUESTS` error
body as a defined response for *every single endpoint*, treating it as a first-class response
code on par with 401 and 404. The original `spec_before.md` error table similarly listed
`TOOMANYREQUESTS` as a full peer code, not as an afterthought.

The current one-line description "too many requests" gives no actionable guidance to either
registry authors or client authors.

## Evidence From Implementations

### Servers emitting 429 with body and Retry-After

- **olareg** — [`olareg.go#L184-L185`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/olareg.go#L184-L185)
  ```go
  resp.Header().Add("Retry-After", "1")
  resp.WriteHeader(http.StatusTooManyRequests)
  ```

- **olareg** — [`types/errors.go#L160-L165`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/types/errors.go#L160-L165)
  ```go
  func ErrInfoTooManyRequests(d string) ErrorInfo {
      ...Code: "TOOMANYREQUESTS",
  ```

- **distribution** (server) — [`registry/api/errcode/register.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/errcode/register.go)
  `TOOMANYREQUESTS` registered with `HTTPStatusCode: http.StatusTooManyRequests`.

- **cue-labs-oci** — [`ociregistry/error.go#L334`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/error.go#L334)
  ```go
  ErrTooManyRequests = NewError("too many requests", "TOOMANYREQUESTS", nil)
  ```

### Clients reading Retry-After and backing off

- **regclient** — [`internal/reghttp/http.go#L663-L686`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/reghttp/http.go#L663-L686)
  ```go
  if resp.resp.Header.Get("Retry-After") != "" {
      ras := resp.resp.Header.Get("Retry-After")
      ra, _ := time.ParseDuration(ras + "s")
      // uses ra as backoff delay
  ```
  Reads `Retry-After` header and uses its value as the backoff duration.

- **containerd** — [`core/remotes/docker/resolver.go#L777`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/resolver.go#L777)
  ```go
  case http.StatusRequestTimeout, http.StatusTooManyRequests:
      return true, nil
  ```
  429 is retried, same as 408.

- **google/go-containerregistry** — [`pkg/v1/remote/transport/error.go#L133-L144`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/transport/error.go#L133-L144)
  `TOOMANYREQUESTS` in `temporaryErrorCodes` — triggers retry logic.

## Proposed Fix

### Amend the `TOOMANYREQUESTS` entry in [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

Change the current one-line description to:

```markdown
| code-14 | `TOOMANYREQUESTS` | The client has sent too many requests in a given amount of time. The client SHOULD wait before retrying. |
```

### Add a subsection in [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

After the error code table (before [§Warnings](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#warnings)), add:

```markdown
#### Rate Limiting

A registry MAY enforce rate limits on clients and return `429 Too Many Requests` when limits
are exceeded.
A `429` response SHOULD include a JSON error body with `TOOMANYREQUESTS` as the error code.
A `429` response SHOULD include a `Retry-After` header indicating the number of seconds the
client SHOULD wait before retrying the request.

Clients SHOULD treat `429` responses as transient and retry the request after the delay
indicated by the `Retry-After` header, or after an implementation-defined backoff if no
`Retry-After` header is present.
```
