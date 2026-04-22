# Missing: 416 Response Headers During Chunked Upload

**Priority:** Important  
**Affects:** `PATCH /v2/<name>/blobs/uploads/<reference>` (end-5)  
**Current spec location:** [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

## What Was Lost

The original spec defined the exact headers a registry MUST return in a `416 Requested Range
Not Satisfiable` response during a chunked upload, enabling the client to recover:

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

Directing clients to "issue a GET request to retrieve the current valid offset" is weaker than
having the 416 response itself carry the recovery information — it adds a round-trip.

## Evidence From Implementations

- **distribution** — [`internal/client/blob_writer.go#L64-L72`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/blob_writer.go#L64-L72)
  Parses the `Range` header directly from the 416 response (as well as 202 responses) using
  `fmt.Sscanf(rng, "%d-%d", &start, &end)` to determine the resume offset.

- **cue-labs-oci** — [`ociregistry/ociserver/writer.go#L84`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/writer.go#L84)
  Sets `Range` header in upload responses; the logic for 416 vs 202 uses the same
  `ocirequest.RangeString` helper.

- **distribution** (server) — [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go)
  Documents `Location`, `Range`, and `Content-Length` headers for 416 responses in the
  blob upload descriptors.

## Proposed Fix

### Replacement text for [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

Replace the current 416 paragraph with:

```markdown
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
```
