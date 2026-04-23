# Missing: Stream-Mode PATCH (Upload Without Content-Range)

**Priority:** Important  
**Affects:** `PATCH /v2/<name>/blobs/uploads/<reference>` (end-5)  
**Current spec location:** [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

## What Was Lost

The original spec and the deleted `detail.md` described two distinct PATCH modes:

**Chunked mode** — uses `Content-Range` to specify which bytes are being sent:
```http
PATCH /v2/<name>/blobs/uploads/<session_id>
Content-Length: <size of chunk>
Content-Range: <start>-<end>
Content-Type: application/octet-stream
```

**Stream mode** — no `Content-Range`; the entire body is streamed in a single PATCH with no pre-declared byte range:
```http
PATCH /v2/<name>/blobs/uploads/<session_id>
Content-Type: application/octet-stream

<full blob binary data>
```

The `detail.md` (before deletion) explicitly documented the stream upload as a separate named sub-operation: *"Upload a stream of data to upload without completing the upload."*

> — *[§Stream upload](https://github.com/opencontainers/distribution-spec/blob/e20e7f0e419fc34928f934fb85e2bce1c83d11c5/detail.md#stream-upload)*

The current spec ([§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)) defines only the chunked mode (requiring `Content-Range`).
Stream mode has been silently dropped.

## Why This Matters

Stream mode is the dominant implementation strategy for clients that know the full blob in advance and want to avoid the chunked protocol overhead.
It is simpler to implement and is what most clients actually do when pushing small-to-medium blobs.

## Related Issues

- [#443](https://github.com/opencontainers/distribution-spec/issues/443) (open): @sudo-bmitch [comments](https://github.com/opencontainers/distribution-spec/issues/443#issuecomment-1645950937): "We also define a chunked upload, but not the streaming upload for blobs."
- [#303](https://github.com/opencontainers/distribution-spec/issues/303) (open): "Streamed Blob Upload not defined by spec" — direct match; notes the same three-type reality (monolithic, chunked, streamed) and points to the conformance test for streamed upload that has no spec backing.

## Related PRs

- [#404](https://github.com/opencontainers/distribution-spec/pull/404) — "Allow Content-Length to be omitted when pushing on patch requests" (**open**): directly related; proposes making `Content-Length` optional on `PATCH`, which is a prerequisite for stream-mode uploads where the total size is not always known upfront.

## Conformance Tests

### Existing suite

- **"Blob Upload Streamed"** — [`conformance/02_push_test.go#L38-L70`](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/conformance/02_push_test.go#L38-L70)
  The shipped conformance suite already includes a "Blob Upload Streamed" context: a PATCH with the full blob body and no `Content-Range`, followed by a closing PUT.
  Stream mode is therefore already a conformance requirement despite not being described in the spec text.

### PR #588 (proposed)

- **`BlobPatchStream` / `TestPushBlobPatchStream`** — [PR #588](https://github.com/opencontainers/distribution-spec/pull/588), [`conformance/api.go#L534-L621`](https://github.com/sudo-bmitch/distribution-spec/blob/pr-conformance-v2/conformance/api.go#L534-L621)
  The redesigned suite provides a more structured `BlobPatchStream` function, including digest verification on the completed upload, as a named API type (`stateAPIBlobPatchStream`) that registries can declare support for.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (client)** — [`registry/client/blob_writer.go#L38-L51`](https://github.com/distribution/distribution/blob/v2.7.1/registry/client/blob_writer.go#L38-L51)
  ```go
  func (hbu *httpBlobUpload) ReadFrom(r io.Reader) (n int64, err error) {
      req, err := http.NewRequest("PATCH", hbu.location, ioutil.NopCloser(r))
      ...
      // No Content-Type, no Content-Range set
  ```
  `ReadFrom` — stream mode — was the **primary client interface** for blob upload in v2.7.1, issuing a PATCH with neither `Content-Range` nor `Content-Type`.
  > Current behavior: [`internal/client/blob_writer.go#L40-L50`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L40-L50) — unchanged; `ReadFrom` still issues a Content-Range-free PATCH, now with `Content-Type: application/octet-stream` added.

- **distribution v2.7.1 (server)** — [`registry/handlers/blobupload.go#L167-L193`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/blobupload.go#L167-L193)
  ```go
  func (buh *blobUploadHandler) PatchBlobData(w http.ResponseWriter, r *http.Request) {
      ...
      // TODO(dmcgowan): support Content-Range header to seek and write range
      if err := copyFullPayload(buh, w, r, buh.Upload, -1, "blob PATCH"); err != nil {
  ```
  The v2.7.1 server **only** implemented stream mode. The `// TODO` at line 180 shows `Content-Range` (chunked) support was explicitly deferred. The canonical registry did not support chunked PATCH at all when the spec was reorganized.
  > Current behavior: the `TODO` is resolved; the current server handles both modes. See [`internal/client/blob_writer.go#L76-L84`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L76-L84) for the client's later-added `Write` (chunked) path.

### Other implementations

- **google/go-containerregistry (client)** — [`pkg/v1/remote/write.go#L257-L288`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/write.go#L257-L288)
  ```go
  func (w *writer) streamBlob(...) (commitLocation string, rerr error) {
      req, err := http.NewRequest(http.MethodPatch, streamLocation, blob)
  ```
  `streamBlob` issues a single PATCH of the entire blob body with no `Content-Range`.

- **google/go-containerregistry (server)** — [`pkg/registry/blobs.go#L404-L448`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L404-L448)
  ```go
  if contentRange != "" {
      // chunked path — parse Content-Range
  }
  // else: stream path — first write accepted; subsequent stream writes rejected
  if _, ok := b.uploads[target]; ok {
      return &regError{..., Message: "Stream uploads after first write are not allowed"}
  }
  ```
  The ggcr server explicitly handles both modes: a PATCH with `Content-Range` goes through the chunked path; a PATCH without it goes through the stream path (first write only). This is the clearest binary implementation of the two-mode design.

- **cue-labs-oci (server)** — [`ociregistry/ociserver/writer.go#L89-L102`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/writer.go#L89-L102)
  ```go
  // Note that the spec requires chunked upload PATCH requests to include Content-Range,
  // but the conformance tests do not actually follow that as of the time of writing.
  // Allow the missing header to result in start=0, meaning we assume it's the first chunk.
  ```
  Explicitly documents this as a known spec/conformance-test inconsistency and accepts stream-mode PATCHes to avoid breaking clients.

## Proposed Fix

### Add stream mode to [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

After the chunked PATCH description, add:

```markdown
---

##### Stream Upload

As an alternative to chunked uploads, a client MAY stream the entire blob in a single `PATCH`
request by omitting the `Content-Range` header:

URL path: `<location>` <sup>[end-5](#endpoints)</sup>
```
Content-Type: application/octet-stream
Content-Length: <total-length>
```
```
<full blob byte stream>
```

A registry that receives a `PATCH` without a `Content-Range` header SHOULD treat the body as
starting at byte offset 0.
The response on success MUST be `202 Accepted` with `Location` and `Range` headers as
described above.
The session MUST still be closed with a subsequent `PUT` request.
```
