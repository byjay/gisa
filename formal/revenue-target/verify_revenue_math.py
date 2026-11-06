#!/usr/bin/env python3
"""Exact-integer consistency check for docs/MARKETING_REVENUE_PLAN_1M.md."""
from pathlib import Path
import sys
sys.stdout.reconfigure(encoding='utf-8')

TARGET_WON = 1_000_000
MONTHLY_PRICE_WON = 4_900
FEE_BPS = 1_500
BPS_DENOMINATOR = 10_000
CONVERSION_RATES = ((2, 100), (5, 100), (8, 100))
PLAN = Path(__file__).resolve().parents[2] / "docs" / "MARKETING_REVENUE_PLAN_1M.md"


def ceil_div(numerator: int, denominator: int) -> int:
    if numerator < 0 or denominator <= 0:
        raise ValueError("ceil_div expects a nonnegative numerator and positive denominator")
    return (numerator + denominator - 1) // denominator


gross_payers = ceil_div(TARGET_WON, MONTHLY_PRICE_WON)
net_per_payer_won = MONTHLY_PRICE_WON * (BPS_DENOMINATOR - FEE_BPS) // BPS_DENOMINATOR
net_payers = ceil_div(TARGET_WON, net_per_payer_won)

assert gross_payers * MONTHLY_PRICE_WON >= TARGET_WON
assert (gross_payers - 1) * MONTHLY_PRICE_WON < TARGET_WON
assert net_per_payer_won == 4_165
assert net_payers * net_per_payer_won >= TARGET_WON
assert (net_payers - 1) * net_per_payer_won < TARGET_WON

rows = []
for rate_numerator, rate_denominator in CONVERSION_RATES:
    gross_mau = ceil_div(gross_payers * rate_denominator, rate_numerator)
    net_mau = ceil_div(net_payers * rate_denominator, rate_numerator)
    assert gross_mau * rate_numerator >= gross_payers * rate_denominator
    assert (gross_mau - 1) * rate_numerator < gross_payers * rate_denominator
    assert net_mau * rate_numerator >= net_payers * rate_denominator
    assert (net_mau - 1) * rate_numerator < net_payers * rate_denominator
    rows.append((rate_numerator, gross_mau, net_mau))

plan = PLAN.read_text(encoding="utf-8")
for required in ("205명", "241명", "10,250", "12,050", "4,100", "4,820", "2,563", "3,013"):
    assert required in plan, f"plan does not contain checked result: {required}"

assert gross_payers == 205
assert net_payers == 241
print(f"PASS gross: {gross_payers} × ₩{MONTHLY_PRICE_WON:,} = ₩{gross_payers * MONTHLY_PRICE_WON:,}")
print(f"PASS net at {FEE_BPS // 100}% assumed fee: {net_payers} × ₩{net_per_payer_won:,} = ₩{net_payers * net_per_payer_won:,}")
for rate, gross_mau, net_mau in rows:
    print(f"PASS conversion {rate}%: gross MAU={gross_mau:,}; net MAU={net_mau:,}")
