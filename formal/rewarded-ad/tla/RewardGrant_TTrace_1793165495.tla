---- MODULE RewardGrant_TTrace_1793165495 ----
EXTENDS Sequences, TLCExt, Toolbox, RewardGrant, Naturals, TLC, RewardGrant_TEConstants

_expression ==
    LET RewardGrant_TEExpression == INSTANCE RewardGrant_TEExpression
    IN RewardGrant_TEExpression!expression
----

_trace ==
    LET RewardGrant_TETrace == INSTANCE RewardGrant_TETrace
    IN RewardGrant_TETrace!trace
----

_inv ==
    ~(
        TLCGet("level") = Len(_TETrace)
        /\
        processed = ({txA})
        /\
        pc = ((a1 :> "done" @@ a2 :> "pending" @@ b1 :> "check" @@ b2 :> "pending" @@ fake1 :> "pending"))
        /\
        credits = (1)
        /\
        rejected = ({})
        /\
        granted = ({txA})
    )
----

_init ==
    /\ credits = _TETrace[1].credits
    /\ processed = _TETrace[1].processed
    /\ rejected = _TETrace[1].rejected
    /\ granted = _TETrace[1].granted
    /\ pc = _TETrace[1].pc
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ credits  = _TETrace[i].credits
        /\ credits' = _TETrace[j].credits
        /\ processed  = _TETrace[i].processed
        /\ processed' = _TETrace[j].processed
        /\ rejected  = _TETrace[i].rejected
        /\ rejected' = _TETrace[j].rejected
        /\ granted  = _TETrace[i].granted
        /\ granted' = _TETrace[j].granted
        /\ pc  = _TETrace[i].pc
        /\ pc' = _TETrace[j].pc

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("RewardGrant_TTrace_1793165495.json", _TETrace)

=============================================================================

 Note that you can extract this module `RewardGrant_TEExpression`
  to a dedicated file to reuse `expression` (the module in the
  dedicated `RewardGrant_TEExpression.tla` file takes precedence
  over the module `RewardGrant_TEExpression` below).

---- MODULE RewardGrant_TEExpression ----
EXTENDS Sequences, TLCExt, Toolbox, RewardGrant, Naturals, TLC, RewardGrant_TEConstants

expression ==
    [
        \* To hide variables of the `RewardGrant` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        credits |-> credits
        ,processed |-> processed
        ,rejected |-> rejected
        ,granted |-> granted
        ,pc |-> pc

        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_creditsUnchanged |-> credits = credits'

        \* Format the `credits` variable as Json value.
        \* ,_creditsJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(credits)

        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_creditsModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].credits # _TETrace[s-1].credits
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE RewardGrant_TETrace ----
\*EXTENDS IOUtils, RewardGrant, TLC, RewardGrant_TEConstants
\*
\*trace == IODeserialize("RewardGrant_TTrace_1793165495.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE RewardGrant_TETrace ----
EXTENDS RewardGrant, TLC, RewardGrant_TEConstants

trace ==
    <<
    ([processed |-> {},pc |-> (a1 :> "pending" @@ a2 :> "pending" @@ b1 :> "pending" @@ b2 :> "pending" @@ fake1 :> "pending"),credits |-> 0,rejected |-> {},granted |-> {}]),
    ([processed |-> {},pc |-> (a1 :> "pending" @@ a2 :> "pending" @@ b1 :> "check" @@ b2 :> "pending" @@ fake1 :> "pending"),credits |-> 0,rejected |-> {},granted |-> {}]),
    ([processed |-> {},pc |-> (a1 :> "check" @@ a2 :> "pending" @@ b1 :> "check" @@ b2 :> "pending" @@ fake1 :> "pending"),credits |-> 0,rejected |-> {},granted |-> {}]),
    ([processed |-> {txA},pc |-> (a1 :> "done" @@ a2 :> "pending" @@ b1 :> "check" @@ b2 :> "pending" @@ fake1 :> "pending"),credits |-> 1,rejected |-> {},granted |-> {txA}])
    >>
----


=============================================================================

---- MODULE RewardGrant_TEConstants ----
EXTENDS RewardGrant

CONSTANTS a1, a2, b1, b2, fake1, txA, txB, txC

=============================================================================

---- CONFIG RewardGrant_TTrace_1793165495 ----
CONSTANTS
    GroupA = { a1 , a2 }
    GroupB = { b1 , b2 }
    GroupC = { fake1 }
    TxA = txA
    TxB = txB
    TxC = txC
    Verified = { a1 , a2 , b1 , b2 }
    DailyLimit = 1
    AtomicGrant = TRUE
    txC = txC
    fake1 = fake1
    txB = txB
    a2 = a2
    b2 = b2
    a1 = a1
    b1 = b1
    txA = txA

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
\* Generated on Wed Oct 28 14:31:36 KST 2026