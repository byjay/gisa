#!/usr/bin/env python3
"""해설 부채 상환 도구 — 작성한 해설을 exams.json 에 안전하게 적용한다.

왜 스크립트로 하는가:
  16,653 문항 JSON 을 손으로 편집하면 (a) 다른 문항을 망가뜨리고
  (b) 어떤 문항을 고쳤는지 추적이 안 된다. 그래서 '적용'만 담당하는
  도구를 따로 두고, 아래 안전장치를 강제한다.

안전장치 (하나라도 깨지면 아무것도 쓰지 않는다):
  1. 대상 문항이 '부채'로 분류된 것인지 확인 — 이미 좋은 해설을 덮어쓰지 않는다.
  2. 새 해설의 머리말 정답번호가 answer 필드와 일치하는지 확인 (V5 사전 차단).
  3. 새 해설이 공식 분류기로 'ok' 인지 확인 — 부채를 부채로 바꾸는 헛일 방지.
  4. 전부 통과해야 파일을 쓴다(all-or-nothing). 부분 적용은 추적을 망친다.
  5. 쓰기 전 원본을 .bak 로 남긴다.

사용:
  python3 tool/audit/apply_explanations.py <해설JSON경로>

해설JSON 형식:
  {"track": "elec_industrial",
   "items": [{"exam": "2020_2", "no": 81, "explanation": "✅ 정답 1번\\n\\n..."}]}
"""
import importlib.util
import json
import re
import shutil
import sys
import os
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))


def load_classifier():
    p = os.path.join(HERE, 'verify_learning_data.py')
    spec = importlib.util.spec_from_file_location('vld', p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    if m.selfcheck_classifier() != 0:
        print('✗ 분류기 자기검사 실패 — 적용을 중단한다')
        sys.exit(1)
    return m


def head_answer(exp: str):
    """해설 머리말에서 정답번호를 뽑는다. 없으면 None."""
    mt = re.match(r'^\s*✅?\s*정답\s*(\d+)\s*번', exp or '')
    return int(mt.group(1)) if mt else None


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    vld = load_classifier()
    spec = json.load(open(sys.argv[1], encoding='utf-8'))
    track = spec['track']
    items = spec['items']

    path = os.path.join('assets', 'data', track, 'exams.json')
    if not os.path.exists(path):
        print(f'✗ {path} 없음 — 실행 위치를 확인하라')
        return 1
    data = json.load(open(path, encoding='utf-8'))

    # 문항 색인
    index = {}
    for ex in data:
        for q in ex.get('questions', []):
            index[(str(ex.get('id')), q.get('no'))] = q

    errors = []
    plan = []
    for it in items:
        key = (str(it['exam']), it['no'])
        q = index.get(key)
        if q is None:
            errors.append(f'{key}: 해당 문항이 없다')
            continue
        # 1. 부채인지 확인
        old_kind = vld.classify_explanation(q.get('explanation', ''))
        if old_kind == 'ok':
            errors.append(f'{key}: 이미 실질 해설이 있다 — 덮어쓰지 않는다')
            continue
        new = it['explanation']
        # 2. 머리말 정답번호 == answer
        ha = head_answer(new)
        if ha is None:
            errors.append(f'{key}: 새 해설에 "✅ 정답 N번" 머리말이 없다')
            continue
        if ha != q.get('answer'):
            errors.append(
                f'{key}: 새 해설은 {ha}번이라 하는데 answer={q.get("answer")}')
            continue
        # 3. 새 해설이 실질 해설인지
        nk = vld.classify_explanation(new)
        if nk != 'ok':
            errors.append(f'{key}: 새 해설도 부채로 분류됨({nk}) — 본문이 부실하다')
            continue
        plan.append((key, q, new, old_kind))

    if errors:
        print(f'✗ 적용 중단 — 검증 실패 {len(errors)}건 (파일은 건드리지 않았다)')
        for e in errors[:20]:
            print(f'    {e}')
        if len(errors) > 20:
            print(f'    … 외 {len(errors) - 20}건')
        return 1

    if not plan:
        print('적용할 항목이 없다')
        return 1

    shutil.copy(path, path + '.bak')
    for _key, q, new, _ok in plan:
        q['explanation'] = new
    with open(path, 'w', encoding='utf-8') as fp:
        json.dump(data, fp, ensure_ascii=False, indent=1)

    print(f'✓ {track}: 해설 {len(plan)}건 적용 (원본은 {path}.bak)')
    for k, v in Counter(p[3] for p in plan).items():
        print(f'    {k} → 실질해설: {v}건')
    return 0


if __name__ == '__main__':
    sys.exit(main())
