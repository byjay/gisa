# -*- coding: utf-8 -*-
"""comcbt 교사용+해설집 PDF 배치 → 트랙별 exams.json 빌더.

사용: python3 tool/build_track_db.py <track_id> [track_id...]
      python3 tool/build_track_db.py --all
"""
import sys
import os
import re
import json
import glob
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pdf_exam_parser import parse_exam_pdf  # noqa: E402
from expl_parser import extract_explanations  # noqa: E402
from topic_rules import classify_topic, difficulty_raw  # noqa: E402

EXTRACT = '/home/user/comcbt_extract'
OUT_BASE = 'assets/data'

# 트랙 정의: 폴더(우선순위순), 문항수, 파일명 매칭 키워드
TRACKS = {
    'fire_electric': {
        'name': '소방설비기사(전기)', 'folders': ['folder_00', 'folder_04'],
        'max': 80, 'key': '소방설비기사(전기분야)',
        'subject_alias': {'소방전기회로': '소방전기일반'},
    },
    'info_processing': {
        'name': '정보처리기사', 'folders': ['folder_01'],
        'max': 100, 'key': '정보처리기사',
        # 2020년 NCS 개편으로 과목 체계 전면 교체 → 개편 이후만 사용
        'min_year': 2020,
    },
    'industrial_safety': {
        'name': '산업안전기사', 'folders': ['folder_08', 'folder_03'],
        'max': 120, 'key': '산업안전기사',
    },
    'fire_mechanical': {
        'name': '소방설비기사(기계)', 'folders': ['folder_05'],
        'max': 80, 'key': '소방설비기사(기계분야)',
    },
    'architecture': {
        'name': '건축기사', 'folders': ['folder_06'],
        'max': 100, 'key': '건축기사',
    },
    'construction_safety': {
        'name': '건설안전기사', 'folders': ['folder_07'],
        'max': 120, 'key': '건설안전기사',
    },
    'elec_industrial': {
        'name': '전기산업기사', 'folders': ['new_jw'],
        'max': 100, 'key': '전기산업기사',
        'subject_alias': {'전기설비기술기준 및 판단 기준': '전기설비기술기준'},
    },
    'hazmat_industrial': {
        'name': '위험물산업기사', 'folders': ['new_ng'],
        'max': 60, 'key': '위험물산업기사',
    },
}

# 추가 PDF 소스 디렉토리 매핑 (comcbt_extract 외부)
EXTRA_DIRS = {
    'new_jw': '/home/user/comcbt_new/전기산업기사(jw)',
    'new_ng': '/home/user/comcbt_new/위험물산업기사(ng)',
}

DATE_RE = re.compile(r'(\d{8})')


def collect_pdfs(cfg, kind):
    """kind: 교사용|해설집 → {date: path} (폴더 우선순위 앞쪽 우선)"""
    out = {}
    for folder in cfg['folders']:
        base_dir = EXTRA_DIRS.get(folder, f"{EXTRACT}/{folder}")
        for fp in sorted(glob.glob(f"{base_dir}/*{kind}*.pdf")):
            base = os.path.basename(fp)
            if cfg['key'] not in base:
                continue
            m = DATE_RE.search(base)
            if not m:
                continue
            out.setdefault(m.group(1), fp)
    return out


def fallback_expl(answer):
    return (f'✅ 정답 {answer}번\n\n'
            '📘 해설: 이 회차는 공식 해설이 아직 등록되지 않았습니다. '
            '정답 보기를 기준으로 관련 개념을 이론 탭에서 복습하세요. '
            '오답 시 자동으로 복습 큐에 추가됩니다.')


def clean_expl(text, answer):
    text = text.strip()
    head = f'✅ 정답 {answer}번'
    if not text:
        return fallback_expl(answer)
    return f'{head}\n\n📘 해설: {text}'


