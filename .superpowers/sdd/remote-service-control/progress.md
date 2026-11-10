# SDD ledger — plan: remote-service-control

## Scope
Implement an operator-controlled server kill switch for the installed GISACLUB app. This checkout is `E:\gisaclub` on `main` and contains extensive unrelated/previous uncommitted source and data-separation work. User repeatedly specified this exact folder as the active editing path. Do not reset, stage, or commit pre-existing changes.

## Ruling
Use a single Durable Object rather than Workers KV: Cloudflare documents KV propagation can take 60 seconds or more; the requested switch controls access to study data and the update manifest. Existing Android/Flutter and Worker paths already use server-side admin verification and `SETTINGS` only for version manifests. The code’s route handler currently returns early from many routes, so a request gate plus common post-handler response gate is required.

## Preflight conflict scan
| Area | Existing uncommitted work | Ruling |
|---|---|---|
| Worker `src/index.js`, `wrangler.toml`, `src/admin.js` | Current auth routes, study/content routes and settings changed in this checkout | Read current version, preserve all existing routes, add only control plane/gating |
| Flutter `lib/main.dart`, `remote_content_api.dart`, `study_data.dart` | Server-only data flow and generation invalidation already changed | Extend current root/auth/data flow; preserve server-only edits |
| Existing tests | Worker tests and Flutter security tests are untracked | Preserve; add separate tests and run the whole targeted suites |
| Study content and OLD moves | Large pre-existing deletes and untracked contents | Do not touch |

## Plan status
- [x] Read source routes, app bootstrap, update service, cache invalidation, admin auth, and project separation checklist.
- [x] Search Warehouse/OpenFeature option; no reusable service-control module was found, no dependency added.
- [x] Write design and two subsystem plans.
- [x] Implement Worker DO and route gate; disabled mode blocks all non-allowlisted HTTP paths before auth and rechecks protected responses.
- [x] Implement Flutter client gate/admin control; status checks and local cache invalidation are covered by Flutter tests.
- [x] Build bounded TLA+ model, mutation and reachability counterexamples, model the in-flight D1-write boundary explicitly, and record source correspondence in `formal/remote-service-control/`.
- [x] Review diffs, run focused/full suites, Android debug build, and analyzer. A Kotlin daemon cache warning occurred but Gradle completed.
- [x] Update HANDOFF and separation checklist with local evidence and remaining deployment requirements.
- [ ] Continue cafe promotion request only if cafe rules explicitly permit a development-stage product post.

## Verification boundaries
No live Cloudflare deployment or production DO data changes. A local green suite does not prove deployed behavior. KV/DO binding rollout and runtime smoke checks remain a later deployment gate.
