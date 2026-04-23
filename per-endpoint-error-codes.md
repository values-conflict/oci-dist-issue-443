# Missing: Per-Endpoint Enumerated Error Codes

**Priority:** Important  
**Affects:** All endpoints  
**Current spec location:** [§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints)

## What Was Lost

The deleted `detail.md` documented, for every single endpoint, the exact set of error codes that MAY be returned for each failure HTTP status.
This was the most detailed part of the original specification and totalled over 3,000 lines.
While the level of detail in `detail.md` may have been excessive for the main spec, the *endpoint table* in the original spec listed failure codes inline, and the spec prose described the 400-level error codes per endpoint.

The current [§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints) table lists only a simplified failure code set (e.g., `404`, `400`/`405`) with no information about *which* error code in the JSON body corresponds to which failure condition.

### Key examples of lost per-endpoint error code mappings

**`PUT /v2/<name>/manifests/<reference>` (end-7a, end-7b)**: The original listed these 400-class error codes for a PUT manifest:
- `NAME_INVALID` — invalid repository name
- `TAG_INVALID` — manifest tag did not match URI tag  
- `MANIFEST_INVALID` — manifest failed validation
- `MANIFEST_UNVERIFIED` — manifest failed signature verification
- `BLOB_UNKNOWN` — manifest references an unknown blob

The current endpoint table shows only `404` and `413` as failure codes — all 400-class validation errors are absent.
This is the most practically severe gap since it leaves clients with no guidance on why a manifest push was rejected with `400 Bad Request`.

Note that in distribution v2.7.1, unknown-blob errors on manifest push returned `MANIFEST_INVALID` (not the later-introduced `MANIFEST_BLOB_UNKNOWN`); the distinction was introduced after the spec reorganization.

**`GET /v2/<name>/blobs/<digest>` (end-2)**: Original 400-class codes: `NAME_INVALID`, `DIGEST_INVALID`.

**`POST /v2/<name>/blobs/uploads/` (end-4a)**: Original 400-class codes: `DIGEST_INVALID`, `NAME_INVALID`.

**`PATCH /v2/<name>/blobs/uploads/<reference>` (end-5)**: Original 400-class codes: `DIGEST_INVALID`, `NAME_INVALID`, `BLOB_UPLOAD_INVALID`, `BLOB_UPLOAD_UNKNOWN`.

**`PUT /v2/<name>/blobs/uploads/<reference>` (end-6)**: Original 400-class codes: `DIGEST_INVALID`, `NAME_INVALID`, `BLOB_UPLOAD_INVALID`, `BLOB_UPLOAD_UNKNOWN`, `SIZE_INVALID`.

## Related Issues

