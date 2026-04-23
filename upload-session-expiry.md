# Missing: Upload Session Expiry — 404 Means Restart

**Priority:** Important  
**Affects:** `PATCH`, `PUT`, `GET` blob upload endpoints (end-5, end-6, end-13)  
**Current spec location:** [§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload)

## What Was Lost

The original spec stated that upload sessions have a finite lifetime and defined exactly what
happens when one expires:

> Note that the upload url will not be available forever. If the upload `session_id` is
> unknown to the registry, a `404 Not Found` response will be returned and the client MUST
> restart the upload process.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#errors-1)*

The current spec acknowledges sessions time out from the server's perspective in
[§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload):

> If this request fails or is not called, the server SHOULD eventually timeout unfinished
> uploads.

But it says nothing about what the client MUST do when a 404 is received against an upload
URL. A client receiving a 404 on a PATCH or PUT to an upload location cannot tell from the
current spec whether this means: "the registry doesn't understand this endpoint", "the session
expired", or "this is a network error". The original spec's `MUST restart` language closed
that ambiguity.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (client)** — [`registry/client/blob_writer.go#L31-L34`](https://github.com/distribution/distribution/blob/v2.7.1/registry/client/blob_writer.go#L31-L34)
  ```go
  func (hbu *httpBlobUpload) handleErrorResponse(resp *http.Response) error {
      if resp.StatusCode == http.StatusNotFound {
          return distribution.ErrBlobUploadUnknown
      }
  ```
  The canonical client has mapped 404 on an upload URL to `ErrBlobUploadUnknown` (restart required) since v2.7.1.
  > Current behavior: [`internal/client/blob_writer.go#L33-L37`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L33-L37) — identical.

- **distribution v2.7.1 (server)** — [`registry/handlers/blobupload.go#L63-L75`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/blobupload.go#L63-L75)
  ```go
  if err == distribution.ErrBlobUploadUnknown {
      return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
          buh.Errors = append(buh.Errors, v2.ErrorCodeBlobUploadUnknown.WithDetail(err))
      })
  }
  ```
  When session lookup fails with `ErrBlobUploadUnknown`, the server returns `BLOB_UPLOAD_UNKNOWN` — the signal the client above is waiting for.
  > Current behavior: unchanged.

### Other implementations

- **olareg** — [`blob.go#L123`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L123), [#L154](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L154), [#L388](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L388), [#L468](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L468)
  ```go
  types.ErrRespJSON(w, types.ErrInfoBlobUploadUnknown("upload session not found"))
  ```
  Four distinct code paths all return `BLOB_UPLOAD_UNKNOWN` with a 404 when a session is
  not found.

## Proposed Fix

### Insertion point

Add to [§Cancel a blob upload](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#cancel-a-blob-upload), or as a note within [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks):

```markdown
Upload sessions do not persist indefinitely.
If a registry receives a request for an upload session that has expired or is otherwise
unknown, it MUST respond with `404 Not Found` and SHOULD include a `BLOB_UPLOAD_UNKNOWN`
error in the response body.
Upon receiving such a `404 Not Found` response for an upload session URL, the client MUST
treat the upload as failed and restart the upload process from the beginning (i.e., a new
`POST` to `/v2/<name>/blobs/uploads/` is required).
```
