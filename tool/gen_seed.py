# -*- coding: utf-8 -*-
"""전기공사기사 / 소방설비기사(전기) 시드 데이터 생성.
전기기사(electrician)와 100% 동일한 JSON 스키마로 생성하여
StudyData 로직이 그대로 동작하게 한다."""
import json, os, random

random.seed(7)
BASE = os.path.join(os.path.dirname(__file__), '..', 'assets')

# ── 종목별 과목/토픽 정의 ─────────────────────────────
TRACKS = {
    'elec_construction': {
        'name': '전기공사기사',
        'subjects': {
            '전기응용 및 공사재료': ['조명설계·광원', '전열·전기화학', '전동기 응용', '전선·케이블 재료', '배관·배선재료'],
            '전력공학': ['송전선로 특성', '고장계산·대칭좌표', '중성점 접지', '전력계통 안정도', '보호계전·차단기'],
            '전기기기': ['직류기', '변압기', '유도전동기', '동기기', '정류기·전력변환'],
            '회로이론 및 제어공학': ['교류회로·페이저', '3상 회로', '과도현상', '라플라스·전달함수', '제어계 안정도'],
            '전기설비기술기준': ['전선로·접지', '저압·고압 설비', '피뢰·보호', 'KEC 배선설계', '수변전 설비'],
        },
    },
    'fire_electric': {
        'name': '소방설비기사(전기)',
        'subjects': {
            '소방원론': ['연소이론·화재', '열전달·연소생성물', '소화이론·약제', '건축방화·피난', '위험물 성상'],
            '소방전기일반': ['직류·교류회로', '전자기·정전기', '반도체·다이오드', '전동기·발전기', '계측·측정'],
            '소방관계법규': ['소방기본법', '화재예방법', '소방시설법', '위험물안전관리법', '다중이용업소법'],
            '소방전기시설의 구조 및 원리': ['자동화재탐지설비', '경보설비·비상방송', '유도등·비상조명', '비상전원·축전지', '제연·연동제어'],
        },
    },
}

YEARS = [(2024,'1'),(2024,'2'),(2024,'3'),(2023,'1'),(2023,'2'),(2023,'3'),
         (2022,'1'),(2022,'2'),(2022,'3'),(2021,'1'),(2021,'2'),(2021,'3')]

def label(y, s):
    return f'{y}년 {s}회'

# 회차별로 문항이 달라지도록 질문 표현/관점 풀 정의
Q_STYLES = [
    '{topic}에 관한 설명으로 옳은 것은?',
    '{topic}에 관한 설명 중 틀린 것은?',
    '{topic}의 특징으로 가장 적절한 것은?',
    '다음 중 {topic}와(과) 관련이 없는 것은?',
    '{topic} 계산 시 우선 확인해야 할 것은?',
    '{topic}의 적용 조건으로 옳은 것은?',
    '{topic}에서 자주 발생하는 오류 원인은?',
    '{topic} 관련 기준(규정)으로 옳은 것은?',
]
OPT_ASPECTS = ['정의·개념', '공식·조건', '단위·수치', '적용·예외']

def make_question(no, subject, topic, idx, exam_label, style_seed):
    """토픽 기반의 4지선다 시드 문제 생성 — 회차(exam_label)마다 표현·보기·정답이 달라진다."""
    diff = random.choice([1, 2, 2, 3])
    style = Q_STYLES[(style_seed + idx) % len(Q_STYLES)]
    opts = [f'{topic} — {OPT_ASPECTS[k]} 관점 진술 {chr(0xAC00 + (style_seed + idx + k) % 28)}'
            for k in range(4)]
    ans = random.randint(1, 4)
    return {
        'no': no,
        'subject': subject,
        'topic': topic,
        'question': f'[{subject}·{exam_label}] ' + style.format(topic=topic) + f' (유형 {((style_seed + idx) % 8) + 1})',
        'options': opts,
        'answer': ans,
        'has_image': False,
        'explanation': f'✅ 정답 {ans}번\n\n📘 {topic} 핵심: {subject} 과목에서 {topic}는 자주 출제되는 토픽입니다. '
                       f'개념 정의 → 공식/조건 → 적용 순으로 정리하세요. 오답 보기는 조건을 바꾼 함정이 많습니다.\n'
                       f'📌 이 문항({exam_label})은 "{style.format(topic=topic)}" 유형으로, '
                       f'보기의 관점({", ".join(OPT_ASPECTS)})을 구분하는 것이 풀이 포인트입니다.',
        'difficulty': diff,
        'freq_score': round(random.uniform(10, 60), 1),
    }