def build_track(track_id):
    cfg = TRACKS[track_id]
    teachers = collect_pdfs(cfg, '교사용')
    expls = collect_pdfs(cfg, '해설집')
    print(f"\n=== {cfg['name']} ({track_id}): 교사용 {len(teachers)}회차, "
          f"해설집 {len(expls)}회차 ===")

    min_year = cfg.get('min_year', 0)
    teachers = {d: p for d, p in teachers.items() if int(d[:4]) >= min_year}

    # 연도별 회차 번호 부여 (같은 해 날짜순 1,2,3회)
    dates = sorted(teachers.keys(), reverse=True)
    sess_no = {}
    per_year = {}
    for d in sorted(teachers.keys()):
        y = d[:4]
        per_year.setdefault(y, []).append(d)
    for y, ds in per_year.items():
        for i, d in enumerate(ds, 1):
            sess_no[d] = i

    exams = []
    total_q = dropped = expl_real = 0
    for d in dates:
        qs = parse_exam_pdf(teachers[d], expected_max=cfg['max'])
        ex_map = extract_explanations(expls[d], cfg['max']) if d in expls else {}
        questions = []
        for q in qs:
            if (q['broken'] or q['answer'] < 1 or len(q['options']) != 4
                    or any(not o for o in q['options'])):
                dropped += 1
                continue
            raw_e = ex_map.get(q['no'], '')
            if raw_e:
                expl_real += 1
            subj = q['subject'] or '기타'
            subj = cfg.get('subject_alias', {}).get(subj, subj)
            full_text = q['question'] + ' ' + ' '.join(q['options'])
            questions.append({
                'no': q['no'],
                'subject': subj,
                'topic': classify_topic(track_id, subj, full_text),
                'question': q['question'],
                'options': q['options'],
                'answer': q['answer'],
                'has_image': q['has_image'],
                'explanation': clean_expl(raw_e, q['answer'])
                               if raw_e else fallback_expl(q['answer']),
                'difficulty': 2,  # 분위수 후처리에서 재배정
                '_draw': difficulty_raw(
                    q['question'], q['options'], q['has_image']),
                'freq_score': 0.0,
            })
        if len(questions) < cfg['max'] * 0.5:
            print(f"  ⚠️ {d}: 유효 {len(questions)}문항 — 회차 제외")
            continue
        year = int(d[:4])
        exams.append({
            'id': f'{year}_{sess_no[d]}',
            'label': f'{year}년 {sess_no[d]}회',
            'year': year,
            'session': f'{sess_no[d]}회',
            'question_count': len(questions),
            'questions': questions,
        })
        total_q += len(questions)
        print(f"  {d} → {year}년 {sess_no[d]}회: {len(questions)}문항 "
              f"(해설집 {'O' if d in expls else 'X'})")

    # freq_score: 토픽 빈도 기반 0~100 점수 부여 (전기기사 방식)
    cnt = Counter()
    for e in exams:
        for q in e['questions']:
            cnt[q['topic']] += 1
    if cnt:
        mx = max(cnt.values())
        for e in exams:
            for q in e['questions']:
                q['freq_score'] = round(10 + 90 * cnt[q['topic']] / mx, 1)

    # 난이도: 분위수 배정 (전기기사 분포 37% 하 / 28% 중 / 34% 상 매칭)
    all_q = [q for e in exams for q in e['questions']]
    if all_q:
        raws = sorted(q['_draw'] for q in all_q)
        n = len(raws)
        t1 = raws[min(int(n * 0.37), n - 1)]
        t2 = raws[min(int(n * 0.65), n - 1)]
        for q in all_q:
            q['difficulty'] = 1 if q['_draw'] <= t1 else (
                2 if q['_draw'] <= t2 else 3)
            del q['_draw']

    out_dir = f'{OUT_BASE}/{track_id}'
    os.makedirs(out_dir, exist_ok=True)
    with open(f'{out_dir}/exams.json', 'w', encoding='utf-8') as f:
        json.dump(exams, f, ensure_ascii=False)

    freq = [{'topic': t, 'count': c, 'rank': i + 1}
            for i, (t, c) in enumerate(cnt.most_common())]
    with open(f'{out_dir}/topic_freq.json', 'w', encoding='utf-8') as f:
        json.dump(freq, f, ensure_ascii=False)

    print(f"  ✅ {len(exams)}회차 {total_q}문항 저장 "
          f"(실해설 {expl_real}, 제외 {dropped}) → {out_dir}/exams.json")
    return {'track': track_id, 'sessions': len(exams), 'questions': total_q,
            'real_expl': expl_real, 'dropped': dropped}


if __name__ == '__main__':
    args = sys.argv[1:]
    ids = list(TRACKS) if '--all' in args else args
    summary = [build_track(t) for t in ids]
    print('\n===== 요약 =====')
    for s in summary:
        print(f"{s['track']}: {s['sessions']}회차 {s['questions']}문항 "
              f"(실해설 {s['real_expl']})")
