# -*- coding: utf-8 -*-
"""깨진(그림/수식 대체 텍스트) 문항을 원본 PDF에서 재추출해 exams.json에 병합.

전략:
- electrician: 라벨에 (MM.DD) 날짜가 있어 정확 매칭
- 나머지 트랙: PDF 파일명 날짜 내림차순 ↔ exam id 내림차순 순서 매칭
"""
import sys
import os
import re
import json
import glob

sys.path.insert(0, os.path.dirname(__file__))
from pdf_exam_parser import parse_exam_pdf  # noqa: E402

BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'backend', 'data', 'study')
DATE_RE = re.compile(r'(\d{8})')


def pdfs_desc(folder, name_substr):
    files = glob.glob(os.path.join(folder, f'*{name_substr}*교사용*.pdf'))
    dated = []
    for f in files:
        m = DATE_RE.search(os.path.basename(f))
        if m:
            dated.append((m.group(1), f))
    dated.sort(key=lambda x: x[0], reverse=True)
    return dated  # [(yyyymmdd, path), ...] desc


def is_broken(q):
    opts = q.get('options', [])
    return any(('그림' in o or '수식' in o or '원본' in o) for o in opts)


def build_id2pdf_by_date(exams, dated_pdfs):
    """라벨에 (MM.DD) 날짜가 있는 트랙(electrician) 전용: 정확 날짜 매칭."""
    id2pdf = {}
    date_map = {d: p for d, p in dated_pdfs}
    for e in exams:
        year = e.get('year')
        m = re.search(r'\((\d{2})\.(\d{2})\)', e.get('label', ''))
        if not m or not year:
            continue
        mmdd = m.group(1) + m.group(2)
        key = f'{year}{mmdd}'
        if key in date_map:
            id2pdf[e['id']] = date_map[key]
    return id2pdf


def build_id2pdf_positional(exams, dated_pdfs):
    """날짜 정보 없는 트랙: 최신순 정렬된 두 리스트를 순서대로 매칭."""
    id2pdf = {}
    for e, (d, p) in zip(exams, dated_pdfs):
        id2pdf[e['id']] = p
    return id2pdf


def build_id2pdf_by_year_session(exams, dated_pdfs):
    """연도별로 오름차순 정렬한 PDF 날짜를 회차(session) 순서에 매칭.
    (라벨에 날짜가 없는 트랙 중, PDF가 연도 내 일부 회차만 있는 경우 대응)
    """
    from collections import defaultdict
    by_year = defaultdict(list)
    for d, p in dated_pdfs:
        by_year[int(d[:4])].append((d, p))
    for y in by_year:
        by_year[y].sort()  # 오름차순 = 1회, 2회, 3회...
    id2pdf = {}
    for e in exams:
        y = e.get('year')
        s = e.get('session')
        sm = re.search(r'\d+', str(s)) if s is not None else None
        try:
            s_idx = int(sm.group()) - 1 if sm else int(str(s)) - 1
        except (TypeError, ValueError):
            continue
        lst = by_year.get(y, [])
        if 0 <= s_idx < len(lst):
            id2pdf[e['id']] = lst[s_idx][1]
    return id2pdf


def build_id2pdf_by_filename_id(exams, folder):
    """PDF 파일명이 이미 exam id(예: 2013_1.pdf)인 경우 직접 매칭."""
    id2pdf = {}
    for e in exams:
        p = os.path.join(folder, f"{e['id']}.pdf")
        if os.path.exists(p):
            id2pdf[e['id']] = p
    return id2pdf


