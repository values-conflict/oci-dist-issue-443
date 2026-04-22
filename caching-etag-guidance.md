# Missing: Aggressive HTTP Caching, ETag, and Range Headers Guidance

**Priority:** Important  
**Affects:** `GET /v2/<name>/blobs/<digest>` (end-2), `GET /v2/<name>/manifests/<reference>` (end-3)  
**Current spec location:** [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs), [§Pulling manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-manifests)

## What Was Lost

The original spec had two explicit caching requirements, one general and one specific to blobs:

> All endpoints SHOULD support aggressive http caching, compression and range headers,
> where appropriate. The new API attempts to leverage HTTP semantics where possible but
> MAY break from standards to implement targeted features.
>
> — *[§Overview](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#overview)*

> This endpoint SHOULD support aggressive HTTP caching for image layers. Support for Etags,
> modification dates and other cache control headers SHOULD be included. To allow for
> incremental downloads, `Range` requests SHOULD be supported, as well.
>
> — *[§Pulling a Layer](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#pulling-a-layer)*

The current spec has no caching guidance at all. The only related statement is the single
sentence about Range requests in [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs). There is no mention of ETags, `If-None-Match`,
`Last-Modified`, or `Cache-Control` anywhere in the spec.

This matters because:
- Blobs are content-addressed and immutable — they are ideal for aggressive, indefinite caching.
- ETags on manifest endpoints enable efficient polling (e.g., a CI system watching for tag
  updates) without downloading the full manifest body each time.
- The absence of guidance means registry implementations must guess, and clients cannot rely
  on any caching behavior.

## Evidence From Implementations

### Servers emitting ETag and handling If-None-Match

- **distribution** (blob server) — [`registry/storage/blobserver.go#L56`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/storage/blobserver.go#L56)
  ```go
  w.Header().Set("ETag", fmt.Sprintf(`"%s"`, desc.Digest))
  // If-None-Match handled by ServeContent
  ```

- **distribution** (manifest handler) — [`registry/handlers/manifests.go#L232`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/handlers/manifests.go#L232)
  ```go
  for _, headerVal := range r.Header["If-None-Match"] {
  ```
  Reads `If-None-Match` to return 304 for unchanged manifests.

- **distribution** (API tests) — [`registry/handlers/api_test.go#L1120`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/handlers/api_test.go#L1120)
  Sets `"ETag": []string{fmt.Sprintf(`"%s"`, dgst)}` in test responses; corresponding tests at
  [#L1130](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/handlers/api_test.go#L1130)
  send `If-None-Match: <etag>` from the client side.

### Clients sending If-None-Match

- **distribution** — [`internal/client/repository.go#L569`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/repository.go#L569)
  ```go
  req.Header.Set("If-None-Match", ms.etags[digestOrTag])
  ```

## Proposed Fix

### Add to [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

After the `Content-Length` requirement, add:

```markdown
Because blobs are content-addressed and immutable, registries SHOULD support aggressive HTTP
caching for blob responses.
Specifically:

- Responses SHOULD include a `Cache-Control` header permitting long-term caching (for
  example, `Cache-Control: max-age=31536000`), since a blob's content can never change for a
  given digest.
- Responses SHOULD include an `ETag` header whose value is the blob's digest, enabling
  conditional `GET` requests via `If-None-Match`.
- Responses SHOULD include `Content-Length` for all `200 OK` blob responses.
```

### Add to [§Pulling manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-manifests)

After the `Docker-Content-Digest` paragraph, add:

```markdown
Registries SHOULD include an `ETag` response header on manifest `GET` and `HEAD` responses,
whose value is the manifest's digest.
Clients MAY use `If-None-Match` request headers with this value to avoid re-downloading an
unchanged manifest, and registries SHOULD respond with `304 Not Modified` when the manifest
has not changed.
```
