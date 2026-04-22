# Missing: Blob Fetch Range Requests — 206 and 416 Response Specifications

**Priority:** Important  
**Affects:** `GET /v2/<name>/blobs/<digest>` (end-2)  
**Current spec location:** [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

## What Was Lost

### 206 Partial Content response format

The deleted `detail.md` defined the full response format for a successful range request on a
blob:

```http
206 Partial Content
Content-Length: <length>
Content-Range: bytes <start>-<end>/<size>
Content-Type: application/octet-stream

<blob binary data>
```

> — *[§Fetch Blob Part](https://github.com/opencontainers/distribution-spec/blob/e20e7f0e419fc34928f934fb85e2bce1c83d11c5/detail.md#fetch-blob-part)*

The original spec also required that range support could be detected via a HEAD request:

> This endpoint MAY also support RFC7233 compliant range requests. Support can be detected
> by issuing a HEAD request. If the header `Accept-Range: bytes` is returned, range requests
> can be used to fetch partial content.
>
> — *[§Fetch Blob Part](https://github.com/opencontainers/distribution-spec/blob/e20e7f0e419fc34928f934fb85e2bce1c83d11c5/detail.md#fetch-blob-part)*

### 416 on blob fetch

The deleted `detail.md` also documented the `416` response for blob range requests:

> `416 Requested Range Not Satisfiable`: The range specification cannot be satisfied for the
> requested content. This can happen when the range is not formatted correctly or if the
> range is outside of the valid size of the content.
>
> — *[§Fetch Blob Part](https://github.com/opencontainers/distribution-spec/blob/e20e7f0e419fc34928f934fb85e2bce1c83d11c5/detail.md#fetch-blob-part)*

### What the current spec says

The current spec ([§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)) says only:

> A registry SHOULD support the `Range` request header in accordance with RFC 9110.

This single sentence:
- Gives no response format for 206.
- Does not mention the `Accept-Ranges` capability advertisement mechanism.
- Does not mention 416.
- Does not describe the `Content-Range` response header.

## Evidence From Implementations

### Servers returning 206 with Content-Range

- **zot** — [`pkg/api/routes.go#L1271-L1273`](https://github.com/project-zot/zot/blob/9ba59559d2f4bf2502e7fb4efa120e5558ee7bb6/pkg/api/routes.go#L1271-L1273)
  ```go
  status = http.StatusPartialContent
  response.Header().Set("Content-Range",
      fmt.Sprintf("bytes %d-%d/%d", from, from+blen-1, bsize))
  ```

- **cue-labs-oci** — [`ociregistry/ociserver/reader.go#L35`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/reader.go#L35)
  Sets `Accept-Ranges: bytes` and returns 206 with `Content-Range`.

- **google/go-containerregistry** (registry server) — [`pkg/registry/blobs.go#L339`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L339)
  `resp.WriteHeader(http.StatusPartialContent)`

### Clients sending Range and parsing 206

- **containerd** — [`core/remotes/docker/resolver.go#L689`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/resolver.go#L689)
  ```go
  if resp.StatusCode == http.StatusPartialContent { return nil }
  ```
  Accepts 206 and reads `Content-Range` (line 692).

- **containerd** (test) — [`core/remotes/docker/fetcher_test.go#L60`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/fetcher_test.go#L60)
  ```go
  if r.Header.Get("Range") == "bytes=0-"
  ```

- **distribution** — [`internal/client/transport/http_reader.go#L205-L238`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/transport/http_reader.go#L205-L238)
  Full implementation: validates `Content-Range` on 206, parses start/end/total, verifies
  offsets.

- **regclient** — [`blob_test.go#L99`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/blob_test.go#L99)
  ```go
  "Accept-Ranges": {"bytes"},
  ```
  Tests the capability advertisement; also tests Range request/response.

### Servers advertising Accept-Ranges

- **zot** — [`pkg/api/routes.go#L1119`](https://github.com/project-zot/zot/blob/9ba59559d2f4bf2502e7fb4efa120e5558ee7bb6/pkg/api/routes.go#L1119)
  `response.Header().Set("Accept-Ranges", "bytes")`

- **cue-labs-oci** — [`ociregistry/ociserver/reader.go#L35`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/reader.go#L35)
  `resp.Header().Set("Accept-Ranges", "bytes")`

## Proposed Fix

### Replacement text for [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

Replace the single Range sentence with:

```markdown
A registry SHOULD support range requests on blob fetches in accordance with
[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-range-requests).

A client MAY detect range-request support by issuing a `HEAD` request to the blob URL.
If the response includes an `Accept-Ranges: bytes` header, the registry supports range
requests and clients MAY use a `Range` request header to fetch a partial blob.

A range request MUST use the `Range: bytes=<start>-<end>` format per RFC 9110.

On success, the registry MUST respond with `206 Partial Content` and the following headers:

```
206 Partial Content
Content-Length: <length of returned range>
Content-Range: bytes <start>-<end>/<total-size>
Content-Type: application/octet-stream
```

If the requested range cannot be satisfied (for example, the range is outside the blob's
size, or the `Range` header is malformed), the registry MUST respond with
`416 Requested Range Not Satisfiable`.

Clients SHOULD verify the response `Content-Range` header against their requested range to
detect partial-content mismatches.
```
