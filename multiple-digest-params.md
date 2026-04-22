# Missing: Multiple `digest` Query Parameters on Blob Upload PUT

**Priority:** Important  
**Affects:** `PUT /v2/<name>/blobs/uploads/<reference>?digest=<digest>` (end-6)  
**Current spec location:** [§POST then PUT](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#post-then-put), [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

## What Was Lost

The original spec explicitly allowed multiple `digest` query parameters in the same PUT
request for completing a blob upload, enabling multi-algorithm verification:

> Optionally, if all chunks have already been uploaded, a `PUT` request with a `digest`
> parameter and zero-length body MAY be sent to complete and validate the upload.
> Multiple "digest" parameters MAY be provided with different digests.
> The server MAY verify none or all of them but MUST notify the client if the content is
> rejected.
>
> — *[§Completed Upload](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#completed-upload)*

The current spec describes only a single `digest` query parameter and is entirely silent on
whether multiple `digest` parameters are permitted.

This feature allows a client to supply both a `sha256` and a `sha512` (or other algorithm)
digest in the same request, enabling the registry to verify the blob using whichever algorithm
it prefers or supports, without requiring a second round-trip.

## Related PRs

- [#543](https://github.com/opencontainers/distribution-spec/pull/543) — "Add digest-algorithm for non-canonical blob patches" (**open**): proposes an explicit `digest-algorithm` query parameter for specifying non-sha256 algorithms on `PATCH`; a related but different approach to the same multi-algorithm problem.
- [#547](https://github.com/opencontainers/distribution-spec/pull/547) — "docs: faq entry for multiple digest algorithm support" (**open**): FAQ companion to #543.

## Evidence From Implementations

- **cue-labs-oci** — [`ociregistry/internal/ocirequest/create.go#L56-L68`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/internal/ocirequest/create.go#L56-L68)
  Single `digest=` parameter in URL construction today, but the request parsing path reads
  only the first `digest` value, making multi-digest a silent extension.

- **olareg** — [`blob.go#L194-L206`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L194-L206)
  ```go
  r.URL.Query().Get("digest-algorithm")  // EXPERIMENTAL, see OCI PR #543
  ```
  Already experimenting with an explicit `digest-algorithm` parameter to enable
  non-sha256 verification — directly motivated by the same multi-algorithm use case.

- **regclient** — [`scheme/reg/blob.go#L370-L374`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/scheme/reg/blob.go#L370-L374), [#L581-L585](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/scheme/reg/blob.go#L581-L585)
  Constructs PUT URLs with `digest=<digest>`; would naturally extend to multiple parameters
  if the spec permitted it.

## Proposed Fix

### Amend [§POST then PUT](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#post-then-put)

After the sentence "Here, `<digest>` is the digest of the blob being uploaded, and `<length>`
is its size in bytes.", add:

```markdown
Multiple `digest` query parameters MAY be provided in the same `PUT` request, each using a
different hashing algorithm (for example, `?digest=sha256:abc...&digest=sha512:def...`).
The registry MAY verify any or all of the provided digests but MUST return an error if the
blob content does not match a digest the registry chooses to verify.
```

### Amend [§Pushing a blob in chunks](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-a-blob-in-chunks)

After the closing PUT description, add:

```markdown
The closing `PUT` request MAY include multiple `digest` query parameters with different
hashing algorithms.
The registry MAY verify any or all of them but MUST reject the upload if verification fails
for any digest it chooses to check.
```
