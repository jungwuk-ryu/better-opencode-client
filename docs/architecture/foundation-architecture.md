# Foundation Architecture

## Product Direction

This client is an OpenCode server client first and a Flutter app second. The runtime contract comes from the server's OpenAPI document and live capability probes, not from hard-coded assumptions about any single OpenCode release.

## Runtime Layers

### Connection Context

Every live store is keyed by:

- server profile
- directory
- workspace

This avoids cross-project state leakage and matches OpenCode's routed server model.

### Capability Registry

The capability registry merges four inputs:

1. `GET /global/health` metadata
2. `GET /doc` path and schema inspection
3. endpoint probe responses
4. optional experimental endpoint availability

The registry publishes boolean and structured capabilities such as:

- session share
- session fork
- session summarize
- session revert
- question flow
- permission flow
- provider OAuth
- MCP auth
- TUI control
- experimental tool schema inspection

### Spec Preservation

All decoded config and spec-backed models preserve raw JSON alongside typed fields. Writes merge edited known fields back into the original document so unknown future keys are not lost.

### Live Event Architecture

The app uses SSE with two streams:

- global stream for instance-level events
- scoped stream for active project and session events

An `EventReducer` is the single writer for live session, message, todo, question, and permission state. The reducer must:

- coalesce deltas and full updates
- tolerate duplicate delivery
- detect stale streams via heartbeat timeout
- trigger refetch-based recovery when stream state becomes unsafe

### Rendering Model

Chat rendering is part-based. A message part registry maps server part kinds to Flutter widgets and fallback inspectors so unknown part kinds remain visible during forward-compatibility windows.

## Initial Package Layout

- `lib/src/core/network`
- `lib/src/core/spec`
- `lib/src/core/session_state`
- `lib/src/core/persistence`
- `lib/src/features/connection`
- `lib/src/features/projects`
- `lib/src/features/chat`
- `lib/src/features/files`
- `lib/src/features/tools`
- `lib/src/features/terminal`
- `lib/src/features/settings`
- `lib/src/design_system`
- `lib/src/i18n`

## Verification Strategy

- Fixture-backed tests validate probe parsing, capability derivation, unknown-field preservation, SSE heartbeat behavior, and event reduction.
- Manual QA starts with fixture-driven debug surfaces before live server integration.
- UI parity work comes after the connection, capability, and stream foundations are proven.
