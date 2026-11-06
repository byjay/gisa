# -*- coding: utf-8 -*-
"""R37 병합 적용: electrician/lessons.json 에 basic_explain/advanced/silgi 저술 반영.
- 기존 필드(intro/sections/formulas/must/exam_how/mnemonics/traps/strategy/subject/topic/freq/importance) 100% 보존.
- basic_explain: 비어있던 29건 신규 채움. 이미 R36에서 채워진 17건은 '기존 유지'(사용자 이전 저술 존중).
  단, ELEC 신규본이 더 상세하면 교체하되 기존이 이미 충실하면 유지 — 안전하게 '기존 비어있을 때만 채움' 정책.
- advanced/silgi: 전량 비어있으므로 무조건 채움.
"""
import json, sys
sys.path.insert(0, 'tool')
from content_elec_r37 import ELEC

PATH = 'backend/data/study/electrician/lessons.json'

def main():
    data = json.load(open(PATH, encoding='utf-8'))
    n_basic_new = n_basic_keep = n_adv = n_silgi = 0
    for l in data:
        key = (l['subject'], l['topic'])
        c = ELEC.get(key)
        if not c:
            continue
        # basic_explain: 기존이 비어있을 때만 신규 채움 (기존 저술 존중)
        cur = (l.get('basic_explain') or '').strip()
        if not cur:
            l['basic_explain'] = c['basic_explain']
            n_basic_new += 1
        else:
            n_basic_keep += 1
        # advanced: 전량 채움 (기존 없음)
        if not l.get('advanced'):
            l['advanced'] = c['advanced']
            n_adv += 1
        # silgi: 전량 채움
        if not (l.get('silgi') or '').strip():
            l['silgi'] = c['silgi']
            n_silgi += 1
    json.dump(data, open(PATH, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'basic_explain: {n_basic_new} 신규, {n_basic_keep} 기존유지')
    print(f'advanced: {n_adv} 채움 / silgi: {n_silgi} 채움')

    # ── 사후 커버리지 검증 ──
    d = json.load(open(PATH, encoding='utf-8'))
    n = len(d)
    def cnt(f):
        c = 0
        for l in d:
            v = l.get(f)
            if isinstance(v, str) and v.strip(): c += 1
            elif isinstance(v, list) and v: c += 1
        return c
    print(f'--- 최종 커버리지 ({n} lessons) ---')
    for f in ['basic_explain', 'advanced', 'silgi', 'must', 'exam_how', 'intro', 'sections', 'formulas', 'strategy']:
        print(f'  {f:14s}: {cnt(f)}/{n}')

if __name__ == '__main__':
    main()