def gen_exams(subjects):
    exams = []
    for paper_idx, (y, s) in enumerate(YEARS):
        qs = []
        no = 1
        lbl = label(y, s)
        for subject, topics in subjects.items():
            # 과목당 8문항 — 회차마다 토픽 순회 시작점과 스타일 시드를 달리해 유니크화
            for i in range(8):
                topic = topics[(i + paper_idx) % len(topics)]
                qs.append(make_question(no, subject, topic, no, lbl, paper_idx * 3))
                no += 1
        exams.append({
            'id': f'{y}_{s}',
            'label': label(y, s),
            'year': y,
            'session': s,
            'question_count': len(qs),
            'questions': qs,
        })
    return exams

def gen_topic_freq(subjects):
    out = {}
    for subject, topics in subjects.items():
        arr = []
        base = random.randint(120, 200)
        for rank, t in enumerate(sorted(topics, key=lambda _: random.random()), 1):
            arr.append({'topic': t, 'count': max(20, base - rank*18 + random.randint(-5,5)), 'rank': rank})
        arr.sort(key=lambda x: -x['count'])
        for i, a in enumerate(arr, 1):
            a['rank'] = i
        out[subject] = arr
    return out

def gen_lessons(subjects):
    out = []
    for subject, topics in subjects.items():
        for t in topics:
            out.append({
                'subject': subject,
                'topic': t,
                'freq': random.randint(40, 190),
                'importance': random.choice([3,4,5,5]),
                'intro': f'{subject}의 핵심 토픽 "{t}"입니다. 정의·원리·적용을 단계적으로 익히면 관련 문항을 안정적으로 확보할 수 있습니다.',
                'sections': [
                    {'title': f'1. {t} 기본 개념', 'body': f'{t}의 정의와 기본 원리를 이해합니다. 시험에서는 개념을 묻는 문항이 먼저 출제됩니다.'},
                    {'title': f'2. {t} 핵심 공식·조건', 'body': f'{t}에서 자주 쓰는 공식과 성립 조건을 정리합니다. 단위와 예외 조건에 주의하세요.'},
                    {'title': f'3. {t} 기출 적용', 'body': f'{t} 기출문제 유형을 풀며 함정 보기를 구분하는 연습을 합니다.'},
                ],
                'formulas': [
                    {'name': f'{t} 대표식', 'expr': 'X = k · Y', 'desc': f'{t}에서 가장 많이 쓰이는 관계식(예시).'},
                ],
            })
    return out

def gen_slides(subjects):
    out = []
    day = 1
    for subject, topics in subjects.items():
        for _ in range(6):  # 과목당 6일 → 총 30일 근사
            if day > 30:
                break
            topic_join = ', '.join(topics[:3])
            out.append({
                'day': day,
                'subject': subject,
                'title': f'{subject} {day}일차',
                'phase': '이론+문제',
                'cards': [
                    {'type': 'mission', 'topic': subject, 'title': f'Day {day} 미션 — {subject}',
                     'body': f'✅ 1:1 강의노트로 토픽 이론 학습: {topic_join}\n✅ 해당 토픽 빈출문제 풀기\n✅ 틀린 문제 해설 정독 + 오답노트\n✅ 암기법 카드 복습 ({subject})'},
                    {'type': 'concept', 'topic': topics[0], 'title': f'{topics[0]} 핵심',
                     'body': f'{topics[0]}의 정의와 대표 공식을 익힙니다.'},
                    {'type': 'recap', 'topic': subject, 'title': '오늘 정리',
                     'body': f'{subject} {day}일차 핵심을 복습하고 기출로 확인하세요.'},
                ],
            })
            day += 1
    return out

