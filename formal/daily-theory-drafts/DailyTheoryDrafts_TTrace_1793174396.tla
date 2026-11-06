---- MODULE DailyTheoryDrafts_TTrace_1793174396 ----
EXTENDS DailyTheoryDrafts, Sequences, TLCExt, Toolbox, Naturals, TLC, DailyTheoryDrafts_TEConstants

_expression ==
    LET DailyTheoryDrafts_TEExpression == INSTANCE DailyTheoryDrafts_TEExpression
    IN DailyTheoryDrafts_TEExpression!expression
----

_trace ==
    LET DailyTheoryDrafts_TETrace == INSTANCE DailyTheoryDrafts_TETrace
    IN DailyTheoryDrafts_TETrace!trace
----

_inv ==
    ~(
        TLCGet("level") = Len(_TETrace)
        /\
        owner = ((slot0 :> workerA @@ slot1 :> "none" @@ slot2 :> "none"))
        /\
        stale = ((slot0 :> FALSE @@ slot1 :> FALSE @@ slot2 :> FALSE))
        /\
        public = ((slot0 :> TRUE @@ slot1 :> FALSE @@ slot2 :> FALSE))
        /\
        status = ((slot0 :> "generating" @@ slot1 :> "empty" @@ slot2 :> "empty"))
    )
----

_init ==
    /\ owner = _TETrace[1].owner
    /\ status = _TETrace[1].status
    /\ stale = _TETrace[1].stale
    /\ public = _TETrace[1].public
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ owner  = _TETrace[i].owner
        /\ owner' = _TETrace[j].owner
        /\ status  = _TETrace[i].status
        /\ status' = _TETrace[j].status
        /\ stale  = _TETrace[i].stale
        /\ stale' = _TETrace[j].stale
        /\ public  = _TETrace[i].public
        /\ public' = _TETrace[j].public

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("DailyTheoryDrafts_TTrace_1793174396.json", _TETrace)

=============================================================================

 Note that you can extract this module `DailyTheoryDrafts_TEExpression`
  to a dedicated file to reuse `expression` (the module in the
  dedicated `DailyTheoryDrafts_TEExpression.tla` file takes precedence
  over the module `DailyTheoryDrafts_TEExpression` below).

---- MODULE DailyTheoryDrafts_TEExpression ----
EXTENDS DailyTheoryDrafts, Sequences, TLCExt, Toolbox, Naturals, TLC, DailyTheoryDrafts_TEConstants

expression ==
    [
        \* To hide variables of the `DailyTheoryDrafts` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        owner |-> owner
        ,status |-> status
        ,stale |-> stale
        ,public |-> public

        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_ownerUnchanged |-> owner = owner'

        \* Format the `owner` variable as Json value.
        \* ,_ownerJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(owner)

        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_ownerModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].owner # _TETrace[s-1].owner
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE DailyTheoryDrafts_TETrace ----
\*EXTENDS DailyTheoryDrafts, IOUtils, TLC, DailyTheoryDrafts_TEConstants
\*
\*trace == IODeserialize("DailyTheoryDrafts_TTrace_1793174396.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE DailyTheoryDrafts_TETrace ----
EXTENDS DailyTheoryDrafts, TLC, DailyTheoryDrafts_TEConstants

trace ==
    <<
    ([owner |-> (slot0 :> "none" @@ slot1 :> "none" @@ slot2 :> "none"),stale |-> (slot0 :> FALSE @@ slot1 :> FALSE @@ slot2 :> FALSE),public |-> (slot0 :> FALSE @@ slot1 :> FALSE @@ slot2 :> FALSE),status |-> (slot0 :> "empty" @@ slot1 :> "empty" @@ slot2 :> "empty")]),
    ([owner |-> (slot0 :> workerA @@ slot1 :> "none" @@ slot2 :> "none"),stale |-> (slot0 :> FALSE @@ slot1 :> FALSE @@ slot2 :> FALSE),public |-> (slot0 :> FALSE @@ slot1 :> FALSE @@ slot2 :> FALSE),status |-> (slot0 :> "generating" @@ slot1 :> "empty" @@ slot2 :> "empty")]),
    ([owner |-> (slot0 :> workerA @@ slot1 :> "none" @@ slot2 :> "none"),stale |-> (slot0 :> FALSE @@ slot1 :> FALSE @@ slot2 :> FALSE),public |-> (slot0 :> TRUE @@ slot1 :> FALSE @@ slot2 :> FALSE),status |-> (slot0 :> "generating" @@ slot1 :> "empty" @@ slot2 :> "empty")])
    >>
----


=============================================================================

---- MODULE DailyTheoryDrafts_TEConstants ----
EXTENDS DailyTheoryDrafts

CONSTANTS workerA, workerB, slot0, slot1, slot2

=============================================================================

---- CONFIG DailyTheoryDrafts_TTrace_1793174396 ----
CONSTANTS
    Workers = { workerA , workerB }
    Slots = { slot0 , slot1 , slot2 }
    slot0 = slot0
    workerB = workerB
    workerA = workerA
    slot1 = slot1
    slot2 = slot2

INVARIANT
    _inv

CHECK_DEADLOCK
    \* CHECK_DEADLOCK off because of PROPERTY or INVARIANT above.
    FALSE

INIT
    _init

NEXT
    _next

CONSTANT
    _TETrace <- _trace

ALIAS
    _expression
=============================================================================
\* Generated on Wed Oct 28 16:59:56 KST 2026