#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""해설 머리말의 정답번호가 answer 필드와 어긋난 문항을 고친다.

## 무엇을 고치고, 무엇을 고치지 않는가 (중요)
`tool/audit/verify_learning_data.py` V5 가 잡아낸 불일치 14건을 실제로 열어보니
공통 패턴이 있었다:

  - `answer` 필드는 **원본 시험지의 정답**이고 검증 결과 옳다.
    (예: elec_construction/2022_1 no=26 "3상3선식/단상2선식 전선량비"의
     정답은 0.75 = 1번이 맞다. 해설은 3번이라고 적혀 있었다.)
  - 해설 **본문**은 문제와 무관한 일반 이론이 붙어 있다(생성 과정의 오염).
  - 따라서 잘못된 것은 해설 머리말의 "✅ 정답: N번" 표기다.

그래서 이 스크립트는 **머리말의 번호만** `answer` 에 맞춰 고친다.
`answer` 는 절대 건드리지 않는다 — 정답을 해설에 맞춰 바꾸면 원본 시험지와
어긋나 학습자에게 틀린 답을 가르치게 된다. 어느 쪽을 신뢰할지는 **측정 후 판단**했다.

## 고치지 않고 남기는 것 (숨기지 않는다)
해설 본문이 문제와 무관한 문제는 이 스크립트로 고칠 수 없다. 사람이 다시
써야 한다. 번호만 맞춘다고 해설이 옳아지는 것이 아니므로, 해당 문항에는
`explanation_needs_rewrite: true` 표시를 남겨 나중에 추적할 수 있게 한다.
이 표시를 지워서 "해결됐다"고 하는 것은 금지한다.

사용법:  python3 tool/audit/fix_explanation_answer_mismatch.py [--apply]
         (--apply 없으면 미리보기만)
"""
import json
import glob
import re
import sys

ANS_PATTERNS = [
    re.compile(r'(정답\s*[:：]?\s*)([1-4])(\s*번)'),
    re.compile(r'(정답\s*[:：]\s*)([1-4])'),
    re.compile(r'(^\s*[✅✔]\s*)([1-4])(\s*번)'),
]
CIRCLED = {'①': 1, '②': 2, '③': 3, '④': 4}
NUM2CIRCLED = {v: k for k, v in CIRCLED.items()}
CIRCLED_RE = re.compile(r'(정답\s*[:：]?\s*)([①②③④])')


def extract(text: str):
    if not text:
        return None
    head = text[:120]
    for p in ANS_PATTERNS:
        m = p.search(head)
        if m:
            return int(m.group(2))
    m = CIRCLED_RE.search(head)
    if m:
        return CIRCLED[m.group(2)]
    return None


def rewrite_head(text: str, correct: int) -> str:
    """머리말 120자 안의 정답 번호만 correct 로 바꾼다. 본문은 손대지 않는다."""
    head, tail = text[:120], text[120:]
    for p in ANS_PATTERNS:
        m = p.search(head)
        if m:
            g3 = m.group(3) if m.lastindex and m.lastindex >= 3 else ''
            head = head[:m.start()] + m.group(1) + str(correct) + g3 + head[m.end():]
            return head + tail
    m = CIRCLED_RE.search(head)
    if m:
        head = head[:m.start()] + m.group(1) + NUM2CIRCLED[correct] + head[m.end():]
        return head + tail
    return text


def main():
    apply = '--apply' in sys.argv
    total_fixed = 0
    for f in sorted(glob.glob('assets/data/*/exams.json')):
        data = json.load(open(f, encoding='utf-8'))
        exams = data if isinstance(data, list) else data.get('exams', [])
        changed = 0
        for ex in exams:
            for q in ex.get('questions', []):
                exp = q.get('explanation', '')
                got = extract(exp)
                ans = q.get('answer')
                if got is None or got == ans:
                    continue
                new = rewrite_head(exp, ans)
                if new == exp:
                    print(f'  ! 치환 실패(수동 확인 필요): {f} no={q.get("no")}')
                    continue
                print(f'  {f} no={q.get("no")}: 해설 {got}번 → {ans}번 '
                      f'(answer 는 그대로 {ans})')
                if apply:
                    q['explanation'] = new
                    # 본문이 문제와 무관한 상태는 남아있다. 사람이 다시 써야 한다.
                    q['explanation_needs_rewrite'] = True
                changed += 1
        if changed and apply:
            with open(f, 'w', encoding='utf-8') as fp:
                json.dump(data, fp, ensure_ascii=False, indent=1)
            print(f'  → 저장: {f} ({changed}건)')
        total_fixed += changed

    print()
    if not apply:
        print(f'미리보기 {total_fixed}건. 실제 적용하려면 --apply 를 붙여라.')
    else:
        print(f'적용 완료 {total_fixed}건.')
        print('※ 해설 본문이 문제와 무관한 문제는 남아있다.')
        print('  explanation_needs_rewrite=true 로 표시했으니 사람이 다시 써야 한다.')
        print('  이 표시를 지워서 해결됐다고 하는 것은 금지한다.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
