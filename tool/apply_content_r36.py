# -*- coding: utf-8 -*-
"""R36 콘텐츠 병합 스크립트
- fire_electric: content_fe.FE 20개 토픽 전면 교체
- elec_construction: content_ec.EC 5개(전기응용) + 전기기사 37개 매칭 토픽 rich 콘텐츠 복사
- electrician: 기존 46개에 R36 필드(must/exam_how/basic_explain) 파생·저술 추가
- formulas 'desc' → 'note' 정규화
"""
import json, re, sys, copy
sys.path.insert(0, 'tool')
from content_fe import FE
from content_ec import EC

def norm_formulas(fs):
    out = []
    for f in fs or []:
        f = dict(f)
        if 'desc' in f and 'note' not in f:
            f['note'] = f.pop('desc')
        f.pop('desc', None)
        out.append({'name': f.get('name',''), 'expr': f.get('expr',''), 'note': f.get('note','')})
    return out

def apply_dict(base, content):
    """base(subject/topic/freq/importance 유지) + content 병합"""
    out = {
        'subject': base['subject'], 'topic': base['topic'],
        'freq': base.get('freq', 0), 'importance': base.get('importance', 3),
        'intro': content.get('intro', base.get('intro','')),
        'sections': content.get('sections', base.get('sections', [])),
        'formulas': norm_formulas(content.get('formulas', base.get('formulas', []))),
        'mnemonics': content.get('mnemonics', base.get('mnemonics', [])),
        'traps': content.get('traps', base.get('traps', [])),
        'strategy': content.get('strategy', base.get('strategy','')),
        'basic_explain': content.get('basic_explain',''),
        'exam_how': content.get('exam_how', []),
        'must': content.get('must', []),
        'advanced': content.get('advanced', []),
        'silgi': content.get('silgi',''),
    }
    return out

def derive_fields(lesson):
    """기존 rich 콘텐츠에서 R36 필드 파생 (전기기사·EC 복사분용)"""
    l = dict(lesson)
    l['formulas'] = norm_formulas(l.get('formulas'))
    # must: 공식 = 필수 암기 대상 (이름: 식)
    if not l.get('must'):
        must = []
        for f in l['formulas'][:6]:
            item = f"{f['name']}: {f['expr']}" if f['name'] else f['expr']
            if f.get('note'): item += f" ({f['note']})"
            must.append(item)
        # 공식이 없으면 암기법 상위 항목으로 대체
        if not must:
            must = list(l.get('mnemonics', [])[:4])
        l['must'] = must
    # exam_how: 합격 전략의 ①②③④ 분해 → 출제 패턴
    if not l.get('exam_how'):
        st = l.get('strategy','')
        parts = [p.strip() for p in re.split(r'[①②③④⑤]', st) if p.strip()]
        l['exam_how'] = parts[:4]
    l.setdefault('basic_explain','')
    l.setdefault('advanced', [])
    l.setdefault('silgi','')
    return l

