#!/usr/bin/env python3
"""Tracked source files에서 실수로 커밋된 비밀 패턴을 탐지한다."""

from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "Cerebras API key": re.compile(r"csk-[A-Za-z0-9_-]{20,}"),
    "OpenAI-style secret": re.compile(r"sk-[A-Za-z0-9_-]{24,}"),
    "Google API key": re.compile(r"AIza[0-9A-Za-z_-]{30,}"),
}
ALLOW_SUFFIXES = {".dart", ".yaml", ".yml", ".json", ".xml", ".gradle", ".kts", ".md"}


def tracked_files() -> list[Path]:
    output = subprocess.check_output(
        ["git", "ls-files"], cwd=ROOT, text=True, encoding="utf-8"
    )
    return [ROOT / line for line in output.splitlines() if line]


def main() -> int:
    findings: list[str] = []
    for path in tracked_files():
        if path.suffix.lower() not in ALLOW_SUFFIXES or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for name, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                findings.append(f"{path.relative_to(ROOT)}:{line}: {name}")
    if findings:
        print("비밀 탐지 실패:")
        print("\n".join(findings))
        return 1
    print("비밀 탐지 통과: 추적 파일에서 운영 키 패턴 0건")
    return 0


if __name__ == "__main__":
    sys.exit(main())
