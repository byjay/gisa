import json, os

# 최신 KEC 개정(2021 시행 + 2024.10 고시개정) 조사 결과를 기출 답 기준에 반영
NEW_ITEMS = {
    '① 배선설비': [
        {
            'item': '전선 식별(색상) 국제표준화 (KEC 121.2)',
            'before': '접지=녹색, 상별 구분 임의',
            'after': 'L1=갈색 · L2=흑색 · L3=회색 · N(중성)=청색 · PE(보호)=녹색-노랑',
        },
        {
            'item': '화재 확산 최소화 배선설비 (KEC 232.3.6, 2024 개정)',
            'before': '별도 규정 미흡',
            'after': '난연 재료 선정 + 관통부 방화구획(내화충전) 의무화',
        },
    ],
    '② 접지설비': [
        {
            'item': '종별 접지(제1/2/3종·특별3종) 방식 (KEC 140)',
            'before': '제1종 10Ω · 제3종 100Ω 등 종별 접지',
            'after': '종별 접지 전면 폐지 → 계통접지(TN·TT·IT)로 전환 (구 종별문제는 오답)',
        },
        {
            'item': '전압 구분 / 저압 범위 확대 (KEC 111.1)',
            'before': '저압 교류 600V · 직류 750V 이하',
            'after': '저압 교류 1000V · 직류 1500V 이하로 확대',
        },
        {
            'item': '저압 접지시스템 접지저항 상한값 (KEC 211.2.6/7, 2024 개정)',
            'before': '상한값 규정 없음',
            'after': '감전보호를 위한 접지저항 상한값 신설(계통별 산정)',
        },
    ],
}

FILES = [
    'backend/data/study/electrician/exam_info_2026.json',
    'backend/data/study/elec_construction/exam_info_2026.json',
    'backend/data/study/fire_electric/exam_info_2026.json',
]

new_traps = [
    '제1/2/3종 접지·접지저항(10Ω/100Ω) 보기는 무조건 오답 → 계통접지(TN/TT/IT)',
    '저압을 교류 600V·직류 750V로 답하면 오답 → 1000V/1500V',
    '전선 색상: 중성선 청색·보호도체 녹황 혼동 주의(구기출은 임의색)',
]
new_mnemonics = [
    '색상: "갈흑회 · 청 · 녹황" (L1갈-L2흑-L3회 · 중성청 · 보호녹황)',
    '저압: "천·천오백" (교류 1000V · 직류 1500V)',
    '접지: "종별은 폐지, 계통은 티엔티티아이티" (TN·TT·IT)',
]

for f in FILES:
    if not os.path.exists(f):
        print('SKIP (missing):', f)
        continue
    d = json.load(open(f, encoding='utf-8'))
    kec = d.get('kecChanges2026')
    if not kec:
        print('SKIP (no kec):', f)
        continue
    areas = kec['areas']
    by_name = {a['area']: a for a in areas}
    for area_name, items in NEW_ITEMS.items():
        target = by_name.get(area_name)
        if target is None:
            target = {'area': area_name, 'changes': []}
            areas.append(target)
            by_name[area_name] = target
        existing = {c['item'] for c in target['changes']}
        for it in items:
            if it['item'] not in existing:
                target['changes'].append(it)
    # traps + mnemonics (dedupe)
    traps = kec.get('trapPoints', [])
    for t in new_traps:
        if t not in traps:
            traps.append(t)
    kec['trapPoints'] = traps
    mne = kec.get('mnemonics', [])
    for m in new_mnemonics:
        if m not in mne:
            mne.append(m)
    kec['mnemonics'] = mne
    kec['warning'] = ('본 앱 수록 기출의 설비 문제 일부는 개정 전 수치가 정답으로 되어 있습니다. '
                      '아래 "개정 후"가 현행 KEC(2021 시행·2024.10 고시개정) 기준 정답이며, '
                      '풀이 중 종별 접지·구 저압범위·구 색상 문제는 원리만 익히고 답은 개정 기준으로 갱신하세요.')
    kec['lastResearched'] = '2024.10 고시개정 반영 (KEC 111.1·121.2·140·211.2·232.3.6)'
    json.dump(d, open(f, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print('UPDATED:', f, '| total areas:', len(areas))

print('DONE')
