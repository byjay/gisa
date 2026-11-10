| # | Action | Code | Changed |
|---|---|---|---|
| 1 | `Init` |  | `revision` = 0; `scheduleState` = "idle"; `controlAvailable` = TRUE; `adminAuthenticated` = FALSE; `requestState` = "idle"; `serviceEnabled` = TRUE |
| 2 | `ControlUnavailable` | backend/cloudflare/src/index.js:36-43 | `controlAvailable` = FALSE |
| 3 | `StartScheduled` ⚠ | backend/cloudflare/src/index.js:313-326 | `scheduleState` = "loading" |
