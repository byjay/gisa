# CORRESPONDENCE — rewarded-ad grant

| Model action/state | Intended implementation | Abstraction and obligation |
|---|---|---|
| `Receive(d)` | Future Worker AdMob SSV endpoint: query parse + Google signature verification | Only verified signed transaction ID, allowed ad unit, reward item/amount and account binding enter trusted state. Currently no SSV endpoint exists. |
| `Check(d)` atomic branch | Future D1 atomic transaction/conditional update keyed by (user, quota-day, transaction_id) | Insert dedupe record and increment quota/ledger atomically. Unique constraint/transaction semantics must match this atomic action. |
| `Check(d)` buggy branch | Deliberately split read/check before asynchronous credit | Models two callbacks both observing unseen ID and remaining quota. This is a mutation used to show the safety property has a counterexample. |
| `Apply(d)` | Future ledger/quota increment | A separate side effect can race if no transaction/claim; modeled only in buggy variant. |
| `Record(d)` | Future processed transaction record | Late record allows duplicate callbacks to pass Check. |
| `DailyLimit` | Future server configured per-user per-day limit | Model uses one only to keep state space small; implementation limit is not chosen. |
| `Verified` | Future successful AdMob SSV signature and policy/config checks | Forged or invalid client callback is abstracted as absent from Verified and cannot be received as trusted. |

## Existing source baseline

- `pubspec.yaml`: `google_mobile_ads` absent; no client reward callback exists.
- `backend/cloudflare/src/billing.js:13-15`: purchase verification is deliberately 503 fail-closed; this is not an ad reward handler.
- Thus model actions currently have no production code correspondence. They are requirements for a future implementation, not claims about current runtime behavior.
