# Missing: Digest Algorithm Domains — Client Verification Semantics

**Priority:** Important  
**Affects:** `GET /v2/<name>/blobs/<digest>`, `GET /v2/<name>/manifests/<reference>`  
**Current spec location:** [§Pulling manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-manifests), [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

## What Was Lost

The original spec defined a precise conceptual model for how clients should handle the
`Docker-Content-Digest` response header when the returned digest algorithm differs from the
one used in the request:

> The client MAY choose to ignore the header or MAY verify it to ensure content integrity
> and transport security. This is most important when fetching by a digest.
> To ensure security, the content SHOULD be verified against the digest used to fetch the
> content. At times, the returned digest MAY differ from that used to initiate a request.
> Such digests are considered to be from different _domains_, meaning they have different
> values for _algorithm_. In such a case, the client MAY choose to verify the digests in
> both domains or ignore the server's digest.
> To maintain security, the client MUST always verify the content against the _digest_ used
> to fetch the content.
>
> **IMPORTANT**: If a _digest_ is used to fetch content, the client SHOULD use the same digest
> used to fetch the content to verify it. The header `Docker-Content-Digest` SHOULD NOT be
> trusted over the "local" digest.
>
> — *[§Digest Header](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#digest-header)*

The current spec ([§Pulling manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-manifests)) says:

> The `Docker-Content-Digest` header, if present on the response, returns the digest of the
> uploaded blob which MAY differ from the provided digest. If the digest does differ, it MAY
> be the case that the hashing algorithms used do not match.

This drops:
1. The **"different domains"** conceptual model — the key insight that different algorithms
   produce digests in different "domains" and that comparing across them is invalid.
2. The **IMPORTANT admonition** that the server's `Docker-Content-Digest` SHOULD NOT be
   trusted *over* the client's own local digest.
3. The explicit **MUST** requirement: the client MUST always verify against the digest used
   in the request, not the server-returned one.

## Why This Matters

The dropped IMPORTANT note is a security requirement, not just a nicety. A server that returns
a false `Docker-Content-Digest` (e.g., due to a bug or a MITM) could cause a naive client to
accept incorrect content if the client prefers the server header over its own calculation.

## Evidence From Implementations

- **containerd** — [`core/remotes/docker/resolver.go#L689-L692`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/resolver.go#L689-L692)
  Accepts 206 and reads `Content-Range` for blob verification, but uses the locally-known
  digest from the manifest as the ground truth, not the server header.

- **distribution** — [`internal/client/transport/http_reader.go#L205-L238`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/transport/http_reader.go#L205-L238)
  Validates content against the digest in the request, parsing and cross-checking
  `Content-Range` against the local expected values.

- **cue-labs-oci** — [`ociregistry/ociclient/client.go#L148-L159`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociclient/client.go#L148-L159)
  Validates the `Content-Range` on 206 response against the requested range.

## Proposed Fix

### Amend [§Pulling blobs](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-blobs)

After the existing `Docker-Content-Digest` paragraph, add:

```markdown
When the client fetches a blob by digest, it MUST verify that the response body matches the
digest specified in the request URL.
The `Docker-Content-Digest` response header, if present, SHOULD NOT be trusted in place of
this local verification: the client SHOULD compute the digest of the received content and
compare it against the request digest directly.

If the `Docker-Content-Digest` header value uses a different hashing algorithm than the
request digest, the two values are in different digest _domains_ and cannot be directly
compared.
In such a case, the client MUST still verify the content against the digest used in the
request and MAY additionally verify against the server-provided digest as an extra check.
```

### Amend [§Pulling manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pulling-manifests)

After the existing `Docker-Content-Digest` note, add:

```markdown
When the `<reference>` in a manifest request is a digest, the client MUST verify the
downloaded manifest body matches that digest.
The client SHOULD NOT substitute the server-returned `Docker-Content-Digest` value for its
own verification: the `Docker-Content-Digest` header SHOULD NOT be trusted in preference
to locally-computed verification.
```
