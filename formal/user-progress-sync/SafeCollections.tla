------------------------- MODULE SafeCollections --------------------------
EXTENDS Naturals

CONSTANTS C1, C2, FixEnabled
Clients == {C1, C2}
Max(a, b) == IF a >= b THEN a ELSE b

VARIABLES localSeen, serverSeen, highWater, localRegistration,
          localRegistrationAt, serverRegistration, serverRegistrationAt,
          registrationDeletedAt
vars == <<localSeen, serverSeen, highWater, localRegistration,
          localRegistrationAt, serverRegistration, serverRegistrationAt,
          registrationDeletedAt>>

TypeOK ==
  /\ localSeen \in [Clients -> 0..2]
  /\ serverSeen \in 0..2
  /\ highWater \in 0..2
  /\ localRegistration \in [Clients -> BOOLEAN]
  /\ localRegistrationAt \in [Clients -> 0..2]
  /\ serverRegistration \in BOOLEAN
  /\ serverRegistrationAt \in 0..2
  /\ registrationDeletedAt \in 0..2

Init ==
  /\ localSeen = [c \in Clients |-> 0]
  /\ serverSeen = 0
  /\ highWater = 0
  /\ localRegistration = [c \in Clients |-> TRUE]
  /\ localRegistrationAt = [c \in Clients |-> 0]
  /\ serverRegistration = TRUE
  /\ serverRegistrationAt = 0
  /\ registrationDeletedAt = 0

\* src: lib/services/slide_progress.dart:49-77; one client increases seen pages.
Learn(c) ==
  /\ c \in Clients
  /\ localSeen[c] < 2
  /\ localSeen' = [localSeen EXCEPT ![c] = @ + 1]
  /\ UNCHANGED <<serverSeen, highWater, localRegistration,
       localRegistrationAt, serverRegistration, serverRegistrationAt,
       registrationDeletedAt>>

\* src: lib/services/progress_snapshot_store.dart:553-587;
\* backend/cloudflare/src/progress.js:277-299; slide progress merges by max.
MergeProgress(c) ==
  /\ c \in Clients
  /\ LET nextSeen == IF FixEnabled THEN Max(serverSeen, localSeen[c]) ELSE localSeen[c]
     IN
       /\ serverSeen' = nextSeen
       /\ highWater' = Max(highWater, nextSeen)
  /\ UNCHANGED <<localSeen, localRegistration, localRegistrationAt,
       serverRegistration, serverRegistrationAt, registrationDeletedAt>>

\* src: lib/services/exam_registration.dart:188-200; local delete writes a versioned tombstone.
DeleteRegistration ==
  /\ registrationDeletedAt = 0
  /\ localRegistration' = [localRegistration EXCEPT ![C1] = FALSE]
  /\ serverRegistration' = FALSE
  /\ registrationDeletedAt' = 1
  /\ UNCHANGED <<localSeen, serverSeen, highWater, localRegistrationAt,
       serverRegistrationAt>>

\* src: lib/services/exam_registration.dart:168-186; a deliberate re-add is newer than deletion.
RestoreRegistration ==
  /\ registrationDeletedAt > 0
  /\ ~localRegistration[C1]
  /\ localRegistration' = [localRegistration EXCEPT ![C1] = TRUE]
  /\ localRegistrationAt' = [localRegistrationAt EXCEPT ![C1] = 2]
  /\ UNCHANGED <<localSeen, serverSeen, highWater, serverRegistration,
       serverRegistrationAt, registrationDeletedAt>>

\* src: backend/cloudflare/src/progress.js:69-100,378-401; stale or restored device push.
PushRegistration(c) ==
  /\ c \in Clients
  /\ localRegistration[c]
  /\ IF ~FixEnabled
       THEN
         /\ serverRegistration' = TRUE
         /\ serverRegistrationAt' = localRegistrationAt[c]
         /\ registrationDeletedAt' = registrationDeletedAt
       ELSE IF registrationDeletedAt > 0
         THEN IF localRegistrationAt[c] > registrationDeletedAt
           THEN
             /\ serverRegistration' = TRUE
             /\ serverRegistrationAt' = localRegistrationAt[c]
             /\ registrationDeletedAt' = 0
           ELSE
             /\ serverRegistration' = FALSE
             /\ serverRegistrationAt' = serverRegistrationAt
             /\ registrationDeletedAt' = registrationDeletedAt
         ELSE IF localRegistrationAt[c] >= serverRegistrationAt
           THEN
             /\ serverRegistration' = TRUE
             /\ serverRegistrationAt' = localRegistrationAt[c]
             /\ registrationDeletedAt' = 0
           ELSE
             /\ serverRegistration' = serverRegistration
             /\ serverRegistrationAt' = serverRegistrationAt
             /\ registrationDeletedAt' = 0
  /\ UNCHANGED <<localSeen, serverSeen, highWater, localRegistration,
       localRegistrationAt>>

Next ==
  \/ \E c \in Clients : Learn(c)
  \/ \E c \in Clients : MergeProgress(c)
  \/ DeleteRegistration
  \/ RestoreRegistration
  \/ \E c \in Clients : PushRegistration(c)

Spec == Init /\ [][Next]_vars
SlideProgressNeverRegresses == serverSeen = highWater
RegistrationTombstoneWins == registrationDeletedAt > 0 =>
  (~serverRegistration \/ serverRegistrationAt > registrationDeletedAt)
SafeProgressRange == serverSeen \in 0..2
NoProgressReached == serverSeen = 0 /\ registrationDeletedAt = 0
NoRegistrationRestoreReached == serverRegistrationAt # 2

=============================================================================
