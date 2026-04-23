# Missing: `BLOB_UNKNOWN` Error `detail` Field Schema

**Priority:** Important  
**Affects:** `PUT /v2/<name>/manifests/<reference>` (end-7), `POST /v2/<name>/blobs/uploads/` (end-4a/4b)  
**Current spec location:** [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes), [§Push](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#push)

## What Was Lost

The deleted `detail.md` contained a specific description of the `BLOB_UNKNOWN` and `DIGEST_INVALID` error codes that called out the structure of their `detail` fields:

> `BLOB_UNKNOWN`: This error MAY be returned when a blob is unknown to the registry in a
> specified repository. This can be returned with a standard get or if a manifest references
> an unknown layer during upload.
>
> `DIGEST_INVALID`: When a blob is uploaded, the registry will check that the content matches
> the digest provided by the client. The error MAY include a detail structure with the key
> "digest", including the invalid digest string.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/e20e7f0e419fc34928f934fb85e2bce1c83d11c5/detail.md#errors)*

The original `spec_before.md` also described this concretely in the context of manifest upload validation: when a manifest references blobs unknown to the registry, the response includes one `BLOB_UNKNOWN` error per unknown blob, each with a `detail` object containing the digest of the missing blob:

```json
{
    "errors": [
        {
            "code": "BLOB_UNKNOWN",
            "message": "blob unknown to registry",
            "detail": {
                "digest": "<missing digest>"
            }
        }
    ]
}
```

The current spec ([§Push](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#push)) says:

> When a manifest is rejected for this reason, it MUST result in one or more
> `MANIFEST_BLOB_UNKNOWN` errors.

But it does not specify:
1. That there SHOULD be one error per missing blob (not just one aggregate error).
2. What the `detail` field of `BLOB_UNKNOWN` or `MANIFEST_BLOB_UNKNOWN` contains.
3. The `detail.digest` schema.

Similarly for `DIGEST_INVALID` — the `detail.digest` field is documented in the original but absent from the current spec.

## Related Issues

- [#413](https://github.com/opencontainers/distribution-spec/issues/413) (open): "Clarify multiple multiple-error semantics" — broader question about how clients should interpret multiple error codes in a single response, which also touches the `detail` field structure.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (server)** — [`registry/api/v2/descriptors.go#L617-L632`](https://github.com/distribution/distribution/blob/v2.7.1/registry/api/v2/descriptors.go#L617-L632)
  ```json
  {
      "errors:" [{
          "code": "BLOB_UNKNOWN",
          "message": "blob unknown to registry",
          "detail": {
              "digest": "<digest>"
          }
      }]
  }
  ```
  The canonical implementation documented the `detail.digest` schema in its endpoint descriptor table since v2.7.1. This is the source document from which the `detail.md` content originated.
  > Current behavior: [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go) — same schema still present in the descriptors for both `BLOB_UNKNOWN` (with `detail.digest`) and `DIGEST_INVALID` (with `detail.digest` containing the invalid digest string); only the spec lost it.

### Other implementations

- **olareg (server)** — [`types/errors.go`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/types/errors.go)
  Constructs error responses with the `BLOB_UNKNOWN` code and passes the digest as the detail string.

- **cue-labs-oci (shared)** — [`ociregistry/error.go#L321`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/error.go#L321)
  ```go
  ErrBlobUnknown = NewError("blob unknown to registry", "BLOB_UNKNOWN", nil)
  ```

## Proposed Fix

### Amend the error code table in [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

Update the descriptions for code-1 and code-4:

```markdown
| code-1 | `BLOB_UNKNOWN` | blob unknown to registry; the `detail` field SHOULD be an object with a `digest` key whose value is the digest of the unknown blob |
| code-4 | `DIGEST_INVALID` | provided digest did not match uploaded content; the `detail` field SHOULD be an object with a `digest` key containing the invalid digest string |
```

### Amend [§Push](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#push)

After the `MANIFEST_BLOB_UNKNOWN` sentence, add:

````markdown
When one or more referenced blobs are unknown, the registry SHOULD return one
`MANIFEST_BLOB_UNKNOWN` error per unknown blob.
Each error's `detail` field SHOULD be an object with a `digest` key containing the digest
of the unknown blob, for example:

```json
{
    "errors": [
        {
            "code": "MANIFEST_BLOB_UNKNOWN",
            "message": "manifest references a manifest or blob unknown to registry",
            "detail": {
                "digest": "sha256:abc123..."
            }
        }
    ]
}
```
````