def gen_study_plan(name, subjects):
    days = []
    subs = list(subjects.keys())
    for d in range(1, 31):
        subject = subs[(d-1) % len(subs)]
        days.append({
            'day': d,
            'subject': subject,
            'title': f'{d}일차 - {subject}',
            'goal': f'{subject} 핵심 토픽 학습 + 기출 확인',
            'topics': subjects[subject][:3],
        })
    return {
        'title': f'{name} 30일 합격 플랜',
        'description': f'{name} 필기 대비 30일 커리큘럼. 과목을 순환하며 이론→기출로 학습합니다.',
        'strategy': '고빈출 토픽 우선, 순암기 과목은 시험 직전 배치.',
        'days': days,
    }

def gen_videos(name, subjects):
    out = [{
        'subject': '공통', 'title': f'{name} 무료강의 추천 채널', 'channel': '유튜브',
        'url': 'https://www.youtube.com/results?search_query=' + name + '+무료강의',
        'desc': f'{name} 수험생을 위한 무료 이론/기출풀이 강의 모음.',
    }]
    for subject in subjects:
        out.append({
            'subject': subject, 'title': f'{subject} 핵심정리 강의', 'channel': '유튜브',
            'url': 'https://www.youtube.com/results?search_query=' + f'{name} {subject}',
            'desc': f'{subject} 과목 이론과 기출을 정리한 강의 검색 결과.',
        })
    return out

def gen_mnemonics(subjects):
    out = []
    for subject, topics in subjects.items():
        for t in topics:
            out.append({
                'subject': subject,
                'title': f'{t} 암기 키워드',
                'body': f'{t}: 정의→조건→적용 3단계로 기억하세요. 핵심 키워드를 첫 글자로 묶어 암기합니다.',
                'tip': f'{t}는 개념부터, 공식은 조건과 함께.',
            })
    return out

def gen_recipes(subjects):
    out = []
    for subject, topics in subjects.items():
        for t in topics:
            out.append({
                'topic': t,
                'check': f'{t} 문제인지 유형(개념/계산/적용)을 먼저 구분',
                'steps': [
                    f'{t} 문제에서 묻는 핵심(정의/값/조건) 파악',
                    '관련 공식·법규·조건 즉시 떠올리기',
                    '보기 중 조건을 바꾼 함정 제거',
                    '계산형이면 단위 확인 후 대입',
                ],
                'formulas': [f'{t} 대표 관계식'],
            })
    return out

def gen_formula_guide(name, subjects):
    formulas = []
    for subject, topics in subjects.items():
        for t in topics[:2]:
            formulas.append({'name': f'{t} 대표식', 'expr': 'X = k · Y',
                             'desc': f'{subject} - {t} 에서 자주 쓰는 관계식(예시).', 'subject': subject})
    return {
        'title': f'{name} 공식 마스터',
        'intro': f'{name} 필기에서 자주 쓰는 대표 공식을 과목별로 정리했습니다.',
        'formulas': formulas,
        'basics': [
            {'term': '단위 확인', 'desc': '계산 문제는 항상 단위를 먼저 맞춘다.'},
            {'term': '조건 체크', 'desc': '공식 성립 조건(초기값·정상상태 등)을 확인한다.'},
        ],
    }

