# Missing: 307 Temporary Redirect for Blob Fetch

**Priority:** Critical  
**Affects:** `GET /v2/<name>/blobs/<digest>` (end-2)  
**Current spec location:** [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

## What Was Lost

The original spec (`spec.md` before commit c90b0f1) explicitly stated:

> This endpoint MAY issue a 307 (302 for < HTTP 1.1) redirect to another service for
> downloading the layer and clients SHOULD be prepared to handle redirects.
>
> — *[§Pulling a Layer](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#pulling-a-layer)*

The deleted `detail.md` documented 307 as a named success response for `GET /v2/<name>/blobs/<digest>`:

```http
307 Temporary Redirect
Location: <blob location>
Docker-Content-Digest: <digest>
```

The current spec ([§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)) says only:

> A GET request to an existing blob URL MUST provide the expected blob, with a response
> code that MUST be `200 OK`.

That wording now *contradicts* the redirect behavior in active use: a registry that returns 307 is technically non-conformant per the current text, even though it was explicitly allowed before and remains the dominant production deployment pattern for large registries redirecting to object storage or CDNs.

The endpoint table ([§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints)) lists only `200` as success and `404` as failure for end-2 — `307` does not appear at all.

## Related Issues

- [#397](https://github.com/opencontainers/distribution-spec/issues/397) (open): "Pulling a blob doesn't specify 307 as a valid response status code" — direct match; the issue that PR #398 was opened to fix.
- [#299](https://github.com/opencontainers/distribution-spec/issues/299) (open): "Support pull/push redirect" — same problem raised independently.

## Related PRs

- [#607](https://github.com/opencontainers/distribution-spec/pull/607) — "Permit HTTP redirects globally and add RFC references" (**open**): resolves this issue; adds a global redirect rule to §API covering all endpoints, with the "status codes are those after redirects have been followed" framing replacing the need to add 307 to the end-2 table.
- [#398](https://github.com/opencontainers/distribution-spec/pull/398) — "Add 307 as valid response for pulling blobs" (closed, **not merged**): prior attempt; closed without explanation.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (server)** — [`registry/storage/blobserver.go#L41-L42`](https://github.com/distribution/distribution/blob/v2.7.1/registry/storage/blobserver.go#L41-L42)
  ```go
  // Redirect to storage URL.
  http.Redirect(w, r, redirectURL, http.StatusTemporaryRedirect)
  ```
  The canonical registry has redirected blob fetches to storage backends since at least v2.7.1; the redirect path is taken whenever the storage driver provides a URL.
  > Current behavior: [`registry/storage/blobserver.go#L44`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/storage/blobserver.go#L44) — identical; unchanged across all versions. The current server also documents `StatusCode: http.StatusTemporaryRedirect` as a valid blob fetch response in [`registry/api/v2/descriptors.go#L771`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go#L771).

### Other implementations

- **google/go-containerregistry (server)** — [`pkg/registry/blobs.go#L85-L104`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L85-L104), [L214](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/blobs.go#L214)
  ```go
  type redirectError struct { ... Code int ... }
  // later: http.Redirect(resp, req, rerr.Location, rerr.Code)
  ```
  The ggcr registry has a dedicated `redirectError` type and calls `http.Redirect` with arbitrary status codes at multiple points in blob serving — HEAD, GET, and PATCH paths all support redirect.

- **cue-labs-oci (server)** — [`ociregistry/ociserver/reader.go#L61`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/reader.go#L61)
  ```go
  http.Redirect(resp, req, locs[0], http.StatusTemporaryRedirect)
  ```
  Redirects when the backend returns a `BlobLocations` URL list.

### Clients handling redirects

- **containerd (client)** — [`core/remotes/docker/resolver.go#L647-L656`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/resolver.go#L647-L656)
  Installs a custom `CheckRedirect` handler that re-authorizes each redirect hop and limits to 10 redirects.

- **regclient** — [`internal/reghttp/http.go#L803-L811`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/reghttp/http.go#L803-L811)
  ```
  // Repository specific authentication needs a dedicated CheckRedirect handler.
  ```
  `checkRedirect` injects auth headers for specific hosts in the redirect chain.

- **docker/cli (client)** — [`cli/context/docker/load.go#L117`](https://github.com/docker/cli/blob/977ee838e0ec5eb81eef2ba822af900548807516/cli/context/docker/load.go#L117)
  Sets `CheckRedirect: client.CheckRedirect` on every registry HTTP client.

- **moby (client)** — [`daemon/pkg/registry/search_endpoint_v1.go#L175-L197`](https://github.com/moby/moby/blob/dff719e3674958407416fd1d8a35db998f128da2/daemon/pkg/registry/search_endpoint_v1.go#L175-L197)
  `CheckRedirect: addRequiredHeadersToRedirectedRequests` — adds required auth headers to redirected requests.

## Proposed Fix

### 1. Amend the endpoint table ([§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints))

Change the end-2 row to include `307` as a success code:

```
| end-2 | `GET` / `HEAD` | `/v2/<name>/blobs/<digest>` | `200`/`307` | `404` |
```

### 2. Add language to [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

After the current sentence "A GET request to an existing blob URL MUST provide the expected blob, with a response code that MUST be `200 OK`.", change it to:

---

A successful response MUST have a code of `200 OK` or `307 Temporary Redirect` (or `302 Found` for clients that do not support HTTP/1.1). A registry MAY respond with a redirect to an alternate location for the blob content, such as a CDN or object storage endpoint.
Clients MUST follow such redirects to retrieve the blob.
When a redirect crosses host boundaries, clients MUST NOT automatically forward `Authorization` or other credential headers to the redirected host unless that host has been explicitly authorized for the target repository.

---

### 3. Full proposed replacement text in [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

Replace:

```
A GET request to an existing blob URL MUST provide the expected blob, with a response code
that MUST be `200 OK`.
```

With:

```markdown
A successful `GET` request to an existing blob URL MUST return the blob content, with a
response code of `200 OK`.
A registry MAY instead respond with a `307 Temporary Redirect` (or `302 Found` for HTTP/1.0
clients) to an alternate URL for the blob content (for example, a URL signed by an object
storage provider).
Clients MUST follow such redirects.
When a redirect crosses to a different host, clients MUST NOT forward `Authorization` or
other credential headers to the new host unless that host is explicitly trusted for the
target repository.
```
