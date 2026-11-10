| # | Action | Code | Changed |
|---|---|---|---|
| 1 | `Init` |  | `revision` = 0; `scheduleState` = "idle"; `controlAvailable` = TRUE; `adminAuthenticated` = FALSE; `requestState` = "idle"; `serviceEnabled` = TRUE |
| 2 | `ControlUnavailable` | backend/cloudflare/src/index.js:36-43 | `controlAvailable` = FALSE |
| 3 | `StartProtected` | backend/cloudflare/src/index.js:85-93 | `requestState` = "running" |
| 4 | `FinishProtected` | backend/cloudflare/src/index.js:303-309 | `requestState` = "accepted" |
| 5 | `StartScheduled` ⚠ | backend/cloudflare/src/index.js:311-323 | `scheduleState` = "loading" |
