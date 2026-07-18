# -*- coding: utf-8 -*-
"""comcbt 교사용 PDF → 문제 DB 범용 파서
- 2단 컬럼 레이아웃 (좌→우 읽기 순서)
- 정답 마커: ❶❷❸❹ (교사용), 일반 보기: ①②③④
- 과목 헤더: 'N과목 : 과목명'
- 그림 문항 감지 + 문항 영역 크롭 PNG 저장 (has_image 대체용)
사용:
    from pdf_exam_parser import parse_exam_pdf
    qs = parse_exam_pdf('전기기사20220424(교사용).pdf', expected_max=100)
"""
import fitz
import re
import os
import io

CIRCLED = {'①': 1, '②': 2, '③': 3, '④': 4}
FILLED = {'❶': 1, '❷': 2, '❸': 3, '❹': 4}
ALLMARK = {**CIRCLED, **FILLED}

HEADER_Y = 45
FOOTER_Y = 800

SUBJ_RE = re.compile(r'^\s*(\d)\s*과목\s*[:：]\s*(.+?)\s*$')
QNUM_RE = re.compile(r'^\s*(\d{1,3})\.\s?')


def extract_lines(doc):
    """페이지→좌/우 컬럼 순으로 정렬된 라인 목록."""
    lines = []
    for pno, page in enumerate(doc):
        mid = page.rect.width / 2
        d = page.get_text('dict')
        for block in d['blocks']:
            if block['type'] != 0:
                continue
            for ln in block['lines']:
                x0, y0, x1, y1 = ln['bbox']
                if y1 < HEADER_Y or y0 > FOOTER_Y:
                    continue
                text = ''.join(s['text'] for s in ln['spans'])
                st = text.strip()
                if not st:
                    continue
                if ('comcbt.com' in st or '전자문제집 CBT' in st
                        or st.startswith('◐') or '기출문제 ◑' in st):
                    continue
                col = 0 if x0 < mid else 1
                lines.append({'text': text, 'page': pno, 'col': col,
                              'y0': y0, 'y1': y1, 'x0': x0, 'x1': x1})
    lines.sort(key=lambda l: (l['page'], l['col'], round(l['y0'], 1), l['x0']))
    return lines


def parse_question_blocks(doc, expected_max=100):
    """문항 번호 기준으로 라인들을 그룹핑. 과목 헤더 위치도 수집."""
    lines = extract_lines(doc)
    questions = []
    subj_marks = []  # (등장 시점의 문항 수, 과목명)
    cur = None
    expected = 1
    for ln in lines:
        st = ln['text'].strip()
        m = SUBJ_RE.match(st)
        if m:
            subj_marks.append((len(questions) + (1 if cur else 0), m.group(2).strip()))
            continue
        qm = QNUM_RE.match(ln['text'])
        if qm and int(qm.group(1)) == expected and expected <= expected_max:
            if cur:
                questions.append(cur)
            cur = {'no': expected, 'lines': [ln],
                   'first': (ln['page'], ln['col'], ln['y0'])}
            expected += 1
            continue
        if cur:
            cur['lines'].append(ln)
    if cur:
        questions.append(cur)
    return questions, subj_marks


def build_raw_text(q):
    """comcbt PDF는 단어 중간 wrap 시 공백 없음 → 그대로 이어붙임."""
    return ''.join(ln['text'].replace('\xa0', ' ') for ln in q['lines'])


def clean_text(s):
    s = s.replace('\xa0', ' ')
    s = re.sub(r'[ \t]+', ' ', s)
    return s.strip()


def split_stem_options(raw):
    """지문/보기 4개/정답(❶기반) 분리. 마커 4개 미만이면 broken=True.

    보기가 2×2 그리드로 배치되면 텍스트상 ②①③④처럼 순서가 뒤집힐 수 있어
    마커 위치를 순서 무관하게 전부 찾은 뒤 옵션 번호별로 재배열한다.
    """
    raw = QNUM_RE.sub('', raw, count=1)
    found = {}  # optno -> (pos, filled)
    for ch, n in ALLMARK.items():
        p = raw.find(ch)
        if p != -1 and (n not in found or p < found[n][0]):
            found[n] = (p, ch in FILLED)
    if len(found) < 4:
        return clean_text(raw), [], 0, True
    # 텍스트 위치순 정렬 → 각 마커의 본문은 다음 마커 직전까지
    order = sorted(found.items(), key=lambda kv: kv[1][0])  # [(optno,(pos,filled))...]
    stem = clean_text(raw[:order[0][1][0]])
    texts = {}
    answer = 0
    for i, (optno, (p, filled)) in enumerate(order):
        end = order[i + 1][1][0] if i + 1 < len(order) else len(raw)
        texts[optno] = clean_text(raw[p + 1:end])
        if filled:
            answer = optno
    options = [texts[n] for n in (1, 2, 3, 4)]
    return stem, options, answer, False


