------------------------- MODULE ServiceControl -------------------------
EXTENDS Naturals, ServiceControlProperties

CONSTANTS UseServiceGate, MaxRevision

VARIABLES serviceEnabled, controlAvailable, revision, adminAuthenticated,
          requestState, scheduleState
vars == <<serviceEnabled, controlAvailable, revision, adminAuthenticated,
          requestState, scheduleState>>

RequestStates == {"idle", "running", "accepted", "blocked"}
ScheduleStates == {"idle", "loading", "provider", "blocking", "persisting", "persisted", "skipped", "discarded"}

Init ==
    /\ serviceEnabled = TRUE
    /\ controlAvailable = TRUE
    /\ revision = 0
    /\ adminAuthenticated = FALSE
    /\ requestState = "idle"
    /\ scheduleState = "idle"

TypeOK ==
    /\ UseServiceGate \in BOOLEAN
    /\ MaxRevision \in Nat \ {0}
    /\ serviceEnabled \in BOOLEAN
    /\ controlAvailable \in BOOLEAN
    /\ revision \in 0..MaxRevision
    /\ adminAuthenticated \in BOOLEAN
    /\ requestState \in RequestStates
    /\ scheduleState \in ScheduleStates

\* src: backend/cloudflare/src/index.js:108-135 (`requireAdmin`, service-control routes)
AuthenticateAdmin ==
    /\ adminAuthenticated = FALSE
    /\ adminAuthenticated' = TRUE
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, requestState, scheduleState>>

\* src: backend/cloudflare/src/index.js:108-135 (`requireAdmin`, service-control routes)
LogoutAdmin ==
    /\ adminAuthenticated = TRUE
    /\ adminAuthenticated' = FALSE
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, requestState, scheduleState>>

\* src: backend/cloudflare/src/index.js:108-135 (`/v1/admin/service-control` PUT)
ToggleService(nextEnabled) ==
    /\ adminAuthenticated
    /\ controlAvailable
    /\ revision < MaxRevision
    /\ nextEnabled \in BOOLEAN
    /\ nextEnabled # serviceEnabled
    /\ serviceEnabled' = nextEnabled
    /\ revision' = revision + 1
    /\ UNCHANGED <<controlAvailable, adminAuthenticated, requestState, scheduleState>>

\* src: backend/cloudflare/src/index.js:36-43 (`getServiceState` failure)
ControlUnavailable ==
    /\ controlAvailable
    /\ controlAvailable' = FALSE
    /\ UNCHANGED <<serviceEnabled, revision, adminAuthenticated, requestState, scheduleState>>

\* src: backend/cloudflare/src/index.js:36-43 (`getServiceState` recovery)
ControlRecover ==
    /\ controlAvailable = FALSE
    /\ controlAvailable' = TRUE
    /\ UNCHANGED <<serviceEnabled, revision, adminAuthenticated, requestState, scheduleState>>

\* src: backend/cloudflare/src/index.js:85-93 (pre-handler service gate)
StartProtected ==
    /\ requestState = "idle"
    /\ (~UseServiceGate \/ (serviceEnabled /\ controlAvailable))
    /\ requestState' = "running"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, scheduleState>>

\* src: backend/cloudflare/src/index.js:303-309 (post-handler service gate)
FinishProtected ==
    /\ requestState = "running"
    /\ requestState' =
        IF UseServiceGate /\ ~(serviceEnabled /\ controlAvailable)
        THEN "blocked"
        ELSE "accepted"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, scheduleState>>

ResetProtected ==
    /\ requestState \in {"accepted", "blocked"}
    /\ requestState' = "idle"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, scheduleState>>

\* src: backend/cloudflare/src/index.js:311-323 (`scheduled` event gate)
StartScheduled ==
    /\ scheduleState = "idle"
    /\ (~UseServiceGate \/ (serviceEnabled /\ controlAvailable))
    /\ scheduleState' = "loading"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

SkipScheduled ==
    /\ scheduleState = "idle"
    /\ UseServiceGate
    /\ ~(serviceEnabled /\ controlAvailable)
    /\ scheduleState' = "skipped"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

