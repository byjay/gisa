#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""학습데이터 사실검증 — 구조 무결성 + 해설↔정답 교차검증.

## 왜 필요한가
문항 16,653개는 사람이 눈으로 다 볼 수 없다. 그런데 **정답과 해설이 서로
어긋난 문항**은 학습자에게 직접적인 피해를 준다("해설은 3번이라는데 정답은 2번").
그래서 기계가 확인할 수 있는 것만 골라 전수 검사한다.

## 설계 원칙 (대리지표 금지)
- 「해설이 존재한다」는 품질의 증거가 아니다. 그건 분량일 뿐이다.
  그래서 **해설 안에 적힌 정답 번호**를 뽑아 `answer` 필드와 **직접 대조**한다.
- 검사기가 스스로를 검사한다: 대조 가능한 문항이 전체의 일정 비율 미만이면
  "통과"가 아니라 **검사 무효**로 보고한다. 표본이 없는데 통과라고 말하는 것은
  거짓이기 때문이다.
- 실패는 실패로 보고한다. 위반 건수를 0으로 만들기 위해 규칙을 느슨하게 하지 않는다.

## 검사 항목
  V0 JSON 파싱 가능 · 필수 키 존재
  V1 answer 가 1..len(options) 범위 안
  V2 보기 개수가 4개 (한국 기사시험 표준)
  V3 보기 중복 없음
  V4 question / options 공백 아님
  V5 해설에 적힌 정답번호 == answer  ← 핵심 교차검증
  V6 같은 시험 세트 안에서 문항번호(no) 중복 없음
  V7 subject / topic 공백 아님