def question_segments(q, next_q):
    """문항이 차지하는 (page, col, y0, y1) 세그먼트. 마지막은 다음 문항 직전까지 확장."""
    segs = {}
    for ln in q['lines']:
        key = (ln['page'], ln['col'])
        if key not in segs:
            segs[key] = [ln['y0'], ln['y1']]
        else:
            segs[key][0] = min(segs[key][0], ln['y0'])
            segs[key][1] = max(segs[key][1], ln['y1'])
    last_key = max(segs.keys())
    if next_q:
        nk = (next_q['first'][0], next_q['first'][1])
        if nk == last_key:
            segs[last_key][1] = max(segs[last_key][1], next_q['first'][2] - 4)
        elif last_key < nk:
            segs[last_key][1] = FOOTER_Y
    else:
        segs[last_key][1] = min(segs[last_key][1] + 60, FOOTER_Y)
    return [(p, c, v[0], v[1]) for (p, c), v in sorted(segs.items())]


def seg_rect(page, seg):
    _, c, y0, y1 = seg
    mid = page.rect.width / 2
    x0 = 0 if c == 0 else mid
    x1 = mid if c == 0 else page.rect.width
    return fitz.Rect(x0, y0, x1, y1)


def detect_images(doc, segs):
    """세그먼트 내 이미지 블록/유의미 도형 존재 여부."""
    for seg in segs:
        page = doc[seg[0]]
        rect = seg_rect(page, seg)
        d = page.get_text('dict')
        for block in d['blocks']:
            if block['type'] == 1:
                bx = fitz.Rect(block['bbox'])
                if bx.width > 8 and bx.height > 8 and rect.contains(
                        fitz.Point((bx.x0 + bx.x1) / 2, (bx.y0 + bx.y1) / 2)):
                    return True
        for dr in page.get_drawings():
            bx = dr['rect']
            if bx.width * bx.height < 150:
                continue
            if rect.contains(fitz.Point((bx.x0 + bx.x1) / 2, (bx.y0 + bx.y1) / 2)):
                return True
    return False


def crop_question(doc, segs, out_path, zoom=2.0):
    """문항 세그먼트를 크롭해 세로로 이어붙인 PNG 저장 (그림 문항 표시용)."""
    from PIL import Image
    imgs = []
    for seg in segs:
        page = doc[seg[0]]
        rect = seg_rect(page, seg)
        rect = fitz.Rect(rect.x0 + 4, max(rect.y0 - 3, 0),
                         rect.x1 - 4, min(rect.y1 + 3, page.rect.height))
        if rect.height < 8:
            continue
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), clip=rect)
        imgs.append(Image.open(io.BytesIO(pix.tobytes('png'))))
    if not imgs:
        return False
    if len(imgs) == 1:
        imgs[0].save(out_path, optimize=True)
        return True
    wmax = max(im.width for im in imgs)
    canvas = Image.new('RGB', (wmax, sum(im.height for im in imgs)), 'white')
    y = 0
    for im in imgs:
        canvas.paste(im, (0, y))
        y += im.height
    canvas.save(out_path, optimize=True)
    return True


def parse_exam_pdf(fp, expected_max=100, subjects_by_range=None,
                   img_dir=None, img_prefix=''):
    """단일 교사용 PDF → 문항 dict 리스트.

    subjects_by_range: [(1, 20, '소방원론'), ...] 번호 범위별 과목 지정.
    img_dir 지정 시 그림 문항을 크롭 PNG로 저장하고 'image' 필드에 파일명 기록.
    반환 문항: {no, subject, question, options[4], answer(1-4),
               has_image, image, broken}
    """
    doc = fitz.open(fp)
    blocks, subj_marks = parse_question_blocks(doc, expected_max)
    results = []
    for idx, q in enumerate(blocks):
        next_q = blocks[idx + 1] if idx + 1 < len(blocks) else None
        stem, options, answer, broken = split_stem_options(build_raw_text(q))
        segs = question_segments(q, next_q)
        has_img = detect_images(doc, segs)
        subject = ''
        if subjects_by_range:
            for lo, hi, name in subjects_by_range:
                if lo <= q['no'] <= hi:
                    subject = name
                    break
        elif subj_marks:
            # PDF 내 'N과목 : 이름' 헤더 기반 자동 주입
            for mark_idx, name in subj_marks:
                if mark_idx <= idx:
                    subject = name
        img_rel = None
        if has_img and img_dir:
            os.makedirs(img_dir, exist_ok=True)
            fn = f'{img_prefix}{q["no"]:03d}.png'
            if crop_question(doc, segs, os.path.join(img_dir, fn)):
                img_rel = fn
        results.append({
            'no': q['no'], 'subject': subject, 'question': stem,
            'options': options, 'answer': answer,
            'has_image': has_img, 'image': img_rel, 'broken': broken,
        })
    doc.close()
    return results


if __name__ == '__main__':
    import sys
    import json
    fp = sys.argv[1]
    mx = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    qs = parse_exam_pdf(fp, expected_max=mx)
    ok = sum(1 for x in qs if not x['broken'] and x['answer'])
    print(f'{os.path.basename(fp)}: {len(qs)}문항 파싱, 정상 {ok}, '
          f'그림 {sum(1 for x in qs if x["has_image"])}, '
          f'broken {sum(1 for x in qs if x["broken"])}')
    print(json.dumps(qs[0], ensure_ascii=False)[:300])
