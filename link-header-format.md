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

The angle-bracket syntax for `Link` headers is defined in
[RFC 5988 §5](https://www.rfc-editor.org/rfc/rfc5988#section-5), which is already referenced
in the spec. An implementer reading RFC 5988 would find the format. **This is therefore not
missing normative content** — it is a request for an explicit example and clarifying prose
because the RFC reference alone has demonstrably not been sufficient in practice.

## What Was Lost

The original spec included a concrete example with a named callout:

> **NOTE:** In the request template above, note that the brackets are required. For example,
> if the url is `http://example.com/v2/hello-world/tags/list?n=20&last=b`, the value of the
> header would be `<http://example.com/v2/hello-world/tags/list?n=20&last=b>; rel="next"`.
>
> — *[§Pagination](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#pagination)*

Also lost: the termination-condition statement ("if the header is not present, the client can
assume that all results have been received") and a worked example with four tags at `n=2`.

## Evidence of Practical Need

Despite RFC 5988 being referenced, implementations have gotten the format wrong:

- **olareg** — [`tag.go#L57`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/tag.go#L57)
  Uses `<%s>; rel=next` — correctly.

- **olareg** (test) — [`olareg_test.go`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/olareg_test.go)
  Validates with `regexp.MustCompile(`^<([^>]+)>; rel=next$`)` — suggests the format has
  been wrong before and the test was written defensively.

- **regclient** — [`internal/httplink/httplink.go#L1`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/httplink/httplink.go#L1)
  Ships a dedicated RFC 5988 parser — suggesting that naive string parsing of the header
  without a proper parser is a real failure mode.

- **cue-labs-oci** — [`ociregistry/ociserver/lister.go#L150`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/lister.go#L150),
  [`ociregistry/ociclient/lister.go#L200`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociclient/lister.go#L200)
  Comments explicitly note "RFC 5988" — not obvious enough to omit.

- **google/go-containerregistry** — [`pkg/v1/remote/list.go#L100-L128`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/list.go#L100-L128)
  Custom parser extracts the URL from between `<>`.

## Proposed Fix

No new normative requirements — RFC 5988 already covers them. Add to [§Listing Tags](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-tags):

```markdown
Per [RFC 5988](https://www.rfc-editor.org/rfc/rfc5988), the URL in the `Link` header MUST
be enclosed in angle brackets. For example:

```
Link: </v2/<name>/tags/list?n=20&last=tagname>; rel="next"
```

When no `Link` header is present in a response, the client SHOULD assume it has received
the complete result set.

For example, given a repository with tags `v1`, `v2`, `v3`, `v4` and a request for `n=2`:
- Response 1: tags `["v1","v2"]`, `Link: </v2/<name>/tags/list?n=2&last=v2>; rel="next"`
- Response 2 (following the Link): tags `["v3","v4"]`, no `Link` header — end of list.

Clients SHOULD use the URL from the `Link` header verbatim rather than constructing it
manually, as the registry MAY include opaque pagination state in query parameters.
```
