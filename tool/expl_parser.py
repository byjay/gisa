# -*- coding: utf-8 -*-
"""comcbt 해설집 PDF → {문항번호: 해설텍스트} 추출기.

해설집 구조:
    N. 문제지문...
       ① .. ② .. ③ .. ④ ..
    <문제 해설>
    해설 본문...
    [해설작성자 : XXX]
    (다음 문항 번호까지)
"""
import fitz
import re

QNUM_RE = re.compile(r'^\s*(\d{1,3})\.\s')
EXPL_OPEN = '<문제 해설>'
AUTHOR_RE = re.compile(r'\[해설작성자\s*[:：][^\]]*\]')
NOISE_RE = re.compile(
    r'(comcbt\.com|전자문제집 CBT|해설달기 프로젝트|실시간으로 변경됩니다'
    r'|◐.*?◑|아래와 같은 오류|오류 신고[를]? 하[여면]|정답[을]? 위와 같이 수정)')


def extract_explanations(fp, expected_max=130):
    """해설집 PDF에서 문항번호별 해설 텍스트 dict 반환."""
    doc = fitz.open(fp)
    # 전체 텍스트 라인 수집 (2단 컬럼: 좌→우)
    lines = []
    for pno, page in enumerate(doc):
        mid = page.rect.width / 2
        d = page.get_text('dict')
        for block in d['blocks']:
            if block['type'] != 0:
                continue
            for ln in block['lines']:
                x0, y0, x1, y1 = ln['bbox']
                text = ''.join(s['text'] for s in ln['spans']).strip()
                if not text or NOISE_RE.search(text):
                    continue
                col = 0 if x0 < mid else 1
                lines.append((pno, col, round(y0, 1), x0, text))
    doc.close()
    lines.sort()

    # 문항 번호 경계로 그룹핑
    result = {}
    cur_no = None
    buf = []
    expected = 1
    for _, _, _, _, text in lines:
        m = QNUM_RE.match(text)
        if m and int(m.group(1)) == expected and expected <= expected_max:
            if cur_no is not None:
                result[cur_no] = _pick_expl(buf)
            cur_no = expected
            expected += 1
            buf = [text]
        elif cur_no is not None:
            buf.append(text)
    if cur_no is not None:
        result[cur_no] = _pick_expl(buf)
    return {k: v for k, v in result.items() if v}


def _pick_expl(buf):
    """블록 라인들에서 <문제 해설> 이후 텍스트만 취해 정리."""
    joined = '\n'.join(buf)
    if EXPL_OPEN not in joined:
        return ''
    expl = joined.split(EXPL_OPEN, 1)[1]
    expl = AUTHOR_RE.sub('', expl)
    # 줄 병합: 한국어 워드랩 복원 (문장부호로 끝나지 않으면 이어붙임)
    out_lines = []
    for raw in expl.split('\n'):
        s = raw.strip()
        if not s:
            continue
        if out_lines and not out_lines[-1].endswith(
                ('.', '?', '!', ':', ')', ']', '다', '요', '음', '함', '됨', '임')):
            out_lines[-1] += ' ' + s
        else:
            out_lines.append(s)
    text = '\n'.join(out_lines).strip()
    # 과도하게 짧으면 무효
    return text if len(text) >= 8 else ''


if __name__ == '__main__':
    import sys
    import json
    fp = sys.argv[1]
    ex = extract_explanations(fp)
    print(f'{fp.split("/")[-1]}: 해설 {len(ex)}건')
    for k in sorted(ex)[:3]:
        print(f'--- Q{k} ---')
        print(ex[k][:200])
