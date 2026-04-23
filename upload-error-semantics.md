# Missing: Upload Error Semantics — 4xx Terminates Sessions, 404 Means Restart

**Priority:** Important  
**Affects:** `PATCH`, `PUT`, `GET` blob upload endpoints (end-5, end-6, end-13)  
**Current spec location:** [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks), [§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload)

## What Was Lost

The original spec stated two related rules for upload error handling:

**Rule 1 — Any 4xx (except 416) terminates the session:**

> If there is a problem with the upload, a 4xx error will be returned indicating the problem.
> After receiving a 4xx response (except 416, as called out above), the upload will be
> considered failed and the client SHOULD take appropriate action.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#errors-1)*

**Rule 2 — 404 specifically means the session is gone and the client MUST restart from scratch:**

> Note that the upload url will not be available forever. If the upload `session_id` is
> unknown to the registry, a `404 Not Found` response will be returned and the client MUST
> restart the upload process.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#errors-1)*

The current spec describes only the `416` case in [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks) and notes that unfinished uploads eventually time out from the server's side in [§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload) — but specifies nothing about what the client MUST do in either error case.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (client)** — [`registry/client/blob_writer.go#L31-L37`](https://github.com/distribution/distribution/blob/v2.7.1/registry/client/blob_writer.go#L31-L37)
  ```go
  func (hbu *httpBlobUpload) handleErrorResponse(resp *http.Response) error {
      if resp.StatusCode == http.StatusNotFound {
          return distribution.ErrBlobUploadUnknown  // restart required
      }
      return HandleErrorResponse(resp)              // all other errors: terminal
  }
  ```
  The single `handleErrorResponse` function encodes both rules: 404 maps to a named restart signal; every other error propagates as terminal. This pattern has been present since v2.7.1.
  > Current behavior: [`internal/client/blob_writer.go#L33-L37`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L33-L37) — identical. The current server descriptor at [`registry/api/v2/descriptors.go#L1210`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go#L1210) still reads: *"The upload is unknown to the registry. The upload must be restarted."*

- **distribution v2.7.1 (server)** — [`registry/handlers/blobupload.go#L63-L75`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/blobupload.go#L63-L75)
  ```go
  if err == distribution.ErrBlobUploadUnknown {
      return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
          buh.Errors = append(buh.Errors, v2.ErrorCodeBlobUploadUnknown.WithDetail(err))
      })
  }
  ```
  When session lookup fails, the server returns `BLOB_UPLOAD_UNKNOWN` — the signal that triggers the client restart path above.
  > Current behavior: unchanged.

### Other implementations

- **olareg (server)** — [`blob.go#L123`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L123)
  ```go
  types.ErrRespJSON(w, types.ErrInfoBlobUploadUnknown("upload session not found"))
  ```
  Returns `BLOB_UPLOAD_UNKNOWN` on unknown session across four independent code paths (also lines 154, 388, 468).

## Proposed Fix

### Insertion point in [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

Append after the 416 paragraph:

```markdown
Any other `4xx` response indicates the upload session has failed and MUST NOT be resumed.
```

### Insertion point in [§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload)

Append after the timeout sentence:

```markdown
A `404 Not Found` response to any request on an upload session URL indicates the session has expired; the client MUST begin a new upload with a fresh `POST` to `/v2/<name>/blobs/uploads/`.
```
