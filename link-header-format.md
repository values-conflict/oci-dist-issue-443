# Clarification Needed: Pagination `Link` Header Exact Wire Format

**Priority:** Important  
**Affects:** `GET /v2/<name>/tags/list` (end-8b), `GET /v2/<name>/referrers/<digest>` (end-12a)  
**Current spec location:** [§Listing Tags](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-tags), [§Listing Referrers](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-referrers)

## Related Issues

- [#443](https://github.com/opencontainers/distribution-spec/issues/443) (open): @jonjohnsonjr [comments](https://github.com/opencontainers/distribution-spec/issues/443#issuecomment-1645701222): "I can't find any reference to the pagination mechanism for tag listing. I think this got dropped when catalog was [re]moved? It makes a lot more sense to me now that folks had started inventing new pagination mechanisms for the referrers API: they didn't have the existing mechanism to copy!"
- [#327](https://github.com/opencontainers/distribution-spec/issues/327) (open): "Inconsistent specification for endpoint end-8b's parameter `last`" — the endpoint table lists `last` as `<integer>` while the prose requires it to be a tag name; a separate pagination inconsistency that also traces to the lost detail.

## Related PRs

- [#496](https://github.com/opencontainers/distribution-spec/pull/496) — "Restore pagination information" (closed, **not merged**): explicitly attempted to restore this exact content from commit `c90b0f1`, including the angle-bracket example, the termination-condition statement, and the worked example. The PR body notes "This was restored from c90b0f145ac6bc09d2636ee214486ac333edc284."
- [#470](https://github.com/opencontainers/distribution-spec/pull/470) — "Tag pagination" (merged): added the `n`/`last` parameter language and the RFC 5988 `Link` header requirement now in the current spec. Did **not** restore the example or termination-condition statement.

## Note on RFC Coverage

The angle-bracket syntax for `Link` headers is defined in [RFC 5988 §5](https://www.rfc-editor.org/rfc/rfc5988#section-5), which is already referenced in the spec.
An implementer reading RFC 5988 would find the format.
**This is therefore not missing normative content** — it is a request for an explicit example and clarifying prose because the RFC reference alone has demonstrably not been sufficient in practice.

## What Was Lost

The original spec included a concrete example with a named callout:

> **NOTE:** In the request template above, note that the brackets are required. For example,
> if the url is `http://example.com/v2/hello-world/tags/list?n=20&last=b`, the value of the
> header would be `<http://example.com/v2/hello-world/tags/list?n=20&last=b>; rel="next"`.
>
> — *[§Pagination](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#pagination)*

Also lost: the termination-condition statement ("if the header is not present, the client can assume that all results have been received") and a worked example with four tags at `n=2`.

## Evidence of Practical Need

### distribution v2.7 (canonical)

- **distribution v2.7.1 (client)** — [`registry/client/repository.go`](https://github.com/distribution/distribution/blob/v2.7.1/registry/client/repository.go)
  ```go
  if link := resp.Header.Get("Link"); link != "" {
      linkURLStr := strings.Trim(strings.Split(link, ";")[0], "<>")
  ```
  The v2.7.1 client's tag pagination loop strips angle brackets with `strings.Trim(..., "<>")`, establishing that the angle-bracket wire format was the assumed contract from the start.
  > Divergence: the v2.7.1 **server** ([`registry/handlers/tags.go`](https://github.com/distribution/distribution/blob/v2.7.1/registry/handlers/tags.go)) had no pagination at all — `GetTags` returned all tags in a single response with no `Link` header. The client was written for a pagination protocol that the server had not yet implemented.
  > Current behavior: server-side pagination with `Link` headers is present but the explicit angle-bracket format note was never restored.

- **google/go-containerregistry (server)** — [`pkg/registry/manifest.go#L281-L320`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/registry/manifest.go#L281-L320)
  ```go
  // https://github.com/opencontainers/distribution-spec/blob/b505e9cc53ec499edbd9c1be32298388921bb705/detail.md#tags-paginated
  // Offset using last query parameter.
  if last := req.URL.Query().Get("last"); last != "" { ... }
  // Limit using n query parameter.
  if ns := req.URL.Query().Get("n"); ns != "" { ... }
  ```
  The ggcr server explicitly cites `detail.md#tags-paginated` in a comment, implements both `last` and `n` query parameters — but emits **no `Link` header** in the response when results are truncated. This is direct evidence that the loss of the `Link` header documentation caused an incomplete implementation: the server knows about the pagination parameters but not the response mechanism.

Despite RFC 5988 being referenced, implementations have gotten the format wrong:

- **olareg** (server) — [`tag.go#L57`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/tag.go#L57)
  Uses `<%s>; rel=next` — correctly.

- **olareg** (server, test) — [`olareg_test.go`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/olareg_test.go)
  Validates with ``regexp.MustCompile(`^<([^>]+)>; rel=next$`)`` — suggests the format has been wrong before and the test was written defensively.

- **regclient** (client) — [`internal/httplink/httplink.go#L1`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/httplink/httplink.go#L1)
  Ships a dedicated RFC 5988 parser — suggesting that naive string parsing of the header without a proper parser is a real failure mode.

- **cue-labs-oci** (server) — [`ociregistry/ociserver/lister.go#L150`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/lister.go#L150)
  Comment notes "RFC 5988" on the Link-building function.

- **cue-labs-oci** (client) — [`ociregistry/ociclient/lister.go#L200`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociclient/lister.go#L200)
  Comment notes "RFC 5988" on the Link-parsing function.

- **google/go-containerregistry** (client) — [`pkg/v1/remote/list.go#L100-L128`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/list.go#L100-L128)
  Custom parser extracts the URL from between `<>`.

## Proposed Fix

No new normative requirements — RFC 5988 already covers them.
Add two sentences to [§Listing Tags](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-tags) after the existing `Link` header sentence:

```markdown
Per [RFC 5988](https://www.rfc-editor.org/rfc/rfc5988), the URL in the `Link` header MUST be enclosed in angle brackets (e.g., `Link: </v2/<name>/tags/list?n=20&last=tagname>; rel="next"`).
When no `Link` header is present in a response, the client SHOULD assume it has received the complete result set.
Clients SHOULD use the URL from the `Link` header verbatim rather than constructing it manually, as the registry MAY include opaque pagination state in the URL.
```
