--------------------- MODULE ServiceControlProperties ---------------------
(* Frozen protocol properties sourced from the remote-service-control spec. *)

RequestStartAllowed(ready, before, after) ==
    (before = "idle" /\ after = "running") => ready

RequestFinishAllowed(ready, before, after) ==
    (before = "running" /\ after = "accepted") => ready

CronStartAllowed(ready, before, after) ==
    (before = "idle" /\ after = "loading") => ready

ProviderStartAllowed(ready, before, after) ==
    (before = "loading" /\ after = "provider") => ready

ProviderPersistStartAllowed(ready, before, after) ==
    (before = "provider" /\ after = "persisting") => ready

BlockedStatusWriteAllowed(ready, before, after) ==
    (before \in {"loading", "provider"} /\ after = "blocking") => ~ready

ControlWriteAuthorized(enabledBefore, enabledAfter, admin, available) ==
    (enabledBefore # enabledAfter) => (admin /\ available)

=============================================================================
