#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""학습데이터 사실검증 — 구조 무결성 + 해설↔정답 교차검증.

## 왜 필요한가
문항 16,653개는 사람이 눈으로 다 볼 수 없다. 그런데 **정답과 해설이 서로
어긋난 문항**은 학습자에게 직접적인 피해를 준다("해설은 3번이라는데 정답은 2번").
그래서 기계가 확인할 수 있는 것만 골라 전수 검사한다.

## 설계 원칙 (대리지표 금지)
- 「해설이 존재한다」는 품질의 증거가 아니다. 그건 분량일 뿐이다.
  그래서 **해설 안에 적힌 정답 번호**를 뽑아 `answer` 필드와 **직접 대조**한다.
- 검사기가 스스로를 검사한다: 대조 가능한 문항이 전체의 일정 비율 미만이면
  "통과"가 아니라 **검사 무효**로 보고한다. 표본이 없는데 통과라고 말하는 것은
  거짓이기 때문이다.
- 실패는 실패로 보고한다. 위반 건수를 0으로 만들기 위해 규칙을 느슨하게 하지 않는다.

## 검사 항목
  V0 JSON 파싱 가능 · 필수 키 존재
  V1 answer 가 1..len(options) 범위 안
  V2 보기 개수가 4개 (한국 기사시험 표준)
  V3 보기 중복 없음
  V4 question / options 공백 아님
  V5 해설에 적힌 정답번호 == answer  ← 핵심 교차검증
  V6 같은 시험 세트 안에서 문항번호(no) 중복 없음
  V7 subject / topic 공백 아님

