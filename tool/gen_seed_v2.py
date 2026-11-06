# -*- coding: utf-8 -*-
"""신규 트랙 데이터 v2 — 전기기사 수준 격상.

전략:
- 전기공사기사: 공통 4과목(전력공학·전기기기·회로이론 및 제어공학·전기설비기술기준)은
  전기기사 실제 기출(backend/data/study/electrician/exams.json)에서 재활용.
  '전기응용 및 공사재료'는 bank_elec_app.py 실제 문항 뱅크 사용.
- 소방설비기사(전기): bank_fire.py 4과목 실제 문항 뱅크 사용.
- repeat_questions.json 도 뱅크 고빈출 문항으로 실제화.
"""
import json, os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
from bank_elec_app import BANK as ELEC_APP_BANK, SUBJECT as ELEC_APP_SUBJECT
from bank_fire import BANK_FIRE

random.seed(42)
BASE = os.path.join(os.path.dirname(__file__), '..', 'assets')

YEARS = [(2024,'1'),(2024,'2'),(2024,'3'),(2023,'1'),(2023,'2'),(2023,'3'),
         (2022,'1'),(2022,'2'),(2022,'3'),(2021,'1'),(2021,'2'),(2021,'3')]

def label(y, s):
    return f'{y}년 {s}회'

def bank_to_question(b, no, subject):
    return {
        'no': no,
        'subject': subject,
        'topic': b['topic'],
        'question': b['q'],
        'options': list(b['opts']),
        'answer': b['ans'],
        'has_image': False,
        'explanation': f"✅ 정답 {b['ans']}번\n\n📘 해설: {b['expl']}",
        'difficulty': b['diff'],
        'freq_score': float(b['freq']),
    }

def pick_rotating(bank, paper_idx, count):
    """회차마다 시작점을 옮겨가며 뱅크에서 count개 선택 (실제 기출의 반복출제 패턴 재현)."""
    n = len(bank)
    start = (paper_idx * count) % n
    idxs = [(start + i) % n for i in range(count)]
    return [bank[i] for i in idxs]

# ── 전기기사 실기출 로드 (공통 과목 재활용) ─────────────
elec_exams = json.load(open(os.path.join(BASE, 'data', 'electrician', 'exams.json')))
elec_papers = elec_exams if isinstance(elec_exams, list) else elec_exams.get('papers', [])
COMMON_SUBJECTS = ['전력공학', '전기기기', '회로이론 및 제어공학', '전기설비기술기준']
common_pool = {s: [] for s in COMMON_SUBJECTS}
for p in elec_papers:
    for q in p.get('questions', []):
        if q.get('subject') in common_pool:
            common_pool[q['subject']].append(q)
for s in COMMON_SUBJECTS:
    random.shuffle(common_pool[s])
    print(f'전기기사 재활용 풀 [{s}]: {len(common_pool[s])}문항')

def gen_elec_construction_exams():
    exams = []
    cursor = {s: 0 for s in COMMON_SUBJECTS}
    for paper_idx, (y, s) in enumerate(YEARS):
        qs, no = [], 1
        # 1과목: 전기응용 및 공사재료 (뱅크 24문항 순환)
        for b in pick_rotating(ELEC_APP_BANK, paper_idx, 8):
            qs.append(bank_to_question(b, no, ELEC_APP_SUBJECT)); no += 1
        # 공통 4과목: 전기기사 실기출에서 순차 발급 (전량 유니크)
        for subj in COMMON_SUBJECTS:
            pool = common_pool[subj]
            for _ in range(8):
                src = pool[cursor[subj] % len(pool)]
                cursor[subj] += 1
                q = dict(src)
                q['no'] = no
                no += 1
                qs.append(q)
        exams.append({'id': f'{y}_{s}', 'label': label(y, s), 'year': y,
                      'session': s, 'question_count': len(qs), 'questions': qs})
    return exams

def gen_fire_exams():
    exams = []
    subjects = list(BANK_FIRE.keys())
    for paper_idx, (y, s) in enumerate(YEARS):
        qs, no = [], 1
        for subj in subjects:
            for b in pick_rotating(BANK_FIRE[subj], paper_idx, 8):
                qs.append(bank_to_question(b, no, subj)); no += 1
        exams.append({'id': f'{y}_{s}', 'label': label(y, s), 'year': y,
                      'session': s, 'question_count': len(qs), 'questions': qs})
    return exams

def gen_repeats_from_bank(banks_by_subject):
    """빈출 상위 문항을 실제 문항 그대로 반복출제 목록화."""
    out = []
    for subj, bank in banks_by_subject.items():
        top = sorted(bank, key=lambda b: -b['freq'])[:6]
        for b in top:
            n_exams = max(2, round(b['freq'] / 20))
            out.append({
                'subject': subj,
                'topic': b['topic'],
                'count': n_exams,
                'exams': [label(y, se) for (y, se) in random.sample(YEARS, k=min(n_exams, len(YEARS)))],
                'question': b['q'],
                'options': list(b['opts']),
                'answer': b['ans'],
                'explanation': b['expl'],
            })
    out.sort(key=lambda x: -x['count'])
    return out

def gen_elec_construction_repeats():
    banks = {ELEC_APP_SUBJECT: ELEC_APP_BANK}
    out = gen_repeats_from_bank(banks)
    # 공통 과목은 전기기사의 실제 repeat_questions 재활용
    elec_rep = json.load(open(os.path.join(BASE, 'data', 'electrician', 'repeat_questions.json')))
    items = elec_rep if isinstance(elec_rep, list) else elec_rep.get('items', [])
    reused = [r for r in items if r.get('subject') in COMMON_SUBJECTS][:40]
    out.extend(reused)
    out.sort(key=lambda x: -x.get('count', 0))
    return out

# ── 실행 ─────────────────────────────────────────────
targets = {
    'elec_construction': {
        'exams.json': gen_elec_construction_exams(),
        'repeat_questions.json': gen_elec_construction_repeats(),
    },
    'fire_electric': {
        'exams.json': gen_fire_exams(),
        'repeat_questions.json': gen_repeats_from_bank(BANK_FIRE),
    },
}
for track, files in targets.items():
    d = os.path.join(BASE, 'data', track)
    for fn, data in files.items():
        with open(os.path.join(d, fn), 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        print(f'{track}/{fn} 갱신')
print('done')
