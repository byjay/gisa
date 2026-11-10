| # | Action | Code | Changed |
|---|---|---|---|
| 1 | `Init` |  | `revision` = 0; `scheduleState` = "idle"; `controlAvailable` = TRUE; `adminAuthenticated` = FALSE; `requestState` = "idle"; `serviceEnabled` = TRUE |
| 2 | `StartScheduled` | backend/cloudflare/src/index.js:311-323 | `scheduleState` = "loading" |
| 3 | `StartProvider` | backend/cloudflare/src/blog-drafts.js:183-192 | `scheduleState` = "provider" |
| 4 | `StartPersist` | backend/cloudflare/src/blog-drafts.js:193-197 | `scheduleState` = "persisting" |
| 5 | `ControlUnavailable` | backend/cloudflare/src/index.js:36-43 | `controlAvailable` = FALSE |
| 6 | `FinishPersist` ⚠ | backend/cloudflare/src/blog-drafts.js:173-180 | `scheduleState` = "persisted" |
