| # | Action | Code | Changed |
|---|---|---|---|
| 1 | `Init` |  | `revision` = 0; `scheduleState` = "idle"; `controlAvailable` = TRUE; `adminAuthenticated` = FALSE; `requestState` = "idle"; `serviceEnabled` = TRUE |
| 2 | `StartProtected` | backend/cloudflare/src/index.js:85-93 | `requestState` = "running" |
| 3 | `FinishProtected` ⚠ | backend/cloudflare/src/index.js:303-309 | `requestState` = "accepted" |
