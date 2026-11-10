# Scope — remote service control

## Concern

Prove the service kill-switch guard at the Worker route and scheduled-draft boundaries. In
particular, a disabled or unreadable control state must prevent new protected requests,
scheduled work, provider calls, and reviewable-draft content finalization; a provider result
observed after shutdown must not start that content write.

## Modeled

- One Worker request and one scheduled draft slot.
- Service enabled/disabled, Durable Object state available/unavailable, and admin authorization.
- Protected request start and response acceptance.
- Scheduled job start, provider call start, provider completion, post-provider check, reviewable
  content-write start/completion, and status-only failure bookkeeping after service-off is seen.
- Admin toggle authorization and service revision in the finite range 0..2.

## Abstracted

- All protected HTTP routes share one guard; the public status, health, admin verification,
  admin token issue, admin control, and logout allowlist is represented by omission from this
  protected-route state machine.
- The Durable Object read/write is linearizable. Its storage transaction and HTTP request
  handlers are atomic between the modeled `await` boundaries.
- Three parallel draft slots are represented by one slot. Catalog and claim calls are represented
  as the `loading` phase; provider output is opaque. The D1 content finalize call has a separate
  `persisting` phase. `failClaim` status-only writes are abstracted as `blocking` and contain no
  generated provider content.
- OAuth/session cryptography, D1 SQL semantics, Cloudflare regional scheduling, and provider
  internals are not modeled.

## Assumptions and limits

- A provider request already sent cannot be cancelled by the Worker. Its result is checked again
  and discarded if service-off/unavailable is observed before reviewable-content finalization
  starts. If service-off happens after that write has started, it can still complete; the model
  treats it as an already-started side effect. `failClaim` may write only failure status while OFF
  to release a generating claim; it does not store generated title/body/provider content. Protected
  draft routes remain blocked while service-off is active, but this model does not guarantee an
  already-started private content row is absent after service re-enable.
- Service state may change between any modeled actions; a Durable Object read itself returns a
  valid snapshot or fails.
- The model checks safety, not eventual completion. No fairness is assumed for external services.
- Bounds are a single request, one scheduled slot, one admin, and revisions 0..2; this is not a
  proof of production deployment behavior or Cloudflare availability.
