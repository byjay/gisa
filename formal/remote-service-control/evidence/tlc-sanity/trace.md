| # | Action | Code | Changed |
|---|---|---|---|
| 1 | `Init` |  | `revision` = 0; `scheduleState` = "idle"; `controlAvailable` = TRUE; `adminAuthenticated` = FALSE; `requestState` = "idle"; `serviceEnabled` = TRUE |
| 2 | `StartProtected` | backend/cloudflare/src/index.js:79-97 | `requestState` = "running" |
| 3 | `FinishProtected` ⚠ | backend/cloudflare/src/index.js:292-300 | `requestState` = "accepted" |
