---------------------------- MODULE SessionContentBoundary ----------------------------
EXTENDS Integers

CONSTANT FixEnabled
ASSUME FixEnabled \in BOOLEAN

None == "none"
SessionIds == {"A", "B"}
RequestStates == {"idle", "inflight", "ready", "discarded", "done"}

VARIABLES session, sessionGeneration, cacheGeneration, cache, cacheOwner,
          cacheAtGeneration, request, requestOwner, requestSessionGeneration,
          requestCacheGeneration, responseOwner, responseSessionGeneration,
          responseCacheGeneration
vars == <<session, sessionGeneration, cacheGeneration, cache, cacheOwner,
          cacheAtGeneration, request, requestOwner, requestSessionGeneration,
          requestCacheGeneration, responseOwner, responseSessionGeneration,
          responseCacheGeneration>>

TypeOK ==
    /\ session \in SessionIds \cup {None}
    /\ sessionGeneration \in 0..3
    /\ cacheGeneration \in 0..3
    /\ cache \in BOOLEAN
    /\ cacheOwner \in SessionIds \cup {None}
    /\ cacheAtGeneration \in -1..3
    /\ request \in RequestStates
    /\ requestOwner \in SessionIds \cup {None}
    /\ requestSessionGeneration \in -1..3
    /\ requestCacheGeneration \in -1..3
    /\ responseOwner \in SessionIds \cup {None}
    /\ responseSessionGeneration \in -1..3
    /\ responseCacheGeneration \in -1..3

Init ==
    /\ session = "A"
    /\ sessionGeneration = 0
    /\ cacheGeneration = 0
    /\ cache = FALSE
    /\ cacheOwner = None
    /\ cacheAtGeneration = -1
    /\ request = "idle"
    /\ requestOwner = None
    /\ requestSessionGeneration = -1
    /\ requestCacheGeneration = -1
    /\ responseOwner = None
    /\ responseSessionGeneration = -1
    /\ responseCacheGeneration = -1

\* src: lib/services/remote_content_api.dart:46-48, request start snapshots auth generation.
StartRead ==
    /\ session \in SessionIds
    /\ request = "idle"
    /\ request' = "inflight"
    /\ requestOwner' = session
    /\ requestSessionGeneration' = sessionGeneration
    /\ requestCacheGeneration' = cacheGeneration
    /\ UNCHANGED <<session, sessionGeneration, cacheGeneration, cache,
                   cacheOwner, cacheAtGeneration, responseOwner,
                   responseSessionGeneration, responseCacheGeneration>>

\* src: lib/services/remote_content_api.dart:49-60, response after await is rejected after session change.
ReceiveRead ==
    /\ request = "inflight"
    /\ IF FixEnabled /\ (requestSessionGeneration # sessionGeneration \/ requestOwner # session)
          THEN request' = "discarded"
          ELSE request' = "ready"
    /\ IF FixEnabled /\ (requestSessionGeneration # sessionGeneration \/ requestOwner # session)
          THEN UNCHANGED <<responseOwner, responseSessionGeneration,
                           responseCacheGeneration>>
          ELSE /\ responseOwner' = requestOwner
               /\ responseSessionGeneration' = requestSessionGeneration
               /\ responseCacheGeneration' = requestCacheGeneration
    /\ UNCHANGED <<session, sessionGeneration, cacheGeneration, cache,
                   cacheOwner, cacheAtGeneration, requestOwner,
                   requestSessionGeneration, requestCacheGeneration>>

\* src: lib/services/auth_service.dart:288-298, logout invalidates session and loaded caches.
Logout ==
    /\ session \in SessionIds
    /\ sessionGeneration < 3
    /\ cacheGeneration < 3
    /\ session' = None
    /\ sessionGeneration' = sessionGeneration + 1
    /\ cacheGeneration' = cacheGeneration + 1
    /\ cache' = FALSE
    /\ cacheOwner' = None
    /\ cacheAtGeneration' = -1
    /\ UNCHANGED <<request, requestOwner, requestSessionGeneration,
                   requestCacheGeneration, responseOwner,
                   responseSessionGeneration, responseCacheGeneration>>

\* src: lib/services/auth_service.dart:241-248, a new account begins with empty content caches.
LoginB ==
    /\ session = None
    /\ sessionGeneration < 3
    /\ cacheGeneration < 3
    /\ session' = "B"
    /\ sessionGeneration' = sessionGeneration + 1
    /\ cacheGeneration' = cacheGeneration + 1
    /\ cache' = FALSE
    /\ cacheOwner' = None
    /\ cacheAtGeneration' = -1
    /\ UNCHANGED <<request, requestOwner, requestSessionGeneration,
                   requestCacheGeneration, responseOwner,
                   responseSessionGeneration, responseCacheGeneration>>

\* src: lib/services/study_data.dart:1005-1040, changing the selected track invalidates pending cache fills.
ChangeTrack ==
    /\ cacheGeneration < 3
    /\ cacheGeneration' = cacheGeneration + 1
    /\ cache' = FALSE
    /\ cacheOwner' = None
    /\ cacheAtGeneration' = -1
    /\ UNCHANGED <<session, sessionGeneration, request, requestOwner,
                   requestSessionGeneration, requestCacheGeneration,
                   responseOwner, responseSessionGeneration,
                   responseCacheGeneration>>

\* src: lib/services/study_data.dart:1552-1563, async loader stores only for the generation it started in.
CacheRead ==
    /\ request = "ready"
    /\ IF FixEnabled /\ (responseSessionGeneration # sessionGeneration \/
                         responseCacheGeneration # cacheGeneration \/
                         responseOwner # session \/ session = None)
          THEN /\ request' = "discarded"
               /\ UNCHANGED <<cache, cacheOwner, cacheAtGeneration>>
          ELSE /\ request' = "done"
               /\ cache' = TRUE
               /\ cacheOwner' = responseOwner
               /\ cacheAtGeneration' = responseCacheGeneration
    /\ UNCHANGED <<session, sessionGeneration, cacheGeneration, requestOwner,
                   requestSessionGeneration, requestCacheGeneration,
                   responseOwner, responseSessionGeneration,
                   responseCacheGeneration>>

Next == StartRead \/ ReceiveRead \/ Logout \/ LoginB \/ ChangeTrack \/ CacheRead
Spec == Init /\ [][Next]_vars

NoCrossSessionCache ==
    cache => /\ session \in SessionIds
             /\ cacheOwner = session
             /\ cacheAtGeneration = cacheGeneration

CacheNeverPopulated == cache = FALSE

=============================================================================