- [#443](https://github.com/opencontainers/distribution-spec/issues/443) (open): @corhere [comments](https://github.com/opencontainers/distribution-spec/issues/443#issuecomment-1644724047) on the weakening of error response requirements — the original spec's per-endpoint header/parameter tables (which included which error codes applied where) were lost in the reorganization.
- [#413](https://github.com/opencontainers/distribution-spec/issues/413) (open): "Clarify multiple multiple-error semantics" — asks which error codes apply in which situations, which is exactly the per-endpoint information that was lost.
- [#418](https://github.com/opencontainers/distribution-spec/issues/418) (open): "Error code requirement seems too strict" — argues the exhaustive list is both too strict and underdocumented in context.

## Related PRs

- [#555](https://github.com/opencontainers/distribution-spec/pull/555) — "Align endpoint status with rest of spec" (merged): aligned the endpoint table for delete operations and cross-repo mounts; added 202 to the mount endpoint. Did **not** add per-endpoint error code detail or add 400 to PUT manifest.

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (server)** — [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/v2.7.1/registry/api/v2/descriptors.go)
  The entire file is a machine-readable per-endpoint mapping of error codes to HTTP status codes — the source document that `detail.md` was generated from. It covers every endpoint with the exact error codes that can be returned for each HTTP status. The current spec deleted this mapping; the canonical implementation still carries it.
  > Current behavior: [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go) — unchanged; still a comprehensive per-endpoint error code table, only the spec no longer reflects it.

- **distribution v2.7.1 (server, PUT manifest specifically)** — [`registry/handlers/manifests.go#L247-L274`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/manifests.go#L247-L274)
  ```go
  if err == distribution.ErrBlobUnknown {
      imh.Errors = append(imh.Errors, v2.ErrorCodeManifestInvalid.WithDetail(err))
  ...
  imh.Errors = append(imh.Errors, v2.ErrorCodeTagInvalid.WithDetail(err))
  ```
  In v2.7.1, PUT manifest returned 400 with `MANIFEST_INVALID`, `TAG_INVALID` — none of which appear in the current endpoint table.
  > Current behavior: [`registry/handlers/manifests.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/handlers/manifests.go) — now returns `MANIFEST_BLOB_UNKNOWN` for missing blobs (split from `MANIFEST_INVALID` in a later version); still returns 400 for all validation failures; still absent from the endpoint table.

### Other implementations

- **olareg (server)** — [`types/errors.go`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/types/errors.go)
  Defines `ErrInfoBlobUploadUnknown`, `ErrInfoDigestInvalid`, `ErrInfoNameInvalid`, etc. as
  distinct error constructors used in specific endpoint handlers.

- **cue-labs-oci (shared)** — [`ociregistry/error.go`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/error.go)
  Maps each error type to a specific code and HTTP status, e.g.
  `ErrBlobUploadUnknown` → `BLOB_UPLOAD_UNKNOWN` → 404,
  `ErrManifestUnknown` → `MANIFEST_UNKNOWN` → 404.

### Clients that parse specific error codes from responses

- **containerd (client)** — [`core/remotes/docker/errdesc.go`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/errdesc.go)
  Full registry of error descriptors including `BLOB_UNKNOWN`, `BLOB_UPLOAD_UNKNOWN`,
  `DIGEST_INVALID`, `NAME_INVALID`, `SIZE_INVALID`, `MANIFEST_INVALID`, etc., each with HTTP
  status code mappings.

- **google/go-containerregistry (client)** — [`pkg/v1/remote/transport/error.go`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/transport/error.go)
  Parses `TOOMANYREQUESTS`, `UNAUTHORIZED`, `DENIED`, `BLOB_UNKNOWN`, `MANIFEST_UNKNOWN`,
  and `UNKNOWN` from response bodies.

## Proposed Fix

### Option A: Extend the endpoint table in [§Endpoints](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#endpoints)

Add an "Error Codes" column listing the JSON body error codes that correspond to each failure HTTP status.
Example for end-7a:

| ID    | Method | API Endpoint                               | Success     | Failure HTTP | Error Codes (body) |
|-------|--------|--------------------------------------------|-------------|-------------|---------------------|
| end-7a | `PUT` | `/v2/<name>/manifests/<reference>`         | `201`       | `400`       | `NAME_INVALID`, `MANIFEST_INVALID`, `MANIFEST_BLOB_UNKNOWN` |
|       |        |                                            |             | `413`       | *(no body required)* |
|       |        |                                            |             | `404`       | `NAME_UNKNOWN` |

### Option B: Add per-endpoint error code tables in prose

Add after each endpoint's description a table enumerating errors, e.g. for PUT manifest in [§Pushing Manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-manifests):

```markdown
**Error codes for `PUT /v2/<name>/manifests/<reference>`:**

| HTTP Status | Error Code             | Condition |
|-------------|------------------------|-----------|
| 400         | `NAME_INVALID`         | Invalid repository name |
| 400         | `MANIFEST_INVALID`     | Manifest failed validation |
| 400         | `MANIFEST_BLOB_UNKNOWN`| Manifest references unknown blob(s) |
| 404         | `NAME_UNKNOWN`         | Repository not found |
| 413         | *(none)*               | Manifest exceeds size limit |
```

Option B is more comprehensive and was the original approach; Option A is more compact and more appropriate for a summary specification.

### Immediate fix: update the endpoint table for end-7a and end-7b

As the most practically impactful gap, the PUT manifest rows should be corrected first:

```
| end-7a | `PUT` | `/v2/<name>/manifests/<reference>`          | `201` | `400`/`404`/`413` |
| end-7b | `PUT` | `/v2/<name>/manifests/<digest>?tag=1&tag=2` | `201` | `400`/`404`/`413` |
```

And add to [§Pushing Manifests](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#pushing-manifests):

```markdown
If the manifest fails validation, the registry MUST return `400 Bad Request`.
The response body SHOULD contain one or more of the following error codes:

| Error Code              | Condition |
|-------------------------|-----------|
| `NAME_INVALID`          | The repository `<name>` is not a valid repository name |
| `MANIFEST_INVALID`      | The manifest body failed schema or content validation |
| `MANIFEST_BLOB_UNKNOWN` | The manifest references a blob or manifest not present in the registry |
```
