---- MODULE SessionContentBoundary_TTrace_1793166795 ----
EXTENDS Sequences, SessionContentBoundary, TLCExt, Toolbox, Naturals, TLC

_expression ==
    LET SessionContentBoundary_TEExpression == INSTANCE SessionContentBoundary_TEExpression
    IN SessionContentBoundary_TEExpression!expression
----

_trace ==
    LET SessionContentBoundary_TETrace == INSTANCE SessionContentBoundary_TETrace
    IN SessionContentBoundary_TETrace!trace
----

_inv ==
    ~(
        TLCGet("level") = Len(_TETrace)
        /\
        responseGeneration = (0)
        /\
        generation = (1)
        /\
        request = ("done")
        /\
        cache = (TRUE)
        /\
        responseOwner = ("A")
        /\
        cacheGeneration = (0)
        /\
        requestGeneration = (0)
        /\
        session = ("none")
        /\
        cacheOwner = ("A")
        /\
        requestOwner = ("A")
    )
----

_init ==
    /\ cacheGeneration = _TETrace[1].cacheGeneration
    /\ cacheOwner = _TETrace[1].cacheOwner
    /\ responseGeneration = _TETrace[1].responseGeneration
    /\ request = _TETrace[1].request
    /\ session = _TETrace[1].session
    /\ generation = _TETrace[1].generation
    /\ cache = _TETrace[1].cache
    /\ responseOwner = _TETrace[1].responseOwner
    /\ requestGeneration = _TETrace[1].requestGeneration
    /\ requestOwner = _TETrace[1].requestOwner
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ cacheGeneration  = _TETrace[i].cacheGeneration
        /\ cacheGeneration' = _TETrace[j].cacheGeneration
        /\ cacheOwner  = _TETrace[i].cacheOwner
        /\ cacheOwner' = _TETrace[j].cacheOwner
        /\ responseGeneration  = _TETrace[i].responseGeneration
        /\ responseGeneration' = _TETrace[j].responseGeneration
        /\ request  = _TETrace[i].request
        /\ request' = _TETrace[j].request
        /\ session  = _TETrace[i].session
        /\ session' = _TETrace[j].session
        /\ generation  = _TETrace[i].generation
        /\ generation' = _TETrace[j].generation
        /\ cache  = _TETrace[i].cache
        /\ cache' = _TETrace[j].cache
        /\ responseOwner  = _TETrace[i].responseOwner
        /\ responseOwner' = _TETrace[j].responseOwner
        /\ requestGeneration  = _TETrace[i].requestGeneration
        /\ requestGeneration' = _TETrace[j].requestGeneration
        /\ requestOwner  = _TETrace[i].requestOwner
        /\ requestOwner' = _TETrace[j].requestOwner

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("SessionContentBoundary_TTrace_1793166795.json", _TETrace)

=============================================================================

 Note that you can extract this module `SessionContentBoundary_TEExpression`
  to a dedicated file to reuse `expression` (the module in the
  dedicated `SessionContentBoundary_TEExpression.tla` file takes precedence
  over the module `SessionContentBoundary_TEExpression` below).

---- MODULE SessionContentBoundary_TEExpression ----
EXTENDS Sequences, SessionContentBoundary, TLCExt, Toolbox, Naturals, TLC

expression ==
    [
        \* To hide variables of the `SessionContentBoundary` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        cacheGeneration |-> cacheGeneration
        ,cacheOwner |-> cacheOwner
        ,responseGeneration |-> responseGeneration
        ,request |-> request
        ,session |-> session
        ,generation |-> generation
        ,cache |-> cache
        ,responseOwner |-> responseOwner
        ,requestGeneration |-> requestGeneration
        ,requestOwner |-> requestOwner

        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_cacheGenerationUnchanged |-> cacheGeneration = cacheGeneration'

        \* Format the `cacheGeneration` variable as Json value.
        \* ,_cacheGenerationJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(cacheGeneration)

        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_cacheGenerationModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].cacheGeneration # _TETrace[s-1].cacheGeneration
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE SessionContentBoundary_TETrace ----
\*EXTENDS IOUtils, SessionContentBoundary, TLC
\*
\*trace == IODeserialize("SessionContentBoundary_TTrace_1793166795.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE SessionContentBoundary_TETrace ----
EXTENDS SessionContentBoundary, TLC

trace ==
    <<
    ([responseGeneration |-> -1,generation |-> 0,request |-> "idle",cache |-> FALSE,responseOwner |-> "none",cacheGeneration |-> -1,requestGeneration |-> -1,session |-> "A",cacheOwner |-> "none",requestOwner |-> "none"]),
    ([responseGeneration |-> -1,generation |-> 0,request |-> "inflight",cache |-> FALSE,responseOwner |-> "none",cacheGeneration |-> -1,requestGeneration |-> 0,session |-> "A",cacheOwner |-> "none",requestOwner |-> "A"]),
    ([responseGeneration |-> 0,generation |-> 0,request |-> "ready",cache |-> FALSE,responseOwner |-> "A",cacheGeneration |-> -1,requestGeneration |-> 0,session |-> "A",cacheOwner |-> "none",requestOwner |-> "A"]),
    ([responseGeneration |-> 0,generation |-> 1,request |-> "ready",cache |-> FALSE,responseOwner |-> "A",cacheGeneration |-> -1,requestGeneration |-> 0,session |-> "none",cacheOwner |-> "none",requestOwner |-> "A"]),
    ([responseGeneration |-> 0,generation |-> 1,request |-> "done",cache |-> TRUE,responseOwner |-> "A",cacheGeneration |-> 0,requestGeneration |-> 0,session |-> "none",cacheOwner |-> "A",requestOwner |-> "A"])
    >>
----


=============================================================================

---- CONFIG SessionContentBoundary_TTrace_1793166795 ----
CONSTANTS
    FixEnabled = FALSE

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
\* Generated on Wed Oct 28 14:53:16 KST 2026