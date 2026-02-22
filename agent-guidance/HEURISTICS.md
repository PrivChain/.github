# Agent Heuristics

Operational heuristics for day-to-day implementation choices.

## Prioritization

- Security defects over feature work.
- Protocol correctness over developer convenience.
- Developer onboarding blockers over polish.

## Design Heuristics

- Prefer boring, proven primitives before novel abstractions.
- Keep public APIs small and versioned.
- Make protocol behavior explicit in specs before implementation.

## Delivery Heuristics

- Use feature flags for unfinished behavior.
- Treat migrations as first-class: include forward/backward paths.
- Keep CI checks fast enough for tight iteration loops.

## Documentation Heuristics

- Every externally visible behavior should have a matching doc entry.
- Record tradeoffs and non-goals to avoid ambiguity.
- Keep examples aligned with current APIs and test them in CI where possible.

## Incident Heuristics

- Contain first, diagnose second, optimize third.
- Prefer safe degradation over downtime when possible.
- Publish postmortems with concrete corrective actions.
