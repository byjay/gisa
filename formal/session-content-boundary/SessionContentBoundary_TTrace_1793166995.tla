---- MODULE SessionContentBoundary_TTrace_1793166995 ----
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
        responseCacheGeneration = (0)
        /\
        request = ("done")
        /\
        cache = (TRUE)
        /\
        responseOwner = ("A")
        /\
        cacheGeneration = (0)
        /\
        session = ("A")
        /\
        requestSessionGeneration = (0)
        /\
        cacheOwner = ("A")
        /\
        requestOwner = ("A")
        /\
        cacheAtGeneration = (0)
        /\
        responseSessionGeneration = (0)
        /\
        sessionGeneration = (0)
        /\
        requestCacheGeneration = (0)
    )
----

_init ==
    /\ cacheGeneration = _TETrace[1].cacheGeneration
    /\ cacheOwner = _TETrace[1].cacheOwner
    /\ sessionGeneration = _TETrace[1].sessionGeneration
    /\ request = _TETrace[1].request
    /\ session = _TETrace[1].session
    /\ requestCacheGeneration = _TETrace[1].requestCacheGeneration
    /\ requestSessionGeneration = _TETrace[1].requestSessionGeneration
    /\ cacheAtGeneration = _TETrace[1].cacheAtGeneration
    /\ cache = _TETrace[1].cache
    /\ responseOwner = _TETrace[1].responseOwner
    /\ responseSessionGeneration = _TETrace[1].responseSessionGeneration
    /\ requestOwner = _TETrace[1].requestOwner
    /\ responseCacheGeneration = _TETrace[1].responseCacheGeneration
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ cacheGeneration  = _TETrace[i].cacheGeneration
        /\ cacheGeneration' = _TETrace[j].cacheGeneration
        /\ cacheOwner  = _TETrace[i].cacheOwner
        /\ cacheOwner' = _TETrace[j].cacheOwner
        /\ sessionGeneration  = _TETrace[i].sessionGeneration
        /\ sessionGeneration' = _TETrace[j].sessionGeneration
        /\ request  = _TETrace[i].request
        /\ request' = _TETrace[j].request
        /\ session  = _TETrace[i].session
        /\ session' = _TETrace[j].session
        /\ requestCacheGeneration  = _TETrace[i].requestCacheGeneration
        /\ requestCacheGeneration' = _TETrace[j].requestCacheGeneration
        /\ requestSessionGeneration  = _TETrace[i].requestSessionGeneration
        /\ requestSessionGeneration' = _TETrace[j].requestSessionGeneration
        /\ cacheAtGeneration  = _TETrace[i].cacheAtGeneration
        /\ cacheAtGeneration' = _TETrace[j].cacheAtGeneration
        /\ cache  = _TETrace[i].cache
        /\ cache' = _TETrace[j].cache
        /\ responseOwner  = _TETrace[i].responseOwner
        /\ responseOwner' = _TETrace[j].responseOwner
        /\ responseSessionGeneration  = _TETrace[i].responseSessionGeneration
        /\ responseSessionGeneration' = _TETrace[j].responseSessionGeneration
        /\ requestOwner  = _TETrace[i].requestOwner
        /\ requestOwner' = _TETrace[j].requestOwner
        /\ responseCacheGeneration  = _TETrace[i].responseCacheGeneration
        /\ responseCacheGeneration' = _TETrace[j].responseCacheGeneration

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("SessionContentBoundary_TTrace_1793166995.json", _TETrace)

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
        ,sessionGeneration |-> sessionGeneration
        ,request |-> request
        ,session |-> session
        ,requestCacheGeneration |-> requestCacheGeneration
        ,requestSessionGeneration |-> requestSessionGeneration
        ,cacheAtGeneration |-> cacheAtGeneration
        ,cache |-> cache
        ,responseOwner |-> responseOwner
        ,responseSessionGeneration |-> responseSessionGeneration
        ,requestOwner |-> requestOwner
        ,responseCacheGeneration |-> responseCacheGeneration

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
\*trace == IODeserialize("SessionContentBoundary_TTrace_1793166995.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE SessionContentBoundary_TETrace ----
EXTENDS SessionContentBoundary, TLC

trace ==
    <<
    ([responseCacheGeneration |-> -1,request |-> "idle",cache |-> FALSE,responseOwner |-> "none",cacheGeneration |-> 0,session |-> "A",requestSessionGeneration |-> -1,cacheOwner |-> "none",requestOwner |-> "none",cacheAtGeneration |-> -1,responseSessionGeneration |-> -1,sessionGeneration |-> 0,requestCacheGeneration |-> -1]),
    ([responseCacheGeneration |-> -1,request |-> "inflight",cache |-> FALSE,responseOwner |-> "none",cacheGeneration |-> 0,session |-> "A",requestSessionGeneration |-> 0,cacheOwner |-> "none",requestOwner |-> "A",cacheAtGeneration |-> -1,responseSessionGeneration |-> -1,sessionGeneration |-> 0,requestCacheGeneration |-> 0]),
    ([responseCacheGeneration |-> 0,request |-> "ready",cache |-> FALSE,responseOwner |-> "A",cacheGeneration |-> 0,session |-> "A",requestSessionGeneration |-> 0,cacheOwner |-> "none",requestOwner |-> "A",cacheAtGeneration |-> -1,responseSessionGeneration |-> 0,sessionGeneration |-> 0,requestCacheGeneration |-> 0]),
    ([responseCacheGeneration |-> 0,request |-> "done",cache |-> TRUE,responseOwner |-> "A",cacheGeneration |-> 0,session |-> "A",requestSessionGeneration |-> 0,cacheOwner |-> "A",requestOwner |-> "A",cacheAtGeneration |-> 0,responseSessionGeneration |-> 0,sessionGeneration |-> 0,requestCacheGeneration |-> 0])
    >>
----


=============================================================================

---- CONFIG SessionContentBoundary_TTrace_1793166995 ----
CONSTANTS
    FixEnabled = TRUE

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
\* Generated on Wed Oct 28 14:56:36 KST 2026