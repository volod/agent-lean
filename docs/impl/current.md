# Current Implementation

This index describes behavior available now. Product intent is in the
[specification](../design/spec.md), remaining work in the [plan](plan.md), and evidence and
decisions in the [task records](records/README.md).

## Documentation shape

Each capability gets one page under `current/` when its first task is accepted, linked from the
table below and from its registry row. A page states behavior, modules, theorems, commands and
tests, and links the records that prove them. When a page grows, it becomes a short index of
focused pages under `current/<capability>/`. Plans, dates and history do not belong here.

## Areas

| Area | Owns | State |
| --- | --- | --- |
| [Project foundation](current/project-foundation.md) | Lake layout, `agent-lean` command seam, `lake` gates, options, CI, agent rules, planning tooling | Shipped |
| [Release distribution](current/release-distribution.md) | `lake exe repo dist`, native release runners, checksums, tag release workflow | Shipped |
