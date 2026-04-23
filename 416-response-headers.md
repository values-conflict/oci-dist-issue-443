# Missing: 416 Response Headers During Chunked Upload

**Priority:** Important  
**Affects:** `PATCH /v2/<name>/blobs/uploads/<reference>` (end-5)  
**Current spec location:** [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

## What Was Lost

The original spec defined the exact headers a registry MUST return in a `416 Requested Range Not Satisfiable` response during a chunked upload, enabling the client to recover:

```http
416 Requested Range Not Satisfiable
Location: /v2/<name>/blobs/uploads/<session_id>
Range: 0-<last valid range>
Content-Length: 0
```

And enumerated the conditions that trigger it:

> A 416 will be returned under the following conditions:
> - Invalid Content-Range header format
> - Out of order chunk: the range of the next chunk MUST start immediately after the "last
>   valid range" from the previous response.
>
> — *[§Chunked Upload](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#chunked-upload)*

The current spec ([§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)) says only:

> If a chunk is uploaded out of order, the registry MUST respond with a
> `416 Requested Range Not Satisfiable` code.
> A GET request may be used to retrieve the current valid offset and upload location.

This loses:
1. The `Location` header (required for the client to know where to continue).
2. The `Range` header on the 416 itself (the "last valid range" so the client can resume
   *without* a separate GET).
3. The `Content-Length: 0` requirement.
4. The enumerated conditions that trigger a 416 (invalid `Content-Range` format, plus
   out-of-order chunk).

Directing clients to "issue a GET request to retrieve the current valid offset" is weaker than having the 416 response itself carry the recovery information — it adds a round-trip.

## Related Issues

- [#355](https://github.com/opencontainers/distribution-spec/issues/355) (open): "Critical response headers should have compliance tests" — calls out missing response headers (including on the upload endpoints) as a gap between the conformance tests and real-world interoperability.
- [#590](https://github.com/opencontainers/distribution-spec/issues/590) (closed): "HTTP status code for a blob PUT with an invalid range" — spawned PR #593.

## Related PRs

- [#593](https://github.com/opencontainers/distribution-spec/pull/593) — "Clarify that 416 is valid on a blob put" (merged): confirmed 416 is a valid response for the closing `PUT` of an upload. Does **not** address the response headers (`Location`, `Range`, `Content-Length: 0`) that must accompany a 416 on a `PATCH` so the client can recover without a separate `GET`.
- [#366](https://github.com/opencontainers/distribution-spec/pull/366) — "Add a patch status to recover failed requests" (merged): added the `GET /v2/<name>/blobs/uploads/<reference>` endpoint (end-13) as a recovery mechanism. The current spec directs clients to issue a `GET` after a 416; our issue is that the 416 itself should carry enough headers to avoid that extra round-trip.

## Conformance Tests

### Existing suite

- **"Out-of-order blob upload should return 416"** — [`conformance/02_push_test.go#L170-L197`](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/conformance/02_push_test.go#L170-L197)
- **"Retry previous blob chunk should return 416"** — [`conformance/02_push_test.go#L220-L230`](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/conformance/02_push_test.go#L220-L230)
  Both tests assert only `StatusCode == 416`; neither checks `Location`, `Range`, or `Content-Length: 0` on the 416 response itself.
  Recovery is demonstrated via a subsequent GET ([`#L232-L241`](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/conformance/02_push_test.go#L232-L241)), which checks `Location` and `Range` on the 204 — but this requires the extra round-trip that the proposed fix would eliminate.

### PR #588 (proposed)

- **`BlobPatchChunked` with `OutOfOrderChunks`** — [PR #588](https://github.com/opencontainers/distribution-spec/pull/588), [`conformance/api.go#L402-L440`](https://github.com/sudo-bmitch/distribution-spec/blob/pr-conformance-v2/conformance/api.go#L402-L440)
  Adds `apiReturnHeader("Location", &loc)` at [`#L410`](https://github.com/sudo-bmitch/distribution-spec/blob/pr-conformance-v2/conformance/api.go#L410) on the 416 response itself, requiring `Location` to be present on the 416.
  `Range` and `Content-Length: 0` on the 416 are still not checked; recovery remains via a subsequent GET.
  The full set of recovery headers on the 416 itself (`Location`, `Range`, `Content-Length: 0`) remains untested in both suites, making this issue's proposed fix directly actionable as a further conformance test improvement.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (server)** — [`registry/handlers/blobupload.go#L319-L323`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/blobupload.go#L319-L323)
  ```go
  w.Header().Set("Location", uploadURL)
  w.Header().Set("Content-Length", "0")
  w.Header().Set("Range", fmt.Sprintf("0-%d", endRange))
  ```
  The `blobUploadResponse` helper — used for all success (202) responses — sets `Location`, `Content-Length: 0`, and bare `Range` since v2.7.1. Note: v2.7.1 did not emit 416 from PATCH (chunked upload was unimplemented; see [stream-mode-patch.md](stream-mode-patch.md)), so 416 recovery headers were not exercised by the canonical server at the time of the spec reorganization.
  > Current behavior: [`internal/client/blob_writer.go#L64-L72`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L64-L72) — the client parses `Range` from both 202 and 416 responses using `fmt.Sscanf(rng, "%d-%d", ...)`, expecting all three headers to be present. The current server still documents `Location`, `Range`, and `Content-Length` as required 416 response headers in [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go).

### Other implementations

- **google/go-containerregistry (server)** — [`pkg/registry/blobs.go#L406-L419`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L406-L419)
  ```go
  if _, err := fmt.Sscanf(contentRange, "%d-%d", &start, &end); err != nil {
      return &regError{Status: http.StatusRequestedRangeNotSatisfiable,
          Code: "BLOB_UPLOAD_UNKNOWN", ...}
  }
  if start != len(b.uploads[target]) {
      return &regError{Status: http.StatusRequestedRangeNotSatisfiable,
          Code: "BLOB_UPLOAD_UNKNOWN", ...}
  }
  ```
  The ggcr server returns 416 for an out-of-order or malformed `Content-Range`, but does **not** set `Location`, `Range`, or `Content-Length: 0` on the 416 response — the client has no in-band recovery information without a separate `GET`. This is evidence that the missing 416 headers are a real gap even in recent implementations.

- **cue-labs-oci (server)** — [`ociregistry/ociserver/writer.go#L84`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/writer.go#L84)
  Sets `Range` header in upload responses; the logic for 416 vs 202 uses the same `ocirequest.RangeString` helper.

## Proposed Fix

### Replacement text for [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

Replace the current 416 paragraph with:

````markdown
Chunks MUST be uploaded in order, with the first byte of a chunk being the last chunk's
`<end-of-range>` plus one.
A `416 Requested Range Not Satisfiable` response MUST be returned by the registry in either
of the following cases:

- The `Content-Range` header is missing or has an invalid format.
- The chunk is out of order (i.e., its start byte does not immediately follow the last
  accepted byte).

The `416` response MUST include the following headers so that the client can recover without
an additional round-trip:

```
416 Requested Range Not Satisfiable
Location: <location>
Range: 0-<last-valid-byte>
Content-Length: 0
```

`<last-valid-byte>` is the zero-based index of the last byte successfully received by the
registry for this session.
The client SHOULD resume the upload by sending the next chunk starting at
`<last-valid-byte> + 1`.
````
