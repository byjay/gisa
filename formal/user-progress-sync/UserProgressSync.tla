-------------------------- MODULE UserProgressSync --------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS A, B, C1, C2, R1, R2, RA, RB, NoRequest, NoPush, FixEnabled

Users == {A, B}
Clients == {C1, C2}
Records == {R1, R2, RA, RB}
RecordOwner == [r \in Records |-> IF r = RB THEN B ELSE A]
ClientOwner == [c \in Clients |-> A]
ClientSnapshot == [c \in Clients |-> IF c = C1 THEN {R1} ELSE {RA, R2}]

VARIABLES active, generation, boxOwner, boxReady, openRequests, local,
          serverRecords, serverTombstones, serverVersion, readRequest,
          pushState, push, committed
vars == <<active, generation, boxOwner, boxReady, openRequests, local,
          serverRecords, serverTombstones, serverVersion, readRequest,
          pushState, push, committed>>

ActiveType == active \in Users
GenerationType == generation \in 0..3
BoxOwnerType == boxOwner \in Users
BoxReadyType == boxReady \in BOOLEAN
OpenRequestsType == openRequests \subseteq [owner: Users, generation: 0..3]
LocalType == local \in [Users -> SUBSET Records]
ServerRecordsType == serverRecords \in [Users -> SUBSET Records]
TombstoneType == serverTombstones \in [Users -> SUBSET Records]
VersionType == serverVersion \in [Users -> Nat]
PushStateType == pushState \in [Clients -> {"idle", "pending", "committed"}]
CommitType == committed \subseteq Clients

BaseType ==
  /\ ActiveType
  /\ GenerationType
  /\ BoxOwnerType
  /\ BoxReadyType
  /\ OpenRequestsType
  /\ LocalType
  /\ ServerRecordsType
  /\ TombstoneType
  /\ VersionType
  /\ PushStateType
  /\ CommitType

ReadRequestType ==
  readRequest = NoRequest \/ (
    /\ DOMAIN readRequest = {"owner", "generation", "records", "deleted"}
    /\ readRequest.owner \in Users
    /\ readRequest.generation \in 0..3
    /\ readRequest.records \subseteq Records
    /\ readRequest.deleted \subseteq Records)

PushType == \A c \in Clients :
  push[c] = NoPush \/ (
    /\ DOMAIN push[c] = {"owner", "version", "records", "deleted"}
    /\ push[c].owner \in Users
    /\ push[c].version \in Nat
    /\ push[c].records \subseteq Records
    /\ push[c].deleted \subseteq Records)

TypeOK ==
  /\ BaseType
  /\ ReadRequestType
  /\ PushType

Init ==
  /\ active = A
  /\ generation = 0
  /\ boxOwner = A
  /\ boxReady = TRUE
  /\ openRequests = {}
  /\ local = [u \in Users |-> {}]
  /\ serverRecords = [u \in Users |-> IF u = A THEN {RA} ELSE {RB}]
  /\ serverTombstones = [u \in Users |-> {}]
  /\ serverVersion = [u \in Users |-> 0]
  /\ readRequest = NoRequest
  /\ pushState = [c \in Clients |-> "idle"]
  /\ push = [c \in Clients |-> NoPush]
  /\ committed = {}

\* src: lib/services/progress_sync_service.dart:95-106; captures owner/session generation.
StartRead ==
  /\ readRequest = NoRequest
  /\ boxReady
  /\ boxOwner = active
  /\ readRequest' = [owner |-> active, generation |-> generation,
       records |-> serverRecords[active] \ serverTombstones[active],
       deleted |-> serverTombstones[active]]
  /\ UNCHANGED <<active, generation, boxOwner, boxReady, openRequests, local,
       serverRecords, serverTombstones, serverVersion, pushState, push, committed>>

\* src: lib/providers/app_provider.dart:111-128; scoped account switch invalidates earlier work.
SwitchUser ==
  /\ generation < 3
  /\ LET nextOwner == IF active = A THEN B ELSE A IN
       /\ active' = nextOwner
       /\ generation' = generation + 1
       /\ boxReady' = FALSE
       /\ openRequests' = openRequests \cup
            {[owner |-> nextOwner, generation |-> generation + 1]}
  /\ UNCHANGED <<boxOwner, local, serverRecords, serverTombstones, serverVersion,
       readRequest, pushState, push, committed>>

\* src: lib/providers/app_provider.dart:138-160; stale account opens cannot replace current box references.
CompleteOpen(req) ==
  /\ req \in openRequests
  /\ IF FixEnabled
       THEN IF req.owner = active /\ req.generation = generation
              THEN /\ boxOwner' = req.owner
                   /\ boxReady' = TRUE
              ELSE /\ UNCHANGED boxOwner
                   /\ UNCHANGED boxReady
       ELSE /\ boxOwner' = req.owner
            /\ boxReady' = TRUE
  /\ openRequests' = openRequests \ {req}
  /\ UNCHANGED <<active, generation, local, serverRecords, serverTombstones,
       serverVersion, readRequest, pushState, push, committed>>