종료코드 0 = 위반 없음. 1 = 위반 있음(또는 검사 무효).
"""
import json
import glob
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

# 해설 첫머리의 "✅ 정답 2번" / "정답: 3" / "[정답] 4번" 등을 인식한다.
# 지나치게 관대한 패턴은 오탐을 만들므로, 정답을 명시한 형태만 좁게 잡는다.
ANS_PATTERNS = [
    re.compile(r'정답\s*[:：]?\s*([1-4])\s*번'),
    re.compile(r'정답\s*[:：]\s*([1-4])'),
    re.compile(r'^\s*[✅✔]\s*([1-4])\s*번'),
]

# 원문자 보기 번호(①②③④)로 정답을 적은 경우도 대조 대상에 넣는다.
CIRCLED = {'①': 1, '②': 2, '③': 3, '④': 4}
CIRCLED_RE = re.compile(r'정답\s*[:：]?\s*([①②③④])')


def extract_answer_from_explanation(text: str):
    """해설에서 정답 번호를 추출한다. 확신할 수 없으면 None(=대조 제외)."""
    if not text:
        return None
    head = text[:120]  # 정답 표기는 서두에 온다. 본문 속 숫자를 오탐하지 않도록 제한.
    for p in ANS_PATTERNS:
        m = p.search(head)
        if m:
            return int(m.group(1))
    m = CIRCLED_RE.search(head)
    if m:
        return CIRCLED[m.group(1)]
    return None


def find_exam_files():
    """환경변수 경로 또는 기존 assets 경로에서 시험 데이터를 찾는다."""
    data_dir = os.environ.get('LEARNING_DATA_DIR', 'assets/data')
    return sorted(
        Path(path).as_posix()
        for path in glob.glob(os.path.join(data_dir, '*', 'exams.json'))
    )


# ── V8: 해설이 '실질 해설'인가 ───────────────────────────────────
#
# V5(해설↔정답 대조)만으로는 부족하다는 것을 실측으로 확인했다.
# V5 는 "해설에 적힌 정답번호"만 보므로, 본문이 아래처럼 학습에 쓸모없어도
# 전부 통과시킨다. 실제로 V0~V7 이 16,653문항을 '위반 0건'으로 통과시킨
# 코퍼스에서 6,446건(38.7%)이 아래 유형이었다.
#
# 판정을 '토큰 겹침'으로 하려다 폐기했다. 한국어는 조사가 붙어
# 문항의 "온수난방에" 와 해설의 "온수난방" 이 다른 토큰이 되어,
# 관련 있는 해설을 '무관'으로 오판했다(표본 15건 중 2건 오판 확인).
# 그래서 추측하지 않는 '정확 문자열/구조' 판정만 쓴다.
BOILERPLATE = '이 회차는 공식 해설이 아직 등록되지 않았습니다'
IMG_NOTE = '원본 PDF의 그림'
# '정답 N번' 머리말만 있고 본문이 없는 해설.
#
# 최초 판정은 r'^\s*✅\s*정답\s*\d+\s*번\s*:?\s*[^\n]{0,25}\s*\Z' 대신
# 끝에 $ 를 썼다가, 파이썬 $ 가 '문자열 끝'뿐 아니라 '마지막 개행 앞'에도
# 매칭되고 뒤의 \s* 가 개행을 삼켜서, 본문이 있는 해설까지
# '정답번호만'으로 오판했다(S7 사보타주에서 실측 발견).
# 그래서 추측을 없애고 '머리말을 제거한 뒤 남는 본문 길이'로 판정한다.
ANSWER_HEAD = re.compile(r'^\s*✅?\s*정답\s*[\d①-⑩]+\s*번?\s*[::]?\s*')

DEBT_BASELINE = 'tool/audit/explanation_debt_baseline.txt'


def classify_explanation(exp: str) -> str:
    """'ok' 또는 결함 종류를 돌려준다. 추측 없이 확정 판정만 한다."""
    e = (exp or '').strip()
    if not e:
        return '해설없음'
    if BOILERPLATE in e:
        return '정형문구'
    if IMG_NOTE in e and len(e) < 90:
        return '그림안내만'
    # 머리말('✅ 정답 3번: 보기내용')을 벗겨낸 뒤 실제 설명 본문이 남는가.
    # 첫 줄 전체를 머리말로 보고 버린다(보기 내용이 붙어 있어도 설명은 아니다).
    first, _, rest = e.partition('\n')
    if ANSWER_HEAD.match(first):
        body = rest.strip()
    else:
        body = e
    # 이모지/장식만 남은 경우도 본문이 아니다.
    body = re.sub(r'^[📘📗📕📷✅⚠️\s]+', '', body)
    if len(body) < 10:
        return '정답번호만'
    return 'ok'


def selfcheck_classifier() -> int:
    """V8 판정 로직 자기검사 (C4).

    검사기가 조용히 망가지면 '결함 0건'이라는 거짓 통과가 나온다.
    실제로 최초 구현은 파이썬 $ 의 개행 매칭 때문에 본문 있는 해설을
    '정답번호만'으로 오판했고, 사보타주 검증에서만 드러났다.
    그래서 본 검사를 실행할 때마다 판정 로직을 먼저 검증한다.
    """
    cases = [
        ('', '해설없음'),
        ('✅ 정답 2번', '정답번호만'),
        ('✅ 정답 4번: 아파트 현관', '정답번호만'),
        ('✅ 정답 2번\n\n📘', '정답번호만'),
        ('✅ 정답 1번\n\n📘 (본문이 실제로 존재한다)', 'ok'),
        ('✅ 정답 3번\n\n📘 증기난방 : 잠열 이용 온수난방 : 현열 이용', 'ok'),
        ('저압은 교류 1000V 이하를 말한다.', 'ok'),
        ('✅ 정답 1번\n\n📘 해설: ' + BOILERPLATE + '.', '정형문구'),
        ('📷 ' + IMG_NOTE + '/회로도를 문제 화면에서 확인할 수 있습니다.', '그림안내만'),
    ]
    fails = [(s, w, classify_explanation(s))
             for s, w in cases if classify_explanation(s) != w]
    if fails:
        print('✗ V8 판정 로직 자기검사 실패 — 이 검사기의 결과를 믿을 수 없다')
        for s, w, g in fails:
            print(f'    기대={w} 실제={g} 입력={s!r}')
        return 1
    return 0


def main():
    if selfcheck_classifier() != 0:
        return 1
    files = find_exam_files()
    if not files:
        data_dir = os.environ.get('LEARNING_DATA_DIR', 'assets/data')
        print(f'✗ {data_dir}/*/exams.json 을 찾지 못했다 — 실행 위치와 데이터 경로를 확인하라')
        return 1

    violations = defaultdict(list)   # 코드 -> [메시지]
    total_q = 0
    comparable = 0                   # V5 대조가 가능했던 문항 수
    per_track = {}
    debt = defaultdict(int)          # V8 결함종류 -> 건수
    debt_per_track = defaultdict(int)

    for f in files:
        track = Path(f).parent.name
        try:
            data = json.load(open(f, encoding='utf-8'))
        except Exception as e:
            violations['V0'].append(f'{f}: JSON 파싱 실패 {e}')
            continue
        exams = data if isinstance(data, list) else data.get('exams', [])
        t_q = t_cmp = t_bad = 0

        for ex in exams:
            seen_no = set()
            ex_name = ex.get('title') or ex.get('name') or ex.get('id') or '?'
            for q in ex.get('questions', []):
                total_q += 1
                t_q += 1
                loc = f'{track}/{ex_name}/no={q.get("no")}'

                opts = q.get('options')
                if not isinstance(opts, list):
                    violations['V0'].append(f'{loc}: options 가 리스트가 아니다')
                    continue

                ans = q.get('answer')
                if not isinstance(ans, int) or not (1 <= ans <= len(opts)):
                    violations['V1'].append(f'{loc}: answer={ans} 가 1..{len(opts)} 범위 밖')
                    t_bad += 1

                if len(opts) != 4:
                    violations['V2'].append(f'{loc}: 보기 {len(opts)}개 (4개여야 함)')

                norm = [str(o).strip() for o in opts]
                if len(set(norm)) != len(norm):
                    violations['V3'].append(f'{loc}: 보기 중복')

                if not str(q.get('question', '')).strip():
                    violations['V4'].append(f'{loc}: 문제 본문 비어있음')
                if any(not o for o in norm):
                    violations['V4'].append(f'{loc}: 빈 보기 존재')

                # V5 핵심 교차검증 — 해설이 말하는 정답과 answer 필드가 같은가
                exp_ans = extract_answer_from_explanation(q.get('explanation', ''))
                if exp_ans is not None:
                    comparable += 1
                    t_cmp += 1
                    if exp_ans != ans:
                        violations['V5'].append(
                            f'{loc}: 해설은 {exp_ans}번이라 하는데 answer={ans}')
                        t_bad += 1

                no = q.get('no')
                if no in seen_no:
                    violations['V6'].append(f'{loc}: 문항번호 중복')
                seen_no.add(no)

                # V8 해설 실질성 — '있다'는 양(量)이지 질(質)이 아니다
                kind = classify_explanation(q.get('explanation', ''))
                if kind != 'ok':
                    debt[kind] += 1
                    debt_per_track[track] += 1

                if not str(q.get('subject', '')).strip():
                    violations['V7'].append(f'{loc}: subject 비어있음')
                if not str(q.get('topic', '')).strip():
                    violations['V7'].append(f'{loc}: topic 비어있음')

        per_track[track] = (t_q, t_cmp, t_bad)

    # ── 보고 ────────────────────────────────────────────────
    print('=' * 62)
    print('학습데이터 사실검증 결과')
    print('=' * 62)
    print(f'  트랙 {len(per_track)}개 / 문항 {total_q:,}개')
    print(f'  해설↔정답 대조 가능 {comparable:,}개 '
          f'({comparable / total_q * 100:.1f}%)' if total_q else '')
    print()
    print('  %-22s %8s %10s %8s' % ('트랙', '문항', '대조가능', '위반'))
    for t, (q, c, b) in sorted(per_track.items()):
        print('  %-22s %8d %10d %8d' % (t, q, c, b))
    print()

    codes = {
        'V0': 'JSON/필수키 오류',
        'V1': 'answer 범위 오류',
        'V2': '보기 개수 != 4',
        'V3': '보기 중복',
        'V4': '빈 문항/보기',
        'V5': '해설↔정답 불일치 (핵심)',
        'V6': '문항번호 중복',
        'V7': 'subject/topic 누락',
    }
    total_v = sum(len(v) for v in violations.values())
    for code, label in codes.items():
        n = len(violations[code])
        mark = '✓' if n == 0 else '✗'
        print(f'  {mark} {code} {label:<26} {n}건')
        for msg in violations[code][:5]:
            print(f'       - {msg}')
        if n > 5:
            print(f'       … 외 {n - 5}건')

    # ── V8 해설 실질성 (래칫 부채) ───────────────────────────
    debt_total = sum(debt.values())
    print()
    print('  ── V8 해설 실질성 (학습에 쓸 수 있는 해설인가) ──')
    print(f'     실질 해설 {total_q - debt_total:,} / {total_q:,} '
          f'({(total_q - debt_total) / total_q * 100:.1f}%)' if total_q else '')
    for k in ('해설없음', '정형문구', '그림안내만', '정답번호만'):
        if debt[k]:
            print(f'     - {k:<8} {debt[k]:,}건')
    for t in sorted(debt_per_track):
        print(f'       · {t:<22} {debt_per_track[t]:,}건')

    # 래칫: 지금 6천건을 즉시 위반으로 만들면 "검사를 끄자"는 유혹이 생긴다.
    # 그래서 기준선을 파일에 못박고, '늘어나면' 실패로 만든다.
    # 줄어들면 기준선을 자동으로 낮춘다(= 한 번 갚은 부채는 다시 못 늘린다).
    debt_fail = False
    try:
        baseline = int(open(DEBT_BASELINE).read().split('#')[0].strip())
    except Exception:
        baseline = None

    if baseline is None:
        print(f'\n  ! V8 기준선 파일이 없다 — {DEBT_BASELINE} 에 {debt_total} 로 생성한다')
        with open(DEBT_BASELINE, 'w') as fp:
            fp.write(f'{debt_total}\n# V8 해설부채 기준선. 늘어나면 실패한다.\n'
                     f'# 줄이면 자동으로 낮아진다. 손으로 올리는 것은 금지.\n')
    elif debt_total > baseline:
        print(f'\n  ✗ V8 해설부채 악화: {baseline:,} → {debt_total:,} '
              f'(+{debt_total - baseline:,})')
        print('     해설 없는 문항을 새로 늘렸다. 되돌려라.')
        debt_fail = True
    elif debt_total < baseline:
        print(f'\n  ✓ V8 해설부채 감소: {baseline:,} → {debt_total:,} '
              f'(-{baseline - debt_total:,}) — 기준선을 낮춘다')
        with open(DEBT_BASELINE, 'w') as fp:
            fp.write(f'{debt_total}\n# V8 해설부채 기준선. 늘어나면 실패한다.\n'
                     f'# 줄이면 자동으로 낮아진다. 손으로 올리는 것은 금지.\n')
    else:
        print(f'\n  ✓ V8 해설부채 유지: {debt_total:,}건 (기준선과 동일, 악화 없음)')
        print('     주의: 이것은 "품질 좋음"이 아니라 "더 나빠지지 않았다"는 뜻이다.')

    print()
    # 검사기 자기검사 — 표본이 없으면 통과라고 말하지 않는다
    ratio = comparable / total_q if total_q else 0
    if ratio < 0.30:
        print(f'✗ 검사 무효 — 해설↔정답 대조 가능 문항이 {ratio*100:.1f}% 뿐이다.')
        print('  표본이 이렇게 적으면 "V5 위반 0건"은 품질의 증거가 아니라')
        print('  검사하지 못했다는 뜻이다. 통과로 보고하지 않는다.')
        return 1

    if total_v == 0 and not debt_fail:
        print(f'✓ 위반 0건 — 문항 {total_q:,}개 전수 검사, '
              f'해설↔정답 {comparable:,}개 대조 완료')
        print(f'  단, 해설부채 {debt_total:,}건이 남아있다 (V8 참조). '
              f'"위반 0건"은 부채가 없다는 뜻이 아니다.')
        return 0
    if debt_fail:
        print('✗ V8 해설부채 악화 — 출시 차단')
        return 1
    print(f'✗ 위반 {total_v}건 — 위 목록을 고쳐라 (검사를 느슨하게 하는 것은 금지)')
    return 1


if __name__ == '__main__':
    sys.exit(main())
