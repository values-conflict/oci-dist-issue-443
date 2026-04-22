# Missing: 4xx Response During Upload Terminates the Session

**Priority:** Important  
**Affects:** `PATCH` and `PUT` blob upload endpoints (end-5, end-6)  
**Current spec location:** [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

## What Was Lost

The original spec explicitly stated that a 4xx response (other than 416) during a blob upload
means the upload is failed and the client must start over:

> If there is a problem with the upload, a 4xx error will be returned indicating the problem.
> After receiving a 4xx response (except 416, as called out above), the upload will be
> considered failed and the client SHOULD take appropriate action.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#errors-1)*

The current spec describes the `416` case in [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks) but says nothing about what other 4xx codes mean for upload session state. A client reading the current spec cannot determine whether, say, a `400 Bad Request` on a PATCH means: (a) the chunk was rejected but the session is still valid, or (b) the entire upload session is now dead and must be restarted.

## Why This Matters

Without this language, clients may attempt to resume a session that the registry has already
invalidated, wasting bandwidth and causing spurious errors. The correct behavior is to cancel
and restart, but that is only implied, never stated.

## Evidence From Implementations

- **distribution** — [`internal/client/blob_writer.go#L33-L37`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L33-L37)
  ```go
  func (hbu *httpBlobUpload) handleErrorResponse(resp *http.Response) error {
      if resp.StatusCode == http.StatusNotFound {
          return distribution.ErrBlobUploadUnknown
      }
      ...
  }
  ```
  Treats 404 as an unknown/dead session, requiring restart.

- **olareg** — [`blob.go#L123`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L123)
  ```go
  types.ErrRespJSON(w, types.ErrInfoBlobUploadUnknown("upload session not found"))
  ```
  Returns `BLOB_UPLOAD_UNKNOWN` when a session ID is not found, indicating the session cannot
  be resumed (also lines 154, 388, 468).

- **distribution** (server) — [`registry/api/v2/descriptors.go#L1210`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go#L1210)
  ```
  "The upload is unknown to the registry. The upload must be restarted."
  ```
  The server's own documentation says restart is required.

## Proposed Fix

### Insertion point

Add to [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks), after the 416 paragraph:

```markdown
Any `4xx` response other than `416 Requested Range Not Satisfiable` indicates that the upload
session has failed and MUST NOT be resumed.
The client SHOULD issue a `DELETE` request to the upload `<location>` to release server
resources (see [Cancel a blob upload](#cancel-a-blob-upload)), and then restart the upload
from the beginning.

If the upload `<location>` is no longer valid (for example, because the session has expired
or been garbage collected by the registry), the registry MUST respond to further requests
to that location with `404 Not Found` and a `BLOB_UPLOAD_UNKNOWN` error code.
In that case the client MUST restart the upload process entirely.
```
