# Missing: PUT Manifest 400 Error Codes in Endpoint Table

**Priority:** Important  
**Affects:** `PUT /v2/<name>/manifests/<reference>` (end-7a, end-7b)  
**Current spec location:** [§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints)

## What Was Lost

This is a focused subset of the broader [per-endpoint-error-codes](per-endpoint-error-codes.md)
issue, called out separately due to its practical severity.

The current [§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints) table shows:

```
| end-7a | `PUT` | `/v2/<name>/manifests/<reference>` | `201` | `404`/`413` |
```

`400 Bad Request` does not appear as a failure code at all. Yet a PUT manifest can legitimately
fail with 400 for several reasons that the spec describes in prose:

1. **Invalid name** (`NAME_INVALID`) — the `<name>` path component is malformed.
2. **Invalid manifest content** (`MANIFEST_INVALID`) — the manifest JSON fails schema
   validation.
3. **Unknown referenced blob** (`MANIFEST_BLOB_UNKNOWN`) — the manifest references a blob
   or manifest not present in the registry (described in [§Push](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#push)).

A client receiving a 400 on PUT manifest has no way to know what went wrong without parsing
the error body — but the endpoint table implies 400 should not happen at all.

The original `spec_before.md` and `detail.md` both listed 400 as a defined failure code for
PUT manifest with the specific error codes above.

## Related Issues

- [#413](https://github.com/opencontainers/distribution-spec/issues/413) (open): "Clarify multiple multiple-error semantics" — overlaps; asks which error codes are valid per endpoint.
- [#418](https://github.com/opencontainers/distribution-spec/issues/418) (open): "Error code requirement seems too strict" — the strict MUST list makes it unclear what code to return for validation failures.

## Related PRs

- [#555](https://github.com/opencontainers/distribution-spec/pull/555) — "Align endpoint status with rest of spec" (merged): aligned endpoint table for several endpoints but did **not** add `400` to the PUT manifest rows (end-7a, end-7b).

## Evidence From Implementations

- **distribution** (server) — [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go)
  PUT manifest failure responses include `400` with `MANIFEST_INVALID`, `MANIFEST_BLOB_UNKNOWN`,
  `NAME_INVALID` as defined error codes.

- **distribution** (server handler) — [`registry/handlers/manifests.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/handlers/manifests.go)
  Returns 400 for manifest validation errors.

- **olareg** — [`types/errors.go`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/types/errors.go)
  Defines `MANIFEST_INVALID` and `MANIFEST_BLOB_UNKNOWN` error constructors that produce
  400 responses.

- **zot** — [`pkg/api/routes.go`](https://github.com/project-zot/zot/blob/9ba59559d2f4bf2502e7fb4efa120e5558ee7bb6/pkg/api/routes.go)
  Returns 400 with appropriate error codes for manifest validation failures.

## Proposed Fix

### Update the endpoint table rows for end-7a and end-7b in [§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints)

```
| end-7a | `PUT` | `/v2/<name>/manifests/<reference>`          | `201` | `400`/`404`/`413` |
| end-7b | `PUT` | `/v2/<name>/manifests/<digest>?tag=1&tag=2` | `201` | `400`/`404`/`413` |
```

### Add a note in [§Pushing Manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-manifests)

After the `MANIFEST_BLOB_UNKNOWN` sentence, add:

```markdown
If the manifest fails validation, the registry MUST return `400 Bad Request`.
The response body SHOULD contain one or more of the following error codes:

| Error Code              | Condition |
|-------------------------|-----------|
| `NAME_INVALID`          | The repository `<name>` is not a valid repository name |
| `MANIFEST_INVALID`      | The manifest body failed schema or content validation |
| `MANIFEST_BLOB_UNKNOWN` | The manifest references a blob or manifest not present in the registry |
```
