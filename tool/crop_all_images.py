# -*- coding: utf-8 -*-
"""fix_broken_questions.py는 '깨진' 문항이 있는 회차의 PDF만 파싱했기 때문에,
정상 텍스트가 있으면서도 그림/회로도가 포함된 문항(has_image=True)은 다수의 회차에서
이미지 크롭이 누락되었다. 이 스크립트는 각 트랙의 "모든" 회차에 대해 PDF를 파싱하여
has_image=True인 문항 전부에 이미지를 크롭하고 image 필드를 채운다.

기존 fix_broken_questions.py의 PDF 매칭 로직(id2pdf 빌더)을 그대로 재사용한다.
"""
import sys
import os
import json

sys.path.insert(0, os.path.dirname(__file__))
from pdf_exam_parser import parse_exam_pdf  # noqa: E402
from fix_broken_questions import (  # noqa: E402
    BASE, pdfs_desc,
    build_id2pdf_by_date, build_id2pdf_positional,
    build_id2pdf_by_year_session, build_id2pdf_by_filename_id,
)


TRACK_PAPER_SIZE = {
    'electrician': 100,
    'elec_construction': 40,
    'fire_electric': 80,
    'fire_mechanical': 80,
    'info_processing': 100,
    'industrial_safety': 120,
    'architecture': 100,
    'construction_safety': 120,
    'elec_industrial': 100,
    'hazmat_industrial': 60,
}


def process_track(track, folder, name_substr, use_date_match, expected_max=100,
                   filename_is_id=False, use_year_session=False):
    exams_path = os.path.join(BASE, track, 'exams.json')
    exams = json.load(open(exams_path, encoding='utf-8'))
    img_dir = os.path.join(BASE, track, 'images')
    os.makedirs(img_dir, exist_ok=True)

    if filename_is_id:
        id2pdf = build_id2pdf_by_filename_id(exams, folder)
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

    if not id2pdf:
        print(f'[{track}] PDF 매칭 결과 없음 — 스킵')
        return 0, 0

    total_filled = 0
    total_needed = 0
    cache = {}

    for e in exams:
        eid = e['id']
        needed = [q for q in e['questions']
                  if q.get('has_image') and not q.get('image')]
        total_needed += len(needed)
        if not needed:
            continue
        pdf_path = id2pdf.get(eid)
        if not pdf_path:
            print(f'  [{track}/{eid}] PDF 매칭 실패 ({len(needed)}건 미해결)')
            continue
        if pdf_path not in cache:
            # question_count 필드는 과거 파싱 실패로 실제보다 적게 기록된 경우가
            # 있어(누락 문항 존재) 그대로 쓰면 expected_max가 낮아져 뒷번호 문항이
            # 통째로 스킵됨 → 트랙별 고정 회차당 문항수(paperSize) 기준으로 상향 보정.
            max_no = max((q['no'] for q in e['questions']), default=0)
            paper_size = TRACK_PAPER_SIZE.get(track, expected_max)
            qcount = max(e.get('question_count') or 0, max_no, paper_size)
            try:
                cache[pdf_path] = parse_exam_pdf(
                    pdf_path, expected_max=qcount,
                    img_dir=img_dir, img_prefix=f'{eid}_')
            except Exception as ex:
                print(f'  [{track}/{eid}] 파싱 오류: {ex}')
                cache[pdf_path] = []
        parsed = {p['no']: p for p in cache[pdf_path]}

        filled_here = 0
        for q in needed:
            p = parsed.get(q['no'])
            if not p:
                continue
            if p['image']:
                q['image'] = f'images/{p["image"]}'
                filled_here += 1
            elif p['has_image']:
                # parser detected image but crop failed for some reason
                continue
        if filled_here:
            print(f'  [{track}/{eid}] {filled_here}/{len(needed)}건 이미지 연결')
        total_filled += filled_here

    json.dump(exams, open(exams_path, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=2)
    remain = total_needed - total_filled
    print(f'[{track}] 총 {total_needed}건 중 {total_filled}건 연결, {remain}건 잔존')
    return total_filled, remain


if __name__ == '__main__':
    grand_filled = 0
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
        ('hazmat_industrial', '/home/user/comcbt_new/위험물산업기사(ng)', '위험물산업기사', False, False),
    ]

    only = sys.argv[1] if len(sys.argv) > 1 else None
    for track, folder, substr, use_date, fname_id in jobs:
        if only and track != only:
            continue
        use_ys = track in ('elec_construction', 'hazmat_industrial')
        f, r = process_track(track, folder, substr, use_date,
                              filename_is_id=fname_id, use_year_session=use_ys)
        grand_filled += f
        grand_remain += r

    print(f'\n=== 전체 합계: 연결 {grand_filled}건 / 잔존 {grand_remain}건 ===')