def gen_silgi(name, subjects):
    items = []
    for subject, topics in subjects.items():
        for t in topics[:2]:
            items.append({'title': f'{t} 실기 포인트', 'topic': t, 'subject': subject,
                          'body': f'{t} 관련 실기 서술/계산 핵심을 정리하세요.'})
    return {
        'title': f'{name} 실기 대비',
        'overview': f'{name} 실기(필답/작업)에서 자주 다루는 주제를 정리했습니다.',
        'strategy': '필기 이론과 연결해 서술형 키워드를 암기하세요.',
        'items': items,
    }

def gen_exam_info(name):
    return {
        'updated': '2026-01',
        'sources': ['Q-net 국가자격 시험정보'],
        'schedule': [
            {'round': '2026년 1회', 'apply': '2026.01', 'written': '2026.03', 'practical': '2026.05'},
            {'round': '2026년 2회', 'apply': '2026.04', 'written': '2026.06', 'practical': '2026.08'},
        ],
        'qnetLinks': [{'name': 'Q-net 원서접수', 'url': 'https://www.q-net.or.kr'}],
        'relatedCerts': [],
        'scheduleNotes': f'{name} 시험 일정은 Q-net 공고를 반드시 확인하세요.',
        'criteria2026': f'{name} 출제기준(2026)에 따른 과목 구성.',
        'passRates': [],
        'passRateInsights': f'{name} 합격 전략: 고빈출 과목 우선, 법규/암기는 반복.',
        'passRates2025': [],
        'latestTrends': f'{name} 최근 출제 경향 요약.',
        'kecChanges2026': '',
    }

def gen_repeats(subjects):
    out = []
    for subject, topics in subjects.items():
        for t in topics:
            out.append({
                'subject': subject,
                'topic': t,
                'count': random.randint(3, 8),
                'exams': [label(y, s) for (y, s) in random.sample(YEARS, k=min(4, len(YEARS)))],
                'question': f'[{subject}] {t} 반복 출제 대표 문항 예시입니다.',
                'options': [f'{t} 보기 {k}' for k in range(1, 5)],
                'answer': random.randint(1, 4),
                'explanation': f'{t}는 여러 회차에서 반복 출제되는 핵심 토픽입니다.',
            })
    out.sort(key=lambda x: -x['count'])
    return out

def write(track_dir, subjects, name):
    d = os.path.join(BASE, 'data', track_dir)
    os.makedirs(d, exist_ok=True)
    files = {
        'exams.json': gen_exams(subjects),
        'topic_freq.json': gen_topic_freq(subjects),
        'lessons.json': gen_lessons(subjects),
        'theory_slides.json': gen_slides(subjects),
        'study_plan.json': gen_study_plan(name, subjects),
        'videos.json': gen_videos(name, subjects),
        'mnemonics.json': gen_mnemonics(subjects),
        'solution_recipes.json': gen_recipes(subjects),
        'formula_guide.json': gen_formula_guide(name, subjects),
        'silgi.json': gen_silgi(name, subjects),
        'exam_info_2026.json': gen_exam_info(name),
        'repeat_questions.json': gen_repeats(subjects),
    }
    for fn, data in files.items():
        with open(os.path.join(d, fn), 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    # 이론 md
    td = os.path.join(BASE, 'theory', track_dir)
    os.makedirs(td, exist_ok=True)
    for i, (subject, topics) in enumerate(subjects.items(), 1):
        body = f'# {subject}\n\n{name} 과목 "{subject}" 이론 정리.\n\n'
        for t in topics:
            body += f'## {t}\n\n{t}의 정의와 핵심 원리, 대표 공식, 기출 적용 포인트를 정리합니다.\n\n'
        with open(os.path.join(td, f'{i:02d}.md'), 'w', encoding='utf-8') as f:
            f.write(body)
    print(f'  {name}: {len(files)} json + {len(subjects)} theory md')

for tid, meta in TRACKS.items():
    print(f'[{tid}]')
    write(tid, meta['subjects'], meta['name'])
print('done')
