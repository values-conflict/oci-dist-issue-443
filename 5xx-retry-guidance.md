# Missing: 5xx Error Retry Semantics

**Priority:** Important  
**Affects:** All endpoints, especially blob push/pull  
**Current spec location:** No equivalent exists in the current spec

## What Was Lost

The original spec explicitly described which 5xx errors are transient (retriable) and which
are terminal:

> If a 502, 503 or 504 error is received, the client SHOULD assume that the download can
> proceed due to a temporary condition, honoring the appropriate retry mechanism.
> Other 5xx errors SHOULD be treated as terminal.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#errors-1)*

This section appeared in the context of blob push errors but was intended generally. The current
spec has no guidance anywhere on retry behavior for server-side errors, leaving every client
implementation to invent its own policy — which, as seen below, they all have done with
slightly different lists.

## Evidence From Implementations

### distribution v2.7 (canonical)

The v2.7.1 client library did not implement retry logic — it propagated errors directly to callers. The retry behavior described in the original spec was a **client-side responsibility** that the spec documented but the canonical library left to higher layers. This absence is itself informative: the guidance was in the spec to fill a gap that the reference library left open.

### Other implementations

The following clients implement retry on 5xx, suggesting this is an operational necessity:

- **containerd (client)** — [`core/remotes/docker/resolver.go#L777-L779`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/resolver.go#L777-L779)
  ```go
  case http.StatusRequestTimeout, http.StatusTooManyRequests:
      return true, nil
  case http.StatusServiceUnavailable, http.StatusGatewayTimeout, http.StatusInternalServerError:
  ```
  503, 504, and 500 are retried; 500 only on last host.

- **regclient (client)** — [`internal/reghttp/http.go#L474-L476`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/reghttp/http.go#L474-L476)
  ```go
  case http.StatusTooManyRequests, http.StatusRequestTimeout,
       http.StatusGatewayTimeout, http.StatusBadGateway,
       http.StatusInternalServerError:
      // server is likely overloaded, backoff but still retry
  ```

- **google/go-containerregistry (client)** — [`pkg/v1/remote/options.go#L94-L102`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/options.go#L94-L102)
  ```go
  var defaultRetryStatusCodes = []int{
      http.StatusRequestTimeout,
      http.StatusInternalServerError,
      http.StatusBadGateway,
      http.StatusServiceUnavailable,
      http.StatusGatewayTimeout,
      499, 522,
  }
  ```
  Also ships a [`pkg/v1/remote/transport/retry.go`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/transport/retry.go)
  transport wrapper with default exponential backoff (100 ms base, factor 3.0, 3 steps).

## Proposed Fix

### Insertion point

Add a new subsection at the end of [§Requirements](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#requirements) (before [§Registry Proxying](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#registry-proxying)), or as a note within [§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload):

```markdown
#### Transient Server Errors

When a request receives a `502 Bad Gateway`, `503 Service Unavailable`, or
`504 Gateway Timeout` response, the client SHOULD assume the condition is temporary and
MAY retry the request using an appropriate backoff strategy.
Other `5xx` error responses SHOULD be treated as terminal for that request attempt.

During a blob upload, any `4xx` response (except `416 Requested Range Not Satisfiable`,
which indicates the need to resume from a different offset) MUST be treated as a failed
upload.
The client SHOULD then issue a `DELETE` request to cancel the upload session (see
[Cancel a blob upload](#cancel-a-blob-upload)) before retrying from the beginning.
```