def process_track(track, folder, name_substr, use_date_match, expected_max=100,
                   limit_ids=None, filename_is_id=False, use_year_session=False):
    exams_path = os.path.join(BASE, track, 'exams.json')
    exams = json.load(open(exams_path, encoding='utf-8'))
    img_dir = os.path.join(BASE, track, 'images')

    if filename_is_id:
        id2pdf = build_id2pdf_by_filename_id(exams, folder)
        if not id2pdf:
            print(f'[{track}] PDF 없음 — 스킵')
            return 0, 0
    else:
        dated_pdfs = pdfs_desc(folder, name_substr)
        if not dated_pdfs:
            print(f'[{track}] PDF 없음 — 스킵')
            return 0, 0
        if use_date_match:
            id2pdf = build_id2pdf_by_date(exams, dated_pdfs)
        elif use_year_session:
            id2pdf = build_id2pdf_by_year_session(exams, dated_pdfs)
        else:
            id2pdf = build_id2pdf_positional(exams, dated_pdfs)

    total_fixed = 0
    total_broken_before = 0
    cache = {}  # pdf_path -> parsed questions

    for e in exams:
        eid = e['id']
        broken_qs = [q for q in e['questions'] if is_broken(q)]
        total_broken_before += len(broken_qs)
        if not broken_qs:
            continue
        if limit_ids and eid not in limit_ids:
            continue
        pdf_path = id2pdf.get(eid)
        if not pdf_path:
            print(f'  [{track}/{eid}] PDF 매칭 실패 ({len(broken_qs)}건 미해결)')
            continue
        if pdf_path not in cache:
            qcount = e.get('question_count', expected_max) or expected_max
            try:
                cache[pdf_path] = parse_exam_pdf(
                    pdf_path, expected_max=qcount,
                    img_dir=img_dir, img_prefix=f'{eid}_')
            except Exception as ex:
                print(f'  [{track}/{eid}] 파싱 오류: {ex}')
                cache[pdf_path] = []
        parsed = {p['no']: p for p in cache[pdf_path]}

        fixed_here = 0
        for q in e['questions']:
            if not is_broken(q):
                continue
            p = parsed.get(q['no'])
            if not p or p['broken'] or not p['answer']:
                continue
            q['question'] = p['question'] or q['question']
            opts = p['options']
            # 보기가 순수 벡터 이미지(수식/회로도)로만 그려진 경우 텍스트가
            # 비어버릴 수 있음 → 이미지가 있으면 안내 문구로 채워 UI 공백 방지.
            if p['has_image'] and all(not o.strip() for o in opts):
                opts = [f'{n} (위 이미지 참고)' for n in ['①', '②', '③', '④']]
            q['options'] = opts
            q['answer'] = p['answer']
            q['has_image'] = p['has_image']
            if p['image']:
                q['image'] = f'images/{p["image"]}'
            elif 'image' in q:
                q.pop('image', None)
            q.pop('stem_recovered', None)
            if p['has_image']:
                q['explanation'] = (
                    (q.get('explanation') or '').split('⚠️ 원본 시험지에')[0].rstrip()
                    + '\n\n📷 원본 PDF의 그림/회로도를 문제 화면에서 바로 확인할 수 있습니다.'
                )
            fixed_here += 1
        if fixed_here:
            print(f'  [{track}/{eid}] {fixed_here}/{len(broken_qs)}건 복구')
        total_fixed += fixed_here

    json.dump(exams, open(exams_path, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=2)
    remain = total_broken_before - total_fixed
    print(f'[{track}] 총 {total_broken_before}건 중 {total_fixed}건 복구, {remain}건 잔존')
    return total_fixed, remain


if __name__ == '__main__':
    grand_fixed = 0
    grand_remain = 0

    jobs = [
        ('electrician', '/home/user/research/pdf', None, False, True),
        ('architecture', '/home/user/comcbt_extract/folder_06', '건축기사', False, False),
        ('construction_safety', '/home/user/comcbt_extract/folder_07', '건설안전기사', False, False),
        ('elec_industrial', '/home/user/comcbt_new/전기산업기사(jw)', '전기산업기사', False, False),
        ('fire_electric', '/home/user/comcbt_extract/folder_04', '소방설비기사(전기분야)', False, False),
        ('fire_mechanical', '/home/user/comcbt_extract/folder_05', '소방설비기사(기계분야)', False, False),
        ('industrial_safety', '/home/user/comcbt_extract/folder_03', '산업안전기사', False, False),
        ('info_processing', '/home/user/comcbt_extract/folder_01', '정보처리기사', False, False),
        ('elec_construction', '/home/user/comcbt_downloads/전기공사기사(ni)', '전기공사기사', False, False),
    ]

    only = sys.argv[1] if len(sys.argv) > 1 else None
    for track, folder, substr, use_date, fname_id in jobs:
        if only and track != only:
            continue
        use_ys = track == 'elec_construction'
        f, r = process_track(track, folder, substr, use_date,
                              filename_is_id=fname_id, use_year_session=use_ys)
        grand_fixed += f
        grand_remain += r

    print(f'\n=== 전체 합계: 복구 {grand_fixed}건 / 잔존 {grand_remain}건 ===')
