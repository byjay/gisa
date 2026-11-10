# Correspondence — remote service control

| Model element | Code | Kind | Abstraction / obligation |
|---|---|---|---|
| `serviceEnabled`, `controlAvailable`, `revision` | `backend/cloudflare/src/index.js:36-57` (`getServiceState`, `updateServiceState`) | shared control state | One global Durable Object; each read/write is an atomic snapshot. |
| `adminAuthenticated`, `ToggleService` | `backend/cloudflare/src/index.js:109-135` (`/v1/admin/service-control`) | admin transition | Existing `requireAdmin` precedes DO access; model reduces token validation to a boolean. |
| `ProtectedStart` | `backend/cloudflare/src/index.js:85-93` (pre-handler gate) | request action | All non-allowlisted methods/paths are gated before auth/handler. |
| `FinishProtected` | `backend/cloudflare/src/index.js:303-309` (post-handler gate) | response action | A request completing while disabled or control-unavailable is replaced with 503. |
| `StartScheduled` | `backend/cloudflare/src/index.js:311-323` (`scheduled`) | event action | Scheduled work reads the DO before entering the generator. |
| `StartProvider`, `SkipProvider` | `backend/cloudflare/src/blog-drafts.js:183-192` (`createSlot`) | async boundary | Recheck after catalog/D1 awaits immediately before sending provider work. |
| `StartPersist`, `SkipPersist` | `backend/cloudflare/src/blog-drafts.js:193-197` (`createSlot`) | async boundary | Recheck after provider response before starting review-content finalization; discard content if OFF/unavailable is observed. |
| `FinishPersist` | `backend/cloudflare/src/blog-drafts.js:173-180` (`finishClaim`) | in-flight side effect | Review-content finalization already started before shutdown may still complete; review routes stay gated while OFF. |
| `SkipProvider`, `SkipPersist`, `FinishBlockedStatus` | `backend/cloudflare/src/blog-drafts.js:166-171,188-195` (`failClaim`) | status-only bookkeeping | OFF/unavailable can trigger an awaited failed-status update to release a claim; it carries no generated content. |
| `MC_bug.cfg` | `UseServiceGate = FALSE` | mutation | Removes route/scheduler/provider guards to demonstrate the frozen properties fail. |

## Property sources

- `docs/superpowers/specs/2026-10-28-remote-service-control.md:19`: while disabled,
  protected data/auth/billing/AI/progress access is blocked; only the listed control-plane
  endpoints remain available.
- `docs/superpowers/specs/2026-10-28-remote-service-control.md:26-27`: an already-running
  external AI side effect cannot be cancelled, but the system does not promise that it can be
  undone. A review-content finalize write already started can also finish after shutdown and is
  modeled separately as `FinishPersist`; shutdown does not cancel it. `failClaim` status-only
  writes are abstracted as `blocking` and contain no generated content.
- `docs/superpowers/specs/2026-10-28-remote-service-control.md:43-48`: disabled routes return
  `503 service_disabled`; admin control remains available; the finite-state model includes
  deliberate defect counterexamples.