종료코드 0 = 위반 없음. 1 = 위반 있음(또는 검사 무효).
"""
import json
import glob
import re
import sys
from collections import defaultdict

# 해설 첫머리의 "✅ 정답 2번" / "정답: 3" / "[정답] 4번" 등을 인식한다.
# 지나치게 관대한 패턴은 오탐을 만들므로, 정답을 명시한 형태만 좁게 잡는다.
ANS_PATTERNS = [
    re.compile(r'정답\s*[:：]?\s*([1-4])\s*번'),
    re.compile(r'정답\s*[:：]\s*([1-4])'),
    re.compile(r'^\s*[✅✔]\s*([1-4])\s*번'),
]

# 원문자 보기 번호(①②③④)로 정답을 적은 경우도 대조 대상에 넣는다.
CIRCLED = {'①': 1, '②': 2, '③': 3, '④': 4}
CIRCLED_RE = re.compile(r'정답\s*[:：]?\s*([①②③④])')


def extract_answer_from_explanation(text: str):
    """해설에서 정답 번호를 추출한다. 확신할 수 없으면 None(=대조 제외)."""
    if not text:
        return None
    head = text[:120]  # 정답 표기는 서두에 온다. 본문 속 숫자를 오탐하지 않도록 제한.
    for p in ANS_PATTERNS:
        m = p.search(head)
        if m:
            return int(m.group(1))
    m = CIRCLED_RE.search(head)
    if m:
        return CIRCLED[m.group(1)]
    return None


def main():
    files = sorted(glob.glob('assets/data/*/exams.json'))
    if not files:
        print('✗ assets/data/*/exams.json 을 찾지 못했다 — 실행 위치를 확인하라')
        return 1

    violations = defaultdict(list)   # 코드 -> [메시지]
    total_q = 0
    comparable = 0                   # V5 대조가 가능했던 문항 수
    per_track = {}

    for f in files:
        track = f.split('/')[2]
        try:
            data = json.load(open(f, encoding='utf-8'))
        except Exception as e:
            violations['V0'].append(f'{f}: JSON 파싱 실패 {e}')
            continue
        exams = data if isinstance(data, list) else data.get('exams', [])
        t_q = t_cmp = t_bad = 0

        for ex in exams:
            seen_no = set()
            ex_name = ex.get('title') or ex.get('name') or ex.get('id') or '?'
            for q in ex.get('questions', []):
                total_q += 1
                t_q += 1
                loc = f'{track}/{ex_name}/no={q.get("no")}'

                opts = q.get('options')
                if not isinstance(opts, list):
                    violations['V0'].append(f'{loc}: options 가 리스트가 아니다')
                    continue

                ans = q.get('answer')
                if not isinstance(ans, int) or not (1 <= ans <= len(opts)):
                    violations['V1'].append(f'{loc}: answer={ans} 가 1..{len(opts)} 범위 밖')
                    t_bad += 1

                if len(opts) != 4:
                    violations['V2'].append(f'{loc}: 보기 {len(opts)}개 (4개여야 함)')

                norm = [str(o).strip() for o in opts]
                if len(set(norm)) != len(norm):
                    violations['V3'].append(f'{loc}: 보기 중복')

                if not str(q.get('question', '')).strip():
                    violations['V4'].append(f'{loc}: 문제 본문 비어있음')
                if any(not o for o in norm):
                    violations['V4'].append(f'{loc}: 빈 보기 존재')

                # V5 핵심 교차검증 — 해설이 말하는 정답과 answer 필드가 같은가
                exp_ans = extract_answer_from_explanation(q.get('explanation', ''))
                if exp_ans is not None:
                    comparable += 1
                    t_cmp += 1
                    if exp_ans != ans:
                        violations['V5'].append(
                            f'{loc}: 해설은 {exp_ans}번이라 하는데 answer={ans}')
                        t_bad += 1

                no = q.get('no')
                if no in seen_no:
                    violations['V6'].append(f'{loc}: 문항번호 중복')
                seen_no.add(no)

                if not str(q.get('subject', '')).strip():
                    violations['V7'].append(f'{loc}: subject 비어있음')
                if not str(q.get('topic', '')).strip():
                    violations['V7'].append(f'{loc}: topic 비어있음')

        per_track[track] = (t_q, t_cmp, t_bad)

    # ── 보고 ────────────────────────────────────────────────
    print('=' * 62)
    print('학습데이터 사실검증 결과')
    print('=' * 62)
    print(f'  트랙 {len(per_track)}개 / 문항 {total_q:,}개')
    print(f'  해설↔정답 대조 가능 {comparable:,}개 '
          f'({comparable / total_q * 100:.1f}%)' if total_q else '')
    print()
    print('  %-22s %8s %10s %8s' % ('트랙', '문항', '대조가능', '위반'))
    for t, (q, c, b) in sorted(per_track.items()):
        print('  %-22s %8d %10d %8d' % (t, q, c, b))
    print()

    codes = {
        'V0': 'JSON/필수키 오류',
        'V1': 'answer 범위 오류',
        'V2': '보기 개수 != 4',
        'V3': '보기 중복',
        'V4': '빈 문항/보기',
        'V5': '해설↔정답 불일치 (핵심)',
        'V6': '문항번호 중복',
        'V7': 'subject/topic 누락',
    }
    total_v = sum(len(v) for v in violations.values())
    for code, label in codes.items():
        n = len(violations[code])
        mark = '✓' if n == 0 else '✗'
        print(f'  {mark} {code} {label:<26} {n}건')
        for msg in violations[code][:5]:
            print(f'       - {msg}')
        if n > 5:
            print(f'       … 외 {n - 5}건')

    print()
    # 검사기 자기검사 — 표본이 없으면 통과라고 말하지 않는다
    ratio = comparable / total_q if total_q else 0
    if ratio < 0.30:
        print(f'✗ 검사 무효 — 해설↔정답 대조 가능 문항이 {ratio*100:.1f}% 뿐이다.')
        print('  표본이 이렇게 적으면 "V5 위반 0건"은 품질의 증거가 아니라')
        print('  검사하지 못했다는 뜻이다. 통과로 보고하지 않는다.')
        return 1

    if total_v == 0:
        print(f'✓ 위반 0건 — 문항 {total_q:,}개 전수 검사, '
              f'해설↔정답 {comparable:,}개 대조 완료')
        return 0
    print(f'✗ 위반 {total_v}건 — 위 목록을 고쳐라 (검사를 느슨하게 하는 것은 금지)')
    return 1


if __name__ == '__main__':
    sys.exit(main())
