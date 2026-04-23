# Missing/Inconsistent: Range Header Wire Format in Upload State Machine

**Priority:** Critical  
**Affects:** `PATCH /v2/<name>/blobs/uploads/<reference>` (end-5), `GET /v2/<name>/blobs/uploads/<reference>` (end-13)  
**Current spec location:** [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

## What Was Lost / Changed

The original spec defined the `Range` header in upload state machine responses using the
`bytes=` prefix per RFC 7233:

```http
202 Accepted
Location: /v2/<name>/blobs/uploads/<session_id>
Range: bytes=0-<offset>
Content-Length: 0
```

```http
204 No Content
Location: /v2/<name>/blobs/uploads/<session_id>
Range: bytes=0-<offset>
```

```http
416 Requested Range Not Satisfiable
Location: /v2/<name>/blobs/uploads/<session_id>
Range: 0-<last valid range>
Content-Length: 0
```

> — *[§Chunked Upload](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#chunked-upload) (202 response), [§Upload Progress](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#upload-progress) (204 GET response)*

Note the original spec was itself inconsistent: the 416 response omits the `bytes=` prefix
while the 202 and 204 responses include it. This inconsistency was present in the original and
has been silently inherited.

The current spec uses the bare `0-<end>` format (without `bytes=`) throughout — for both the
PATCH 202 response and the GET 204 response:

```
Range: 0-<end-of-range>
```

> — *[§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)*

This creates two problems:

1. **Non-RFC format**: The HTTP `Range` header in requests uses `bytes=<start>-<end>` per
   RFC 9110. The upload progress response is a *response* header, so it is not strictly
   governed by the same RFC, but the inconsistency creates confusion and interop bugs.

2. **No spec for empty/initial state**: The original spec specified that when an upload has
   just started and no bytes have been received, the response Range is `bytes=0-0` (meaning
   zero bytes received). The current spec says nothing about what the `Range` value looks like
   for a freshly-initiated upload, leaving clients unable to distinguish "0 bytes received"
   from "offset unknown".

## Related Issues

- [#213](https://github.com/opencontainers/distribution-spec/issues/213) (open): "Range Header Clarifications for Resumable Uploads and Partial Downloads" — directly about the Range/Content-Range semantics during chunked upload, including the `0-<offset>` vs `<start>-<end>` confusion.
- [#586](https://github.com/opencontainers/distribution-spec/issues/586) (open): "`Content-Range` and `Range` syntax expected by this spec deviates from RFC 7233" — directly about the missing `bytes=` prefix.
- [#580](https://github.com/opencontainers/distribution-spec/issues/580) (closed): "Range header in the chunked response needs clarification" — spawned PR #581.
- [#577](https://github.com/opencontainers/distribution-spec/issues/577) (closed): "Unclear (or incorrect) 'Range' in response header" — related discussion.

## Related PRs

- [#581](https://github.com/opencontainers/distribution-spec/pull/581) — "Clarify the Range header on a chunked push response" (merged): clarified that `<end-of-range>` is the offset of the last byte of the **entire blob**, not the last chunk. This is now in the current spec. It does **not** address the `bytes=` prefix question or the initial-state `0-0` semantics.
- [#203](https://github.com/opencontainers/distribution-spec/pull/203) — "fixed to use 'bytes' unit for Content-Range to spec/test" (closed, **not merged**): directly attempted to require the `bytes=` prefix per RFC 7233; closed without merging.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (client, stream mode)** — [`registry/client/blob_writer.go#L59-L64`](https://github.com/distribution/distribution/blob/v2.7.1/registry/client/blob_writer.go#L59-L64)
  ```go
  rng := resp.Header.Get("Range")
  var start, end int64
  if n, err := fmt.Sscanf(rng, "%d-%d", &start, &end); err != nil {
  ```
  The canonical client has parsed the upload progress `Range` response header as bare `start-end` (no `bytes=` prefix) since v2.7.1.
  > Current behavior: [`internal/client/blob_writer.go#L64-L72`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L64-L72) — identical `fmt.Sscanf(rng, "%d-%d", ...)` parse.

- **distribution v2.7.1 (client, chunked mode)** — [`registry/client/blob_writer.go#L94-L99`](https://github.com/distribution/distribution/blob/v2.7.1/registry/client/blob_writer.go#L94-L99)
  Same `fmt.Sscanf(rng, "%d-%d", ...)` parse in the `Write` (chunked) path. Both client modes expect the bare format.

- **distribution v2.7.1 (server)** — [`registry/handlers/blobupload.go#L320-L323`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/blobupload.go#L320-L323)
  ```go
  w.Header().Set("Content-Length", "0")
  w.Header().Set("Range", fmt.Sprintf("0-%d", endRange))
  ```
  The canonical server has emitted bare `0-N` Range headers since v2.7.1. This is the format the spec text should describe.
  > Current behavior: identical; current server uses the same `fmt.Sprintf("0-%d", endRange)` pattern.

### Other implementations

- **cue-labs-oci (server)** — [`ociregistry/ociserver/writer.go#L84`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/writer.go#L84)
  ```go
  resp.Header().Set("Range", ocirequest.RangeString(0, w.Size()))
  ```

- **cue-labs-oci (server, internal)** — [`ociregistry/internal/ocirequest/request.go#L428-L432`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/internal/ocirequest/request.go#L428-L432)
  `RangeString` formats the header as `start-end` (bare, no `bytes=`).

- **cue-labs-oci (server, conformance tests)** — [`ociregistry/ociserver/registry_test.go`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/registry_test.go)
  Test headers assert `"Range": "0-0"` for a fresh upload.

- **google/go-containerregistry (server)** — [`pkg/registry/blobs.go#L391`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L391), [L426](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L426), [L447](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L447)
  ```go
  resp.Header().Set("Range", "0-0")                                    // POST: fresh session
  resp.Header().Set("Range", fmt.Sprintf("0-%d", len(l.Bytes())-1))   // PATCH 202 response
  ```
  The ggcr registry server hardcodes `"0-0"` for fresh upload sessions (line 391) and uses the bare `0-N` format for all PATCH 202 responses — providing a third independent confirmation of both the bare format and the initial-state semantics.

## Proposed Fix

### 1. Explicitly define the bare `start-end` format as the spec format for upload Range responses

Add a note after the chunk-accepted response block in [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks):

---

> **Note on Range header format in upload responses**: The `Range` header returned by the
> registry in upload responses (`202 Accepted`, `204 No Content`, and `416` responses) uses
> the bare `<start>-<end>` format (e.g., `0-1023`) rather than the `bytes=<start>-<end>`
> format used in HTTP range *request* headers (RFC 9110). Both ends are inclusive.

---

### 2. Define the initial Range value (zero bytes received)

Add to the description of the 202 PATCH response in [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks):

---

When no bytes have yet been received (i.e., immediately after the initiating `POST`), the
`Range` value MUST be `0-0`, indicating that the next byte to be sent is byte 0.
After the first successful chunk upload, the `<end-of-range>` value is the zero-based index
of the last byte received.

---

### 3. Full proposed addition in [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

Insert after the paragraph describing the `<end-of-range>` value:

```markdown
> **Note**: The `Range` header in upload progress responses uses the bare `<start>-<end>`
> format (for example, `Range: 0-1023`), not the `bytes=<start>-<end>` format defined by
> RFC 9110 for range requests. Both ends are inclusive. Immediately after initiating an
> upload session with no data transferred, the registry MUST return `Range: 0-0`.
```
