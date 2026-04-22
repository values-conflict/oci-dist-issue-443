# Missing: `Accept-Ranges: bytes` Capability Detection for Blob Range Requests

**Priority:** Important  
**Affects:** `HEAD /v2/<name>/blobs/<digest>` (end-2)  
**Current spec location:** [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs), [§Checking if content exists in the registry](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#checking-if-content-exists-in-the-registry)

## What Was Lost

The deleted `detail.md` described a specific mechanism for clients to detect whether a
registry supports range requests on blobs, using the `Accept-Ranges` response header on a
HEAD request:

> This endpoint MAY also support RFC7233 compliant range requests. Support can be detected
> by issuing a HEAD request. If the header `Accept-Range: bytes` is returned, range requests
> can be used to fetch partial content.
>
> — *[§Fetch Blob Part](https://github.com/opencontainers/distribution-spec/blob/e20e7f0e419fc34928f934fb85e2bce1c83d11c5/detail.md#fetch-blob-part)*

Note: the original text uses the singular `Accept-Range` (a typo — the correct RFC 7233 /
RFC 9110 header is the plural `Accept-Ranges`). All actual implementations use the correct
plural form.

The current spec ([§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)) says only:

> A registry SHOULD support the `Range` request header in accordance with RFC 9110.

There is no mention of how to detect support, what response header to look for, or what HEAD
response headers to expect.

## Why This Matters

Without a capability detection mechanism:
- Clients cannot distinguish "this registry doesn't support range requests" from "this range
  request had an error."
- Clients that unconditionally send range requests to registries that don't support them will
  receive 200 responses with the full blob, silently breaking their resumption logic.

The `Accept-Ranges: bytes` response on HEAD is the standard HTTP mechanism (RFC 9110
§14.3) for this purpose.

## Evidence From Implementations

### Servers advertising `Accept-Ranges: bytes`

- **zot** — [`pkg/api/routes.go#L1119`](https://github.com/project-zot/zot/blob/9ba59559d2f4bf2502e7fb4efa120e5558ee7bb6/pkg/api/routes.go#L1119)
  ```go
  response.Header().Set("Accept-Ranges", "bytes")
  ```

- **cue-labs-oci** — [`ociregistry/ociserver/reader.go#L35`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/reader.go#L35)
  ```go
  resp.Header().Set("Accept-Ranges", "bytes")
  ```

- **distribution** (server descriptors) — [`registry/api/v2/descriptors.go#L816`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go#L816)
  ```
  Description: "This endpoint may also support RFC7233 compliant range requests.
  Support can be detected by issuing a HEAD request. If the header
  'Accept-Range: bytes' is returned, range requests can be used to fetch partial content."
  ```

### Clients checking for `Accept-Ranges`

- **regclient** — [`blob_test.go#L99`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/blob_test.go#L99)
  ```go
  "Accept-Ranges": {"bytes"},
  ```
  Test fixtures include the header to simulate a range-capable registry.

- **regclient** — [`scheme/reg/blob_test.go#L156`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/scheme/reg/blob_test.go#L156)
  `"Accept-Ranges": {"bytes"}` in test fixtures.

- **zot** (test) — [`pkg/api/controller_test.go#L11246`](https://github.com/project-zot/zot/blob/9ba59559d2f4bf2502e7fb4efa120e5558ee7bb6/pkg/api/controller_test.go#L11246)
  ```go
  So(resp.Header().Get("Accept-Ranges"), ShouldEqual, "bytes")
  ```
  Conformance test asserts the header is present.

## Proposed Fix

### Amend [§Checking if content exists in the registry](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#checking-if-content-exists-in-the-registry)

After the existing `Content-Length` requirement, add:

```markdown
A successful `HEAD` response for a blob SHOULD include an `Accept-Ranges: bytes` header if
the registry supports range requests on that blob's `GET` endpoint.
Clients MAY use the presence of `Accept-Ranges: bytes` in a `HEAD` response to determine
whether to use a range request when subsequently fetching the blob.
```

### Amend [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

Replace the single Range sentence with:

```markdown
A registry SHOULD support the `Range` request header on blob `GET` requests in accordance
with [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-range-requests).
A registry that supports range requests SHOULD advertise this capability by including
`Accept-Ranges: bytes` in `HEAD` and `GET` responses for blobs.
Clients MAY detect range-request support by issuing a `HEAD` request and checking for the
`Accept-Ranges: bytes` response header before sending a range `GET`.
```
