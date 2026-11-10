| # | Action | Code | Changed |
|---|---|---|---|
| 1 | `Init` |  | `revision` = 0; `scheduleState` = "idle"; `controlAvailable` = TRUE; `adminAuthenticated` = FALSE; `requestState` = "idle"; `serviceEnabled` = TRUE |
| 2 | `StartProtected` | backend/cloudflare/src/index.js:85-93 | `requestState` = "running" |
| 3 | `StartScheduled` | backend/cloudflare/src/index.js:311-323 | `scheduleState` = "loading" |
| 4 | `ControlUnavailable` | backend/cloudflare/src/index.js:36-43 | `controlAvailable` = FALSE |
| 5 | `SkipProvider` ⚠ | backend/cloudflare/src/blog-drafts.js:188-190 | `scheduleState` = "blocking" |
