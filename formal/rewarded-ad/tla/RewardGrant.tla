-------------------------- MODULE RewardGrant --------------------------
EXTENDS Naturals, FiniteSets, RewardProperties

CONSTANTS GroupA, GroupB, GroupC, TxA, TxB, TxC, Verified, DailyLimit, AtomicGrant

Deliveries == GroupA \cup GroupB \cup GroupC
TransactionIds == {TxA, TxB, TxC}
TxOf(d) == IF d \in GroupA THEN TxA ELSE IF d \in GroupB THEN TxB ELSE TxC

ASSUME GroupA # {}
ASSUME GroupB # {}
ASSUME GroupC # {}
ASSUME GroupA \cap GroupB = {}
ASSUME GroupA \cap GroupC = {}
ASSUME GroupB \cap GroupC = {}
ASSUME Verified \subseteq Deliveries
ASSUME DailyLimit \in Nat
ASSUME AtomicGrant \in BOOLEAN

VARIABLES processed, granted, rejected, credits, pc
vars == <<processed, granted, rejected, credits, pc>>

Statuses == {"pending", "check", "apply", "record", "done", "drop"}

TypeOK ==
    /\ processed \subseteq TransactionIds
    /\ granted \subseteq TransactionIds
    /\ rejected \subseteq TransactionIds
    /\ credits \in 0..Cardinality(Deliveries)
    /\ pc \in [Deliveries -> Statuses]

Init ==
    /\ processed = {}
    /\ granted = {}
    /\ rejected = {}
    /\ credits = 0
    /\ pc = [d \in Deliveries |-> "pending"]

\* src: future Worker SSV handler (not implemented): verify signature, transaction and account binding.
Receive(d) ==
    /\ pc[d] = "pending"
    /\ IF d \in Verified
          THEN pc' = [pc EXCEPT ![d] = "check"]
          ELSE pc' = [pc EXCEPT ![d] = "drop"]
    /\ UNCHANGED <<processed, granted, rejected, credits>>

\* src: future D1 transaction (not implemented): dedupe + quota + ledger must be atomic.
Check(d) ==
    /\ pc[d] = "check"
    /\ IF AtomicGrant
          THEN
            /\ IF TxOf(d) \in processed
                  THEN
                    /\ pc' = [pc EXCEPT ![d] = "done"]
                    /\ UNCHANGED <<processed, granted, rejected, credits>>
                  ELSE IF credits < DailyLimit
                    THEN
                      /\ processed' = processed \cup {TxOf(d)}
                      /\ granted' = granted \cup {TxOf(d)}
                      /\ credits' = credits + 1
                      /\ pc' = [pc EXCEPT ![d] = "done"]
                      /\ UNCHANGED rejected
                    ELSE
                      /\ processed' = processed \cup {TxOf(d)}
                      /\ rejected' = rejected \cup {TxOf(d)}
                      /\ UNCHANGED <<granted, credits>>
                      /\ pc' = [pc EXCEPT ![d] = "done"]
          ELSE
            /\ IF TxOf(d) \in processed
                  THEN
                    /\ pc' = [pc EXCEPT ![d] = "done"]
                    /\ UNCHANGED <<processed, granted, rejected, credits>>
                  ELSE
                    /\ pc' = [pc EXCEPT ![d] = "apply"]
                    /\ UNCHANGED <<processed, granted, rejected, credits>>

\* src: intentionally unsafe split credit side effect (mutation only).
Apply(d) ==
    /\ ~AtomicGrant
    /\ pc[d] = "apply"
    /\ credits' = credits + 1
    /\ pc' = [pc EXCEPT ![d] = "record"]
    /\ UNCHANGED <<processed, granted, rejected>>

\* src: intentionally late dedupe record (mutation only).
Record(d) ==
    /\ ~AtomicGrant
    /\ pc[d] = "record"
    /\ processed' = processed \cup {TxOf(d)}
    /\ granted' = granted \cup {TxOf(d)}
    /\ pc' = [pc EXCEPT ![d] = "done"]
    /\ UNCHANGED <<rejected, credits>>

Next ==
    (\E d \in Deliveries : Receive(d) \/ Check(d) \/ Apply(d) \/ Record(d))
    \/ ((\A d \in Deliveries : pc[d] \in {"done", "drop"}) /\ UNCHANGED vars)

Spec == Init /\ [][Next]_vars

QuotaRespected == QuotaWithinLimit(credits, DailyLimit)
CreditMatchesLedger == LedgerMatchesBalance(credits, granted)
GrantsOnlyVerified == GrantsSubsetOfVerified(granted, {TxOf(d) : d \in Verified})
NoGrantRejected == GrantRejectDisjoint(granted, rejected)
EveryOutcomeProcessed == OutcomesAccounted(granted, rejected, processed)
\* Sanity assertion: this must fail because a verified event can receive a grant.
NobodyEverGranted == credits = 0
=============================================================================
