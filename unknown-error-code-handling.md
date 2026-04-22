# Missing: Client MUST Treat Unknown Error Codes as `UNKNOWN`

**Priority:** Important  
**Affects:** [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

## What Was Lost

The original spec contained an explicit forward-compatibility requirement for clients
encountering error codes not listed in the spec:

> While the client can take action on certain error codes, the registry MAY add new error
> codes over time. All client implementations SHOULD treat unknown error codes as `UNKNOWN`,
> allowing future error codes to be added without breaking API compatibility. For the purposes
> of the specification error codes will only be added and never removed.
>
> — *[§Errors](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#errors)*

The current [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes) defines the table of known codes and the JSON
structure, but says nothing about how clients should handle error codes they do not recognize.
Without this language, a client that encounters an unrecognized error code (such as one added
in a future spec version) has no guidance and may crash, error out, or behave unpredictably.

The companion statement — "error codes will only be added and never removed" — gave implementers
a stability guarantee that is also now absent.

## Related Issues

- [#418](https://github.com/opencontainers/distribution-spec/issues/418) (open): "Error code requirement seems too strict" — directly about the same problem: the `code` field MUST be one of the listed codes, with no escape hatch for future or implementation-specific codes.

## Evidence From Implementations

Every major client and server implements the `UNKNOWN` fallback, demonstrating this is a real
operational need:

- **containerd** — [`core/remotes/docker/errdesc.go#L33-L36`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/errdesc.go#L33-L36)
  ```go
  // ErrorCodeUnknown is a generic error that can be used as a last
  // resort if there is not a normal error code that can describe the situation.
  ErrorCodeUnknown = Register("errcode", ErrorDescriptor{Value: "UNKNOWN", ...})
  ```

- **containerd** — [`core/remotes/docker/errcode.go#L184-L191`](https://github.com/containerd/containerd/blob/46a7bd7acb81c337f41587a2e071dd8b0f2e5eae/core/remotes/docker/errcode.go#L184-L191)
  ```go
  // 'ErrorCodeUnknown' will be returned if the error is not known.
  return ErrorCodeUnknown.Descriptor()
  ```

- **distribution** — [`internal/client/errors.go#L110`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/internal/client/errors.go#L110)
  ```go
  return errcode.ErrorCodeUnknown.WithMessage(details)
  ```
  Explicit fallback: when an error code in a response is not in the known registry, it is
  mapped to `UNKNOWN`.

- **cue-labs-oci** — [`ociregistry/error.go#L269`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/error.go#L269)
  ```go
  e.Code_ = "UNKNOWN"
  ```
  Default code assigned when an unspecified error is returned.

- **google/go-containerregistry** — [`pkg/v1/remote/transport/error.go#L133-L144`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/transport/error.go#L133-L144)
  ```go
  UnknownErrorCode ErrorCode = "UNKNOWN"
  ```
  Included in `temporaryErrorCodes` — unknown errors trigger retry logic.

## Proposed Fix

### Insertion point in [§Error Codes](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#error-codes)

After the error code table, add:

```markdown
The error code table above is exhaustive for this version of the specification.
Registries MUST NOT return error codes outside this table unless doing so via a registered
extension.
Registries MUST NOT remove error codes from responses in future versions of this specification;
error codes will only be added, never removed, to preserve backwards compatibility.

Clients SHOULD treat any unrecognized error code as equivalent to `UNKNOWN`.
This ensures that clients remain functional when communicating with a registry implementing a
newer version of this specification that introduces additional error codes.
```
