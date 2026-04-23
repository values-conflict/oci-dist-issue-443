# Missing: HEAD Request as Mount Capability / Blob Existence Probe

**Priority:** Important  
**Affects:** `POST /v2/<name>/blobs/uploads/?mount=<digest>&from=<other_name>` (end-11)  
**Current spec location:** [§Mounting a blob from another repository](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#mounting-a-blob-from-another-repository)

## What Was Lost

The original spec included a specific client strategy note explaining how to distinguish
between two different 202 fallback scenarios:

> Note: a client MAY issue a HEAD request to check existence of a blob in a source repository
> to distinguish between the registry not supporting blob mounts and the blob not existing in
> the expected repository.
>
> — *[§Cross Repository Blob Mount](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#cross-repository-blob-mount)*

When a mount fails, the registry returns `202 Accepted` with a fresh upload URL. This 202
can mean either:
- The registry does not implement cross-repository mounts (falls back to standard upload), or
- The registry supports mounts but the specific blob does not exist in the source repository.

Without the HEAD probe hint, clients cannot distinguish these two cases and may waste bandwidth
uploading a blob that already exists on the registry under a different repository namespace.

The current spec ([§Mounting a blob from another repository](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#mounting-a-blob-from-another-repository)) says:

> Alternatively, if a registry does not support cross-repository mounting or is unable to
> mount the requested blob, it SHOULD return a `202`. This indicates that the upload session
> has begun and that the client MAY proceed with the upload.

But it does not tell the client *how* to determine which scenario it is facing.

## Related PRs

- [#275](https://github.com/opencontainers/distribution-spec/pull/275) — "Allow for automatic content discovery for cross-mounting blobs" (merged): added the *registry-side* behavior of automatically discovering and mounting blobs when the `from` parameter is provided, even without an exact match. This is a different angle from our issue, which is about the *client-side* HEAD probe to distinguish "registry doesn't support mounts" from "blob doesn't exist in source repo."

## Evidence From Implementations

### distribution v2.7 (canonical)

- **distribution v2.7.1 (server)** — [`registry/handlers/blobupload.go#L106-L144`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/blobupload.go#L106-L144)
  ```go
  if mountDigest != "" && fromRepo != "" {
      opt, err := buh.createBlobMountOption(fromRepo, mountDigest)
      ...
      if ebm, ok := err.(distribution.ErrBlobMounted); ok {
          // 201 Created — mounted
      }
  }
  w.WriteHeader(http.StatusAccepted)  // fallback: 202
  ```
  The v2.7.1 server already handled `mount=` and `from=` parameters and fell back to 202 on failure, but provided no mechanism for the client to distinguish "mount unsupported" from "blob not found." The HEAD probe hint existed in the spec to fill this client-side disambiguation gap.
  > Current behavior: unchanged structure; the server-side fallback behavior is identical.

### Clients using HEAD to probe before or after mount

- **google/go-containerregistry** — [`pkg/v1/remote/write.go#L173-L177`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/write.go#L173-L177)
  ```go
  // checkExistingBlob checks if a blob exists already in the repository by making a HEAD
  // request to the blob store API. GCR performs an existence check on the initiation if
  // "mount" is specified, even if no "from" sources are specified.
  func (w *writer) checkExistingBlob(ctx context.Context, h v1.Hash) (bool, error) {
  ```
  HEAD request is issued before attempting a mount to detect whether the blob exists at all.

- **google/go-containerregistry** — [`pkg/v1/remote/write.go#L204-L237`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/write.go#L204-L237)
  ```go
  if mount != "" && from != "" {
      uv.Set("mount", mount)
      ...
      logs.Warn.Printf("retrying without mount: %v", err)
  ```
  Falls back to upload on mount failure; uses the HEAD result to decide whether to try mount
  at all.

- **containerd** — [`core/remotes/docker/pusher.go#L577-L585`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/pusher.go#L577-L585)
  `requestWithMountFrom` appends `mount=<digest>&from=<repo>` and handles the 202 fallback.

### Servers implementing mount

- **olareg** — [`blob.go#L186`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/blob.go#L186)
  ```go
  // check for mount=digest&from=repo, consider allowing anonymous blob mounts
  ```

- **cue-labs-oci** — [`ociregistry/ociserver/writer.go#L155`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/writer.go#L155)
  ```go
  r.backend.MountBlob(ctx, rreq.FromRepo, rreq.Repo, ...)
  ```

## Proposed Fix

### Add to [§Mounting a blob from another repository](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#mounting-a-blob-from-another-repository)

After the `202` fallback paragraph, add:

```markdown
When a `202 Accepted` response is returned to a mount request, a client that needs to
distinguish between "registry does not support mounts" and "blob does not exist in the source
repository" MAY issue a `HEAD` request to `/v2/<other_name>/blobs/<digest>` against the
source repository before or after the mount attempt.

- A `200 OK` HEAD response indicates the blob exists in the source repository but the registry
  declined to mount it (e.g., cross-repository mounts are disabled).
- A `404 Not Found` HEAD response indicates the blob does not exist in the source repository.

In either case, the client SHOULD proceed with a normal blob upload using the session URL
returned in the `202 Accepted` response.
```