\* src: lib/services/progress_sync_service.dart:115-122; stale response is discarded.
DeliverRead ==
  /\ readRequest # NoRequest
  /\ IF FixEnabled
       THEN IF boxReady /\ boxOwner = active /\ readRequest.owner = active /\
                 readRequest.generation = generation
              THEN local' = [local EXCEPT ![active] =
                     ((@ \cup readRequest.records) \ readRequest.deleted)]
              ELSE UNCHANGED local
       ELSE local' = [local EXCEPT ![active] =
              ((@ \cup readRequest.records) \ readRequest.deleted)]
  /\ readRequest' = NoRequest
  /\ UNCHANGED <<active, generation, boxOwner, boxReady, openRequests,
       serverRecords, serverTombstones, serverVersion, pushState, push, committed>>

\* src: backend/cloudflare/src/index.js:269-281; verified JWT subject is the row owner.
BeginPush(c) ==
  /\ c \in Clients
  /\ pushState[c] = "idle"
  /\ push' = [push EXCEPT ![c] =
       [owner |-> ClientOwner[c], version |-> serverVersion[ClientOwner[c]],
        records |-> ClientSnapshot[c], deleted |-> {}]]
  /\ pushState' = [pushState EXCEPT ![c] = "pending"]
  /\ UNCHANGED <<active, generation, boxOwner, boxReady, openRequests, local,
       serverRecords, serverTombstones, serverVersion, readRequest, committed>>

\* src: backend/cloudflare/src/progress.js:41-61; D1 compare-and-swap commit.
CommitPush(c) ==
  /\ c \in Clients
  /\ pushState[c] = "pending"
  /\ LET u == push[c].owner IN
       /\ push[c].version = serverVersion[u]
       /\ serverRecords' = [serverRecords EXCEPT ![u] =
            ((@ \cup push[c].records) \ (serverTombstones[u] \cup push[c].deleted))]
       /\ serverTombstones' = [serverTombstones EXCEPT ![u] =
            (@ \cup push[c].deleted)]
       /\ serverVersion' = [serverVersion EXCEPT ![u] = @ + 1]
  /\ pushState' = [pushState EXCEPT ![c] = "committed"]
  /\ committed' = committed \cup {c}
  /\ UNCHANGED <<active, generation, boxOwner, boxReady, openRequests, local,
       readRequest, push>>

\* src: backend/cloudflare/src/progress.js:60-64; a CAS miss re-reads and retries.
RetryPush(c) ==
  /\ c \in Clients
  /\ pushState[c] = "pending"
  /\ push[c].version # serverVersion[push[c].owner]
  /\ push' = [push EXCEPT ![c].version = serverVersion[push[c].owner]]
  /\ UNCHANGED <<active, generation, boxOwner, boxReady, openRequests, local,
       serverRecords, serverTombstones, serverVersion, readRequest, pushState, committed>>

\* src: lib/services/progress_snapshot_store.dart:48-60; deletion wins over stale rows.
DeleteServerRecord ==
  /\ RA \in serverRecords[A]
  /\ RA \notin serverTombstones[A]
  /\ serverRecords' = [serverRecords EXCEPT ![A] = @ \ {RA}]
  /\ serverTombstones' = [serverTombstones EXCEPT ![A] = @ \cup {RA}]
  /\ serverVersion' = [serverVersion EXCEPT ![A] = @ + 1]
  /\ UNCHANGED <<active, generation, boxOwner, boxReady, openRequests, local,
       readRequest, pushState, push, committed>>

Next ==
  \/ StartRead
  \/ SwitchUser
  \/ \E req \in openRequests : CompleteOpen(req)
  \/ DeliverRead
  \/ \E c \in Clients : BeginPush(c)
  \/ \E c \in Clients : CommitPush(c)
  \/ \E c \in Clients : RetryPush(c)
  \/ DeleteServerRecord

Spec == Init /\ [][Next]_vars

OwnerSafeLocal == \A u \in Users : \A r \in local[u] : RecordOwner[r] = u
BoxOwnerMatchesWhenReady == boxReady => boxOwner = active
OwnerSafeServer == \A u \in Users : \A r \in serverRecords[u] : RecordOwner[r] = u
TombstonesWin == \A u \in Users : serverRecords[u] \cap serverTombstones[u] = {}
CommittedWritesRetained ==
  \A c \in committed :
    (ClientSnapshot[c] \ serverTombstones[ClientOwner[c]])
      \subseteq serverRecords[ClientOwner[c]]
NoLocalDataReachable == \A u \in Users : local[u] = {}

=============================================================================
