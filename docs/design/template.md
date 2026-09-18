# Capability name

<!-- Copy to docs/design/<capability-id>.md when a capability outgrows its section in spec.md,
link the page from that section, replace every <placeholder> and delete this comment. -->

- Capability: `<capability-id>` in the [registry](spec.md#capability-registry)
- Problem: what a user cannot do or trust today, in their terms.

## Behavior

Commands, flags and defaults; inputs and outputs; file formats; error cases and exit codes. Mark
contracts that other capabilities consume.

## Boundaries

What this capability does not do, and which capability owns the adjacent behavior.

## Design

Modules and imports from the [architecture](architecture.md); public types, error inductives and
the pure/IO split; state, concurrency and cancellation; theorems that pin the contract; new
dependencies from the [dependency table](spec.md#dependencies).

## Evaluation

| Gate | Evidence |
| --- | --- |
| Acceptance signal | Theorem, `#guard`, `#guard_msgs` test, fixture or declared run that proves it |

Valid negative result: what a supported "no" looks like and what it leaves in place.
