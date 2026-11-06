-------------------------- MODULE RewardProperties --------------------------
EXTENDS Naturals, FiniteSets

QuotaWithinLimit(balance, limit) == balance <= limit
LedgerMatchesBalance(balance, grantedTransactions) == balance = Cardinality(grantedTransactions)
GrantsSubsetOfVerified(grantedTransactions, verifiedTransactions) == grantedTransactions \subseteq verifiedTransactions
GrantRejectDisjoint(grantedTransactions, rejectedTransactions) == grantedTransactions \cap rejectedTransactions = {}
OutcomesAccounted(grantedTransactions, rejectedTransactions, processedTransactions) ==
    (grantedTransactions \cup rejectedTransactions) \subseteq processedTransactions

=============================================================================
