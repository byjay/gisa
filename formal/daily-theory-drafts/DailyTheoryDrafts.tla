---------------- MODULE DailyTheoryDrafts ----------------
EXTENDS FiniteSets, Naturals

CONSTANTS Workers, Slots
ASSUME Cardinality(Workers) = 2
ASSUME Cardinality(Slots) = 3

Statuses == {"empty", "generating", "review", "approved", "rejected", "failed"}
Decisions == {"approve", "reject"}
NoOwner == "none"

VARIABLES status, owner, stale, public
vars == <<status, owner, stale, public>>

Init ==
  /\ status = [s \in Slots |-> "empty"]
  /\ owner = [s \in Slots |-> NoOwner]
  /\ stale = [s \in Slots |-> FALSE]
  /\ public = [s \in Slots |-> FALSE]

Claim(w, s) ==
  /\ status[s] = "empty"
  /\ status' = [status EXCEPT ![s] = "generating"]
  /\ owner' = [owner EXCEPT ![s] = w]
  /\ stale' = [stale EXCEPT ![s] = FALSE]
  /\ UNCHANGED public

Expire(s) ==
  /\ status[s] = "generating"
  /\ stale[s] = FALSE
  /\ stale' = [stale EXCEPT ![s] = TRUE]
  /\ UNCHANGED <<status, owner, public>>

Reclaim(w, s) ==
  /\ status[s] = "generating"
  /\ stale[s] = TRUE
  /\ owner[s] # w
  /\ owner' = [owner EXCEPT ![s] = w]
  /\ stale' = [stale EXCEPT ![s] = FALSE]
  /\ UNCHANGED <<status, public>>

Complete(w, s) ==
  /\ status[s] = "generating"
  /\ owner[s] = w
  /\ status' = [status EXCEPT ![s] = "review"]
  /\ UNCHANGED <<owner, stale, public>>

Fail(w, s) ==
  /\ status[s] = "generating"
  /\ owner[s] = w
  /\ status' = [status EXCEPT ![s] = "failed"]
  /\ UNCHANGED <<owner, stale, public>>

Review(s, decision) ==
  /\ status[s] = "review"
  /\ decision \in Decisions
  /\ status' = [status EXCEPT ![s] = IF decision = "approve" THEN "approved" ELSE "rejected"]
  /\ UNCHANGED <<owner, stale, public>>

Terminated == \A s \in Slots : status[s] \in {"review", "approved", "rejected", "failed"}

PublishBug(s) ==
  /\ status[s] # "empty"
  /\ public[s] = FALSE
  /\ public' = [public EXCEPT ![s] = TRUE]
  /\ UNCHANGED <<status, owner, stale>>

Next ==
  \/ \E w \in Workers, s \in Slots : Claim(w, s)
  \/ \E s \in Slots : Expire(s)
  \/ \E w \in Workers, s \in Slots : Reclaim(w, s)
  \/ \E w \in Workers, s \in Slots : Complete(w, s)
  \/ \E w \in Workers, s \in Slots : Fail(w, s)
  \/ \E s \in Slots, d \in Decisions : Review(s, d)
  \/ (Terminated /\ UNCHANGED vars)

BugNext == Next \/ (\E s \in Slots : PublishBug(s))

Spec == Init /\ [][Next]_vars
BugSpec == Init /\ [][BugNext]_vars

TypeOK ==
  /\ status \in [Slots -> Statuses]
  /\ owner \in [Slots -> (Workers \cup {NoOwner})]
  /\ stale \in [Slots -> BOOLEAN]
  /\ public \in [Slots -> BOOLEAN]

SlotLimit == Cardinality({s \in Slots : status[s] # "empty"}) <= 3
OwnerValid == \A s \in Slots : status[s] = "generating" => owner[s] \in Workers
NoPublicPost == \A s \in Slots : public[s] = FALSE
ReviewReached == \E s \in Slots : status[s] \in {"review", "approved", "rejected"}
NoReviewReached == ~ReviewReached

=============================================================================
