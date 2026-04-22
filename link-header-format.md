# Missing: Pagination `Link` Header Exact Wire Format

**Priority:** Important  
**Affects:** `GET /v2/<name>/tags/list` (end-8b), `GET /v2/<name>/referrers/<digest>` (end-12a)  
**Current spec location:** [§Listing Tags](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-tags), [§Listing Referrers](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-referrers)

## What Was Lost

The original spec included an explicit example of the exact `Link` header wire format,
including the **required angle brackets** around the URL:

```http
200 OK
Content-Type: application/json
Link: <<url>?n=<n from the request>&last=<last tag value from previous response>>; rel="next"
```

And a specific callout note:

> **NOTE:** In the request template above, note that the brackets are required. For example,
> if the url is `http://example.com/v2/hello-world/tags/list?n=20&last=b`, the value of the
> header would be `<http://example.com/v2/hello-world/tags/list?n=20&last=b>; rel="next"`.
> Please see [RFC5988](https://tools.ietf.org/html/rfc5988) for details.
>
> — *[§Pagination](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#pagination)*

The original also specified the termination condition explicitly:

> The presence of the `Link` header communicates to the client that the entire result set has
> not been returned and another request MAY be issued. If the header is not present, the
> client can assume that all results have been received.
>
> — *[§Pagination](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#pagination)*

The current spec ([§Listing Tags](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-tags)) says:

> If included, the `Link` header MUST be set according to RFC5988 with the Relation Type
> `rel="next"`.

This is correct but loses:
1. The **explicit angle-bracket example** — implementations have historically gotten this
   wrong (emitting bare URLs without `<>`).
2. The **absence of Link = end of results** statement.
3. The worked example walking through four tags with `n=2`.

## Evidence From Implementations

### Servers emitting Link with angle brackets

- **olareg** — [`tag.go#L57`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/tag.go#L57)
  ```go
  w.Header().Add("Link", fmt.Sprintf("<%s>; rel=next", next.String()))
  ```
  Correctly wraps URL in `<>`.

- **olareg** (referrers) — [`referrer.go#L71`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/referrer.go#L71), [#L114](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/referrer.go#L114), [#L171](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/referrer.go#L171)

- **cue-labs-oci** — [`ociregistry/ociserver/lister.go#L150`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociserver/lister.go#L150)
  ```go
  // makeNextLink returns an RFC 5988 Link value
  ```

- **distribution** (server) — [`registry/api/v2/descriptors.go`](https://github.com/distribution/distribution/blob/f3af4de047a01241bea867e755be18ac8b109f91/registry/api/v2/descriptors.go)
  Documents the format as `<<url>?n=<last n value>&last=<last entry from response>>; rel="next"`.

### Clients parsing Link header

- **regclient** — [`internal/httplink/httplink.go#L1`](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/httplink/httplink.go#L1)
  ```go
  // Package httplink parses the Link header from HTTP responses according to RFC5988
  ```
  Dedicated RFC 5988 Link header parsing package; extracts `<URL>` with angle brackets
  (lines [44](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/httplink/httplink.go#L44),
  [190](https://github.com/regclient/regclient/blob/1a4d357a3a6df1d4d4164bb1aa110fe0259a6c30/internal/httplink/httplink.go#L190)).

- **google/go-containerregistry** — [`pkg/v1/remote/list.go#L100-L128`](https://github.com/google/go-containerregistry/blob/d4f10504a3c9528aeb51c62c7a859cd0a47e07a8/pkg/v1/remote/list.go#L100-L128)
  ```go
  func getNextPageURL(resp *http.Response) (*url.URL, error) {
      link := resp.Header.Get("Link")
  ```
  Parses the `<URL>` out of the Link header.

- **cue-labs-oci** — [`ociregistry/ociclient/lister.go#L200`](https://github.com/cue-labs/oci/blob/3adeb866381942f8fcc777812752a5a9e8869b68/ociregistry/ociclient/lister.go#L200)
  ```go
  // Parse the link header according to RFC 5988.
  ```

- **olareg** (test) — [`olareg_test.go`](https://github.com/olareg/olareg/blob/b50ccb77a369011c861d04bdd993a1f959ccb1f8/olareg_test.go)
  Uses `regexp.MustCompile(`^<([^>]+)>; rel=next$`)` to validate the angle-bracket format.

## Proposed Fix

### Amend [§Listing Tags](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#listing-tags)

After the existing `Link` header sentence, add:

```markdown
The `Link` header MUST use the RFC 5988 format: the URL MUST be enclosed in angle brackets,
followed by `; rel="next"`. For example:

```
Link: </v2/<name>/tags/list?n=20&last=tagname>; rel="next"
```

The absence of a `Link` header in a response indicates that the client has received the
complete result set and no further pagination requests are necessary.

Compliant client implementations SHOULD always use the URL from the `Link` header value
when iterating through pages, rather than constructing the URL manually, as the server MAY
include additional query parameters necessary for correct pagination.
```

### Add worked example

```markdown
For example, given a repository with tags `v1`, `v2`, `v3`, `v4` and a page size of `n=2`:

- First request: `GET /v2/<name>/tags/list?n=2`
  - Response includes tags `["v1","v2"]` and `Link: </v2/<name>/tags/list?n=2&last=v2>; rel="next"`
- Second request follows the `Link` header URL
  - Response includes tags `["v3","v4"]` with no `Link` header, indicating end of list
```