\* src: backend/cloudflare/src/blog-drafts.js:183-192 (pre-provider recheck)
StartProvider ==
    /\ scheduleState = "loading"
    /\ (~UseServiceGate \/ (serviceEnabled /\ controlAvailable))
    /\ scheduleState' = "provider"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

\* src: backend/cloudflare/src/blog-drafts.js:188-190 (blocked claim status after control recheck)
SkipProvider ==
    /\ scheduleState = "loading"
    /\ UseServiceGate
    /\ ~(serviceEnabled /\ controlAvailable)
    /\ scheduleState' = "blocking"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

\* src: backend/cloudflare/src/blog-drafts.js:193-197 (post-provider recheck before starting D1 write)
StartPersist ==
    /\ scheduleState = "provider"
    /\ (~UseServiceGate \/ (serviceEnabled /\ controlAvailable))
    /\ scheduleState' = "persisting"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

\* src: backend/cloudflare/src/blog-drafts.js:193-195 (blocked claim status after post-provider recheck)
SkipPersist ==
    /\ scheduleState = "provider"
    /\ UseServiceGate
    /\ ~(serviceEnabled /\ controlAvailable)
    /\ scheduleState' = "blocking"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

\* This D1 update records only failed/service_control_blocked status; it contains no generated content.
\* src: backend/cloudflare/src/blog-drafts.js:166-171 (`failClaim`)
FinishBlockedStatus ==
    /\ scheduleState = "blocking"
    /\ scheduleState' = "skipped"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

\* src: backend/cloudflare/src/blog-drafts.js:173-180 (`finishClaim`, in-flight D1 write)
\* The D1 write already started at finishClaim(); shutdown cannot cancel this in-flight write.
FinishPersist ==
    /\ scheduleState = "persisting"
    /\ scheduleState' = "persisted"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

ResetScheduled ==
    /\ scheduleState \in {"persisted", "skipped", "discarded"}
    /\ scheduleState' = "idle"
    /\ UNCHANGED <<serviceEnabled, controlAvailable, revision, adminAuthenticated, requestState>>

Next ==
    \/ AuthenticateAdmin
    \/ LogoutAdmin
    \/ ToggleService(TRUE)
    \/ ToggleService(FALSE)
    \/ ControlUnavailable
    \/ ControlRecover
    \/ StartProtected
    \/ FinishProtected
    \/ ResetProtected
    \/ StartScheduled
    \/ SkipScheduled
    \/ StartProvider
    \/ SkipProvider
    \/ StartPersist
    \/ SkipPersist
    \/ FinishBlockedStatus
    \/ FinishPersist
    \/ ResetScheduled

Spec == Init /\ [][Next]_vars

ProtectedStartGuard ==
    [][RequestStartAllowed(serviceEnabled /\ controlAvailable,
        requestState, requestState')]_vars
ProtectedFinishGuard ==
    [][RequestFinishAllowed(serviceEnabled' /\ controlAvailable',
        requestState, requestState')]_vars
ScheduledStartGuard ==
    [][CronStartAllowed(serviceEnabled /\ controlAvailable,
        scheduleState, scheduleState')]_vars
ProviderStartGuard ==
    [][ProviderStartAllowed(serviceEnabled /\ controlAvailable,
        scheduleState, scheduleState')]_vars
ProviderPersistStartGuard ==
    [][ProviderPersistStartAllowed(serviceEnabled /\ controlAvailable,
        scheduleState, scheduleState')]_vars
BlockedStatusWriteGuard ==
    [][BlockedStatusWriteAllowed(serviceEnabled /\ controlAvailable,
        scheduleState, scheduleState')]_vars
AdminToggleGuard ==
    [][ControlWriteAuthorized(serviceEnabled, serviceEnabled',
        adminAuthenticated, controlAvailable)]_vars

\* Sanity check: a healthy request must be able to complete in the model.
SanityNeverAccepted == requestState # "accepted"
NoBlockedStatusReached == scheduleState # "blocking"

\* Intentional limitation check: an already-started D1 write may finish after shutdown.
NoReviewFinalizeAfterShutdown == ~(scheduleState = "persisted" /\ ~(serviceEnabled /\ controlAvailable))

=============================================================================