# ── 전기기사 상위 빈출 토픽 기초설명(왕초보) 저술 ──
ELEC_BASIC = {
 ('전자기학','전계·전위'): "전하 주변에는 보이지 않는 '힘의 밭(전계)'이 펼쳐집니다. 전위는 그 밭에서의 높이 — 높은 곳(+)에서 낮은 곳(−)으로 전하가 굴러갑니다. 쿨롱의 법칙 F=QQ/4πεr²이 이 밭의 세기를 정하는 유일한 규칙입니다.",
 ('전자기학','정전용량·콘덴서'): "콘덴서는 전하를 담는 물통입니다. 판이 넓을수록(A), 간격이 좁을수록(d) 많이 담깁니다 — C=εA/d. 직렬은 물통을 세로로 쌓아 좁아지고(역수 합), 병렬은 옆으로 늘어놓아 커집니다(그냥 합).",
 ('전자기학','자계·자기력'): "전류가 흐르면 주변에 자기장 소용돌이가 생기고(암페어), 자기장 속 전류는 힘을 받습니다(F=BIl, 플레밍 왼손). 전동기가 도는 원리 전부가 이 두 문장입니다.",
 ('전자기학','전자유도·전자파'): "자석을 코일에 넣었다 빼면 전기가 생깁니다(패러데이). 유도전류는 변화를 방해하는 방향(렌츠) — e=−N(dΦ/dt)의 마이너스가 그 뜻입니다. 발전기의 원리 전부가 이 한 문장입니다.",
 ('전자기학','인덕턴스'): "코일은 전류 변화를 싫어하는 관성체이고, 그 관성의 크기가 인덕턴스 L입니다. L=NΦ/I, 축적 에너지 W=½LI² — 콘덴서(½CV²)와 쌍으로 기억하면 절반은 끝납니다.",
 ('전력공학','보호계전·차단기'): "고장 전류를 '알아채는 눈'이 계전기(릴레이), '끊는 손'이 차단기입니다. 차단기는 아크를 끄는 매질(기름·가스·진공·공기)로 종류가 나뉘고, 시험은 각 계전기가 어떤 고장에 반응하는지를 묻습니다.",
 ('전기기기','변압기'): "변압기는 '코일 감은 수의 비율로 전압을 바꾸는 기계'입니다. 철심에 자속이 지나가며 1차의 전기를 2차로 전달합니다. 전압은 권수에 비례, 전류는 반비례, 임피던스는 제곱 — 이 세 가지 비율이 시험의 전부입니다.",
 ('전기기기','동기기'): "동기기는 회전 자기장과 '정확히 같은 속도'로 도는 기계입니다. 발전소 발전기가 대부분 동기발전기입니다. 계자(자석)를 돌리고 전기자에서 전기를 꺼내는 회전계자형이 표준입니다.",
 ('전기기기','유도전동기'): "유도전동기는 '회전 자기장을 따라가되 살짝 늦게 도는' 기계입니다. 그 늦는 비율이 슬립(3~5%). 공장 전동기의 대부분이며, 시험은 동기속도 Ns=120f/P와 슬립 계산이 절반입니다.",
 ('전기기기','직류기'): "직류기는 계자(자석)+전기자(코일)+정류자(방향 전환 브러시)로 구성됩니다. E=V−IaRa(전동기 역기전력) 하나에서 속도·토크 공식이 모두 파생됩니다.",
 ('회로이론 및 제어공학','라플라스·전달함수'): "라플라스 변환은 미분방정식을 '나눗셈 문제'로 바꾸는 마법입니다. 미분은 s 곱하기, 적분은 s 나누기가 됩니다. 전달함수 G(s)=출력/입력은 시스템의 '성격표'입니다.",
 ('회로이론 및 제어공학','교류회로'): "교류 계산의 핵심은 '위상'입니다. 코일(L)은 전류를 늦추고, 콘덴서(C)는 앞당깁니다. 임피던스 Z=√(R²+(XL−XC)²) 직각삼각형 하나로 대부분의 계산이 끝납니다.",
 ('전기설비기술기준','가공전선로'): "전봇대 위 전선에 대한 안전 규칙입니다. '땅에서 몇 m 위에, 얼마나 튼튼하게(안전율), 서로 얼마나 떨어뜨려' 설치하는지 숫자를 정해 놓았고, 시험은 그 숫자를 묻습니다.",
 ('전기설비기술기준','접지시스템'): "접지는 '고장 전기를 땅으로 보내는 비상구'입니다. KEC 개정으로 1·2·3종 대신 계통접지(TN/TT/IT)와 보호접지로 재편되었습니다. 접지선 굵기와 공사방법 숫자가 출제 포인트입니다.",
 ('전력공학','배전'): "발전소→변전소는 송전, 변전소→집은 배전입니다. 배전 방식(방사상·루프·뱅킹·네트워크)별 장단점과 전압강하·손실 계산이 축입니다. 손실은 전류 제곱에 비례 — 전압을 올리면 손실이 급감하는 이유입니다.",
 ('회로이론 및 제어공학','블록선도·안정도'): "블록선도는 시스템을 상자와 화살표로 그린 지도입니다. 피드백 공식 G/(1+GH) 하나로 단순화하고, 안정도는 '특성방정식의 근이 전부 왼쪽(음의 실수부)에 있는가'로 판정합니다(루스 판별법).",
 ('전력공학','고장계산'): "고장계산은 '합선되면 전류가 얼마나 흐르나'를 %임피던스로 계산하는 것입니다. 단락전류 Is=100/%Z×In — %Z가 작을수록 대형 사고입니다. 차단기 용량 선정의 근거가 됩니다.",
}

def main():
    # 1) fire_electric
    path = 'backend/data/study/fire_electric/lessons.json'
    data = json.load(open(path))
    replaced = 0
    for i, l in enumerate(data):
        key = (l['subject'], l['topic'])
        if key in FE:
            data[i] = apply_dict(l, FE[key])
            replaced += 1
    json.dump(data, open(path,'w'), ensure_ascii=False, indent=1)
    print(f'fire_electric: {replaced}/{len(data)} replaced')

    # 2) electrician: R36 필드 파생 + 기초설명 저술
    epath = 'backend/data/study/electrician/lessons.json'
    elec = json.load(open(epath))
    for i, l in enumerate(elec):
        l = derive_fields(l)
        key = (l['subject'], l['topic'])
        if key in ELEC_BASIC:
            l['basic_explain'] = ELEC_BASIC[key]
        elec[i] = l
    json.dump(elec, open(epath,'w'), ensure_ascii=False, indent=1)
    basics = sum(1 for l in elec if l.get('basic_explain'))
    print(f'electrician: {len(elec)} derived, {basics} with basic_explain')

    # 3) elec_construction: EC 5개 + 전기기사 매칭 복사
    cpath = 'backend/data/study/elec_construction/lessons.json'
    ec = json.load(open(cpath))
    emap = {(l['subject'], l['topic']): l for l in elec}
    n_ec, n_copy = 0, 0
    for i, l in enumerate(ec):
        key = (l['subject'], l['topic'])
        if key in EC:
            ec[i] = apply_dict(l, EC[key]); n_ec += 1
        elif key in emap:
            src = copy.deepcopy(emap[key])
            # EC의 freq/importance 유지
            src['freq'] = l.get('freq', src.get('freq', 0))
            src['importance'] = l.get('importance', src.get('importance', 3))
            ec[i] = src; n_copy += 1
        else:
            ec[i] = derive_fields(l)
    json.dump(ec, open(cpath,'w'), ensure_ascii=False, indent=1)
    print(f'elec_construction: {n_ec} EC-authored, {n_copy} copied from electrician, total {len(ec)}')

    # 검증
    for p in ['backend/data/study/fire_electric/lessons.json', 'backend/data/study/electrician/lessons.json', 'backend/data/study/elec_construction/lessons.json']:
        d = json.load(open(p))
        bad_desc = sum(1 for l in d for f in l.get('formulas',[]) if 'desc' in f)
        n_must = sum(1 for l in d if l.get('must'))
        n_basic = sum(1 for l in d if l.get('basic_explain'))
        n_adv = sum(1 for l in d if l.get('advanced'))
        print(f'{p}: {len(d)} lessons | desc-remnant={bad_desc} | must={n_must} basic={n_basic} advanced={n_adv}')

if __name__ == '__main__':
    main()
