# Missing: Explicit Compliance Definition

**Priority:** Important  
**Affects:** [§Conformance](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#conformance), [§Notational Conventions](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#notational-conventions)

## What Was Lost

The original spec had an explicit definition of what it means to be "compliant" with the
specification, tied directly to the RFC 2119 key words:

> An implementation is not compliant if it fails to satisfy one or more of the MUST,
> MUST NOT, REQUIRED, SHALL, or SHALL NOT requirements for the protocols it implements.
> An implementation is compliant if it satisfies all of the MUST, MUST NOT, REQUIRED,
> SHALL, and SHALL NOT requirements for the protocols it implements.
>
> — *[§Notational Conventions](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#notational-conventions)*

Also:

> The key words 'unspecified', 'undefined', and 'implementation-defined' are to be
> interpreted as described in the rationale for the C99 standard.
>
> — *[§Notational Conventions](https://github.com/opencontainers/distribution-spec/blob/a6e5b091b1468662730ab1e5be55c61838643ab4/spec.md#notational-conventions)*

The current spec ([§Notational Conventions](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#notational-conventions)) defines the RFC 2119 key words but does not define what
"compliant" means in terms of those words. The [§Conformance](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#conformance) section only points to
conformance tests and does not state the semantic definition.

This leaves two ambiguities:
1. Is an implementation compliant if it violates one SHOULD but satisfies all MUSTs? The
   original spec said yes (SHOULD violations do not cause non-compliance).
2. What do implementers do when the spec is silent (does not use MUST/SHOULD/MAY)? The C99
   "unspecified/implementation-defined" terminology provided a framework.

## Proposed Fix

### Amend [§Notational Conventions](https://github.com/opencontainers/distribution-spec/blob/ed885fa765593c5294d3b55c0c78ee52825647f0/spec.md#notational-conventions)

After the existing RFC 2119 key words sentence, add:

```markdown
An implementation is not compliant with this specification if it fails to satisfy one or more
of the MUST, MUST NOT, REQUIRED, SHALL, or SHALL NOT requirements for the protocols it
implements.
An implementation is compliant if it satisfies all the MUST, MUST NOT, REQUIRED, SHALL, and
SHALL NOT requirements for the protocols it claims to implement.

Where this specification uses the words "unspecified" or "implementation-defined", the
behavior in those cases is left to the discretion of the implementer and conformance testing
MUST NOT fail an implementation for any particular choice.
```
