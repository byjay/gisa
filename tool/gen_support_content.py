#!/usr/bin/env python3
"""신규 트랙 지원 콘텐츠 생성기 — 전기기사 수준 품질 매칭.

exams.json(실기출)에서 반복 문항·토픽 빈도를 채굴하여
lessons/repeat_questions/theory_slides/solution_recipes/mnemonics/
study_guide/study_plan/formula_guide/videos/exam_info_2026/silgi +
backend/data/theory/<track>/NN.md 를 생성한다.
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from topic_rules import TOPIC_RULES  # noqa: E402

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 트랙별 메타: 과목 순서(exam_track.dart와 동일), 실기 개요, 전략 노트
META = {
    'fire_mechanical': {
        'name': '소방설비기사(기계)',
        'subjects': ['소방원론', '소방유체역학', '소방관계법규',
                     '소방기계시설의 구조 및 원리'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 4과목 균형이 핵심',
            '소방원론·법규는 소방설비(전기)와 공통 — 암기 중심으로 빠르게 확보',
            '유체역학은 베르누이·연속방정식·펌프 동력 공식만 반복하면 계산 절반 해결',
            '기계시설 구조·원리는 스프링클러·옥내소화전 수치 암기가 곧 점수',
        ],
        'silgi_title': '소방설비기사(기계) 실기 핵심 (소방기계시설 설계·시공)',
        'silgi_overview': '실기는 필답형 계산·서술. 옥내소화전 방수량·펌프 양정 계산, '
                          '스프링클러 헤드 수량·배관 구경, 포·가스계 소화설비 약제량 계산이 '
                          '반복 출제. 60점 이상 합격(과락 없음). NFPC/NFTC 수치 암기 필수.',
    },
    'info_processing': {
        'name': '정보처리기사',
        'subjects': ['소프트웨어 설계', '소프트웨어 개발', '데이터베이스 구축',
                     '프로그래밍 언어 활용', '정보시스템 구축관리'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 전공자는 2주, 비전공자는 4주면 충분',
            'NCS 개편(2020) 이후 기출만 유효 — 본 앱은 개편 후 8회차만 수록',
            'SQL·정규화·디자인패턴·결합도/응집도는 매회 출제되는 4대 필수 주제',
            '프로그래밍 언어(C/Java/Python) 코드 추적 문제는 직접 손으로 풀어볼 것',
        ],
        'silgi_title': '정보처리기사 실기 핵심 (정보처리 실무)',
        'silgi_overview': '실기는 필답형 20문항(단답·약술). 프로그래밍(C/Java/Python) 결과 쓰기, '
                          'SQL 작성, 용어 영문 약어가 3대 축. 60점 이상 합격. '
                          '필기 이론(디자인패턴·정규화·테스트기법)이 실기에 그대로 재출제된다.',
    },
    'industrial_safety': {
        'name': '산업안전기사',
        'subjects': ['안전관리론', '인간공학 및 시스템안전공학', '기계위험방지기술',
                     '전기위험방지기술', '화학설비위험방지기술', '건설안전기술'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 6과목 중 약한 과목 과락 방지가 핵심',
            '안전관리론·인간공학은 이론 암기형 — 재해율 공식·FTA 기호부터 암기',
            '기계·전기·화학·건설 4개 기술과목은 법정 수치(방호장치·안전거리) 암기가 곧 점수',
            '산업안전보건법 개정사항(안전보건관리체계)은 최신 기출로 확인',
        ],
        'silgi_title': '산업안전기사 실기 핵심 (산업안전관리 실무)',
        'silgi_overview': '실기는 필답형+작업형(동영상). 재해율 계산, 안전인증 대상, 방호장치, '
                          '위험물 취급, 건설 가시설 기준이 반복 출제. 필답 55점+작업형 45점 '
                          '구성으로 60점 이상 합격. 법정 수치 암기가 절대적.',
    },
    'architecture': {
        'name': '건축기사',
        'subjects': ['건축계획', '건축시공', '건축구조', '건축설비', '건축법규'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 구조 과락 방지가 최우선',
            '건축계획은 각론(주택·사무소·학교·병원) 수치 암기 중심 — 단기 득점 가능',
            '건축구조는 역학 계산(반력·응력·처짐)과 RC/철골 규준 병행 — 매일 조금씩',
            '법규는 최신 개정 반영 기출 위주로 — 면적·높이 산정 기준 반복',
        ],
        'silgi_title': '건축기사 실기 핵심 (건축시공 실무)',
        'silgi_overview': '실기는 필답형. 시공(공정표·네트워크·적산), 구조 계산(휨모멘트·철근량), '
                          '품질관리가 3대 축. 60점 이상 합격. 공정표 작성과 물량 산출은 '
                          '손으로 반복 연습해야 실전에서 시간 안에 푼다.',
    },
    'construction_safety': {
        'name': '건설안전기사',
        'subjects': ['산업안전관리론', '산업심리 및 교육', '인간공학 및 시스템안전공학',
                     '건설시공학', '건설재료학', '건설안전기술'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 6과목 균형 관리',
            '안전관리론·심리교육은 산업안전기사와 상당 부분 공통 — 동시 준비 유리',
            '건설시공학·재료학은 건축기사 시공 과목과 중복 — 공법·재료 특성 암기',
            '건설안전기술은 가설공사·토공사·거푸집 법정 수치가 매회 출제',
        ],
        'silgi_title': '건설안전기사 실기 핵심 (건설안전관리 실무)',
        'silgi_overview': '실기는 필답형+작업형(동영상). 가설통로·비계 기준, 굴착면 기울기, '
                          '거푸집 동바리, 추락·낙하 방지 조치가 반복 출제. 60점 이상 합격. '
                          '법정 수치와 안전계수 암기가 핵심.',
    },
    'elec_industrial': {
        'name': '전기산업기사',
        'subjects': ['전기자기학', '전력공학', '전기기기', '회로이론',
                     '전기설비기술기준'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 전기기사보다 계산 난도가 한 단계 낮다',
            '자기학·회로이론은 공식 대입형이 다수 — 기본 공식 암기로 과락 회피',
            '전기기기는 직류기·변압기·유도기 3대 기기 특성 비교표로 정리',
            '설비기준(KEC)은 접지·이격거리·시설기준 수치 암기가 곧 점수',
        ],
        'silgi_title': '전기산업기사 실기 핵심 (전기설비 설계 및 관리)',
        'silgi_overview': '실기는 필답형. 수변전 설비 용량 계산, 조명 설계, 접지·보호계전, '
                          '시퀀스 회로가 반복 출제. 60점 이상 합격. 전기기사 실기와 범위가 '
                          '겹치므로 상위 자격 준비에도 그대로 연결된다.',
    },
    'hazmat_industrial': {
        'name': '위험물산업기사',
        'subjects': ['일반화학', '화재예방과 소화방법', '위험물의 성질과 취급'],
        'strategy': [
            '평균 60점, 과목당 40점만 넘기면 합격 — 3과목뿐이라 단기 합격이 많다',
            '일반화학은 몰·농도·산화환원 계산 패턴 반복 — 주기율표 앞 20개 원소는 필수',
            '소화방법은 소화약제별 적응 화재(제1~6류)의 매칭 암기가 핵심',
            '위험물 성질은 류별 지정수량·품명 암기표가 곧 점수 — 매일 반복',
        ],
        'silgi_title': '위험물산업기사 실기 핵심 (위험물 취급 실무)',
        'silgi_overview': '실기는 필답형. 류별 위험물의 지정수량·품명, 저장·취급 기준, '
                          '제조소 설비 기준, 소화설비 적응성이 반복 출제. 60점 이상 합격. '
                          '지정수량 배수 계산과 류별 성질 암기가 절대적.',
    },
}

VIDEO_QUERIES = {
    'fire_mechanical': '소방설비기사 기계 무료강의',
    'info_processing': '정보처리기사 필기 무료강의',
    'industrial_safety': '산업안전기사 필기 무료강의',
    'architecture': '건축기사 필기 무료강의',
    'construction_safety': '건설안전기사 필기 무료강의',
    'elec_industrial': '전기산업기사 필기 무료강의',
    'hazmat_industrial': '위험물산업기사 필기 무료강의',
}

# 트랙별 핵심 공식 (formula_guide): (name, expr, subject, desc)
FORMULAS = {
    'fire_mechanical': [
        ('연속방정식', 'Q = A·V', '소방유체역학', '유량 = 단면적 × 유속. 배관 축소 시 유속 증가.'),
        ('베르누이 방정식', 'P/γ + V²/2g + Z = 일정', '소방유체역학', '압력수두+속도수두+위치수두 보존. 펌프 양정 계산의 뿌리.'),
        ('펌프 동력', 'P = γQH/η', '소방유체역학', '축동력 = 비중량×유량×전양정/효율. kW 환산 주의.'),
        ('레이놀즈수', 'Re = ρVD/μ', '소방유체역학', '층류 Re<2100, 난류 Re>4000. 유동 판별 기준.'),
        ('옥내소화전 방수량', 'Q = 130 L/min 이상', '소방기계시설의 구조 및 원리', '방수압 0.17MPa 이상, 노즐 선단 기준. 매회 출제.'),
        ('스프링클러 방수량', 'Q = 80 L/min, 0.1MPa', '소방기계시설의 구조 및 원리', '헤드 1개 기준 방수량·방수압. 수원량 산정의 기초.'),
        ('스테판-볼츠만 법칙', 'E = σT⁴', '소방원론', '복사열은 절대온도 4제곱 비례. 플래시오버 근거.'),
    ],
    'info_processing': [
        ('응집도 순서', '우연<논리<시간<절차<통신<순차<기능', '소프트웨어 설계', '기능적 응집이 가장 강함(좋음). 역순 함정 주의.'),
        ('결합도 순서', '자료<스탬프<제어<외부<공통<내용', '소프트웨어 설계', '자료 결합이 가장 약함(좋음). 낮을수록 좋다.'),
        ('맥케이브 순환복잡도', 'V(G) = E - N + 2', '소프트웨어 개발', '간선-노드+2. 화살표 수와 노드 수만 세면 된다.'),
        ('정규화 단계', '1NF→2NF→3NF→BCNF', '데이터베이스 구축', '원자값→부분함수종속 제거→이행종속 제거→결정자 후보키.'),
        ('트랜잭션 ACID', '원자성·일관성·고립성·지속성', '데이터베이스 구축', 'Atomicity, Consistency, Isolation, Durability.'),
        ('IPv4 클래스', 'A: 0~127, B: 128~191, C: 192~223', '정보시스템 구축관리', '첫 옥텟 범위로 클래스 판별. 사설 IP 대역도 함께 암기.'),
        ('RAID 레벨', 'RAID 0 스트라이핑, 1 미러링, 5 패리티', '정보시스템 구축관리', 'RAID 5는 디스크 1개 장애 허용, 최소 3개 필요.'),
    ],
    'industrial_safety': [
        ('연천인율', '재해자수/연평균근로자수 × 1000', '안전관리론', '1000명당 1년간 재해자 수. 도수율×2.4 근사 환산.'),
        ('도수율', '재해건수/연근로시간수 × 10⁶', '안전관리론', '100만 근로시간당 재해 건수.'),
        ('강도율', '근로손실일수/연근로시간수 × 1000', '안전관리론', '1000 근로시간당 손실일수. 사망 = 7500일.'),
        ('휴먼에러 확률', 'HEP = 에러 수/에러 기회 수', '인간공학 및 시스템안전공학', '인간 신뢰도 R = 1 - HEP.'),
        ('안전율', 'S = 극한강도/허용응력', '기계위험방지기술', '와이어로프 안전율: 권상용 5 이상 등 용도별 수치 암기.'),
        ('허용접촉전압', '1종 2.5V, 2종 25V, 3종 50V', '전기위험방지기술', '장소 위험도별 허용 접촉전압. 매회 출제.'),
        ('위험도', 'H = (UEL-LEL)/LEL', '화학설비위험방지기술', '폭발상한-하한/하한. 아세틸렌·수소가 위험도 상위.'),
    ],
    'architecture': [
        ('건폐율', '건축면적/대지면적 × 100', '건축법규', '대지에 대한 건축면적 비율. 용적률과 세트 출제.'),
        ('용적률', '연면적/대지면적 × 100', '건축법규', '지하층·부속용도 주차장 면적은 연면적에서 제외.'),
        ('휨응력', 'σ = M/Z', '건축구조', '휨모멘트/단면계수. 단면계수 Z = bh²/6 (직사각형).'),
        ('처짐(단순보 중앙집중)', 'δ = PL³/48EI', '건축구조', '집중하중 단순보 최대 처짐. 등분포는 5wL⁴/384EI.'),
        ('철근 정착길이', 'ld = 기본정착길이 × 보정계수', '건축구조', '인장 이형철근 기준. D22 이하/초과 보정 구분.'),
        ('열관류율', 'K = 1/ΣR', '건축설비', '벽체 단열 성능. 낮을수록 단열 우수.'),
        ('급수 최저압력', '대변기 세정밸브 0.1MPa', '건축설비', '기구별 최저 필요압력. 수도직결 0.1~0.4MPa.'),
    ],
    'construction_safety': [
        ('재해율 3공식', '연천인율·도수율·강도율', '산업안전관리론', '연천인율=재해자/근로자×1000, 도수율=건수/시간×10⁶, 강도율=손실일/시간×1000.'),
        ('안전대 최하사점', 'H > 로프길이 + 신장길이 + 여유', '건설안전기술', '추락 시 바닥 미도달 조건. 계산형 매회 출제.'),
        ('비계 작업발판', '폭 40cm 이상, 틈 3cm 이하', '건설안전기술', '강관비계 띠장 2.0m 이하, 기둥 간격 1.85m(장선방향 1.5m) 이하.'),
        ('굴착면 기울기', '모래 1:1.8, 풍화암·연암 1:1.0, 경암 1:0.5', '건설안전기술', '2023 개정 기준. 흙막이 없는 굴착 시 준수.'),
        ('가설통로 경사', '30° 이하, 15° 초과 시 미끄럼막이', '건설안전기술', '높이 8m 이상 비계다리엔 7m마다 계단참.'),
        ('콘크리트 강도', 'f28 = 21~27MPa (일반)', '건설재료학', '물시멘트비가 강도 지배. 슬럼프시험으로 시공연도 측정.'),
        ('네트워크 공정표', 'CP = 여유 0인 경로', '건설시공학', '주공정선이 공기 지배. TF=LT-ET, FF 구분.'),
    ],
    'elec_industrial': [
        ('쿨롱의 법칙', 'F = Q₁Q₂/(4πε₀r²)', '전기자기학', '두 전하 간 힘. 거리 제곱 반비례.'),
        ('전력 3공식', 'P = VI = I²R = V²/R', '회로이론', '옴의 법칙과 결합한 만능 공식.'),
        ('동기속도', 'Ns = 120f/P', '전기기기', '극수 P, 주파수 f. 유도기 슬립 s = (Ns-N)/Ns.'),
        ('변압기 권수비', 'a = V₁/V₂ = N₁/N₂ = I₂/I₁', '전기기기', '전압은 권수비례, 전류는 반비례.'),
        ('전압강하(단상2선)', 'e = 2I(Rcosθ + Xsinθ)', '전력공학', '3상은 √3배. 배전 계산 기본.'),
        ('역률 개선 콘덴서', 'Qc = P(tanθ₁ - tanθ₂)', '전력공학', '개선 전후 무효전력 차. 매회 출제.'),
        ('접지저항 저감', '접지극 병렬·매설깊이·길이 증가', '전기설비기술기준', 'KEC 접지시스템: 계통·보호·피뢰 접지 구분.'),
    ],
    'hazmat_industrial': [
        ('몰 농도', 'M = 용질 mol / 용액 L', '일반화학', '몰수 = 질량/분자량. 농도 환산 기본.'),
        ('이상기체 방정식', 'PV = nRT', '일반화학', 'R = 0.082 atm·L/mol·K. 증기 부피 계산에 사용.'),
        ('pH', 'pH = -log[H⁺]', '일반화학', 'pH+pOH = 14. 강산·강염기 완전해리 가정.'),
        ('지정수량 배수', '배수 = Σ(저장량/지정수량)', '위험물의 성질과 취급', '배수 합 1 이상이면 위험물 규제 대상. 매회 계산 출제.'),
        ('제4류 지정수량', '특수인화물 50L, 1석유류 200/400L, 알코올류 400L', '위험물의 성질과 취급', '2석유류 1000/2000L, 3석유류 2000/4000L, 4석유류 6000L, 동식물유 10000L.'),
        ('소화기 능력단위', 'A급·B급 능력단위 표시', '화재예방과 소화방법', '전기(C급)는 능력단위 없이 적응성만 표시.'),
        ('할론 소화약제', 'Halon 1301 = CF₃Br', '화재예방과 소화방법', '천단위: C·F·Cl·Br 원자 수. 1211 = CF₂ClBr.'),
    ],
}

# 트랙별 암기법 (mnemonics): (subject, title, body, tip)
MNEMONICS = {
    'fire_mechanical': [
        ('소방원론', '화재 급수·색상', 'A일반(백) B유류(황) C전기(청) D금속(무) K주방', '"에이일반 비유류 씨전기 디금속"'),
        ('소방유체역학', '베르누이 3수두', '압력수두 + 속도수두 + 위치수두 = 일정', '"압속위는 일정하다"'),
        ('소방유체역학', '층류·난류 경계', '층류 2100 이하, 난류 4000 이상', '"이천백 층, 사천 난"'),
        ('소방관계법규', '소방시설 5분류', '소화설비·경보설비·피난구조설비·소화용수설비·소화활동설비', '"소경피용활"'),
        ('소방기계시설의 구조 및 원리', '옥내소화전 기준', '방수압 0.17MPa·방수량 130L/min·수평거리 25m', '"일칠 백삼십 이십오"'),
        ('소방기계시설의 구조 및 원리', '스프링클러 기준', '방수압 0.1MPa·방수량 80L/min', '"영점일에 팔십"'),
    ],
    'info_processing': [
        ('소프트웨어 설계', '응집도 순서(약→강)', '우연→논리→시간→절차→통신→순차→기능', '"우논시절통순기"'),
        ('소프트웨어 설계', '결합도 순서(약→강)', '자료→스탬프→제어→외부→공통→내용', '"자스제외공내"'),
        ('데이터베이스 구축', '정규화 단계', '1NF 원자값 → 2NF 부분종속 제거 → 3NF 이행종속 제거 → BCNF 결정자', '"도부이결다조"'),
        ('소프트웨어 개발', '블랙박스 테스트 기법', '동등분할·경계값·원인효과·오류추측·비교', '"동경원오비"'),
        ('프로그래밍 언어 활용', '연산자 우선순위', '괄호 > 단항 > 산술 > 시프트 > 관계 > 비트 > 논리 > 대입', '"괄단산시관비논대"'),
        ('정보시스템 구축관리', 'OSI 7계층', '물리-데이터링크-네트워크-전송-세션-표현-응용', '"물데네전세표응"'),
    ],
    'industrial_safety': [
        ('안전관리론', '하인리히 법칙', '1(중상) : 29(경상) : 300(무상해)', '"일 이구 삼백"'),
        ('안전관리론', '재해예방 4원칙', '손실우연·원인계기·예방가능·대책선정', '"손원예대"'),
        ('인간공학 및 시스템안전공학', 'FTA 논리기호', 'AND 게이트 = 모두 발생 시, OR 게이트 = 하나만 발생해도', '"앤드는 곱, 오어는 합"'),
        ('기계위험방지기술', '방호장치 5종', '격리형·위치제한형·접근거부형·접근반응형·포집형', '"격위거반포"'),
        ('전기위험방지기술', '허용접촉전압', '1종 2.5V, 2종 25V, 3종 50V', '"이오, 이십오, 오십"'),
        ('화학설비위험방지기술', '연소 3요소', '가연물·산소공급원·점화원 (+연쇄반응=4요소)', '"가산점, 더하기 연쇄"'),
        ('건설안전기술', '굴착면 기울기', '모래 1:1.8, 풍화암·연암 1:1.0, 경암 1:0.5', '"모일팔, 암일영, 경오"'),
    ],
    'architecture': [
        ('건축계획', '모듈러 치수', '기본 모듈 M = 100mm', '"엠은 백"'),
        ('건축시공', '콘크리트 타설 순서', '계획→운반→타설→다짐→양생', '"계운타다양"'),
        ('건축구조', '단면계수', 'Z = bh²/6 (직사각형)', '"비 에이치제곱 육"'),
        ('건축설비', '급수 방식 4종', '수도직결·고가수조·압력수조·펌프직송', '"직고압펌"'),
        ('건축법규', '건폐율·용적률', '건폐율 = 건축면적/대지, 용적률 = 연면적/대지', '"건은 바닥, 용은 쌓기"'),
        ('건축구조', '철근 피복두께 목적', '내화·내구·부착', '"내내부"'),
    ],
    'construction_safety': [
        ('산업안전관리론', '하인리히 도미노 5단계', '사회적환경→개인결함→불안전행동·상태→사고→재해', '"3단계 제거가 핵심"'),
        ('산업심리 및 교육', '교육 3요소', '주체(강사)·객체(학습자)·매개체(교재)', '"주객매"'),
        ('인간공학 및 시스템안전공학', '휴먼에러 분류', '생략·수행·순서·시간·불필요행동', '"생수순시불"'),
        ('건설시공학', '지반조사 순서', '지하탐사→보링→샘플링→토질시험', '"탐보샘토"'),
        ('건설재료학', '시멘트 응결시간', '초결 1시간 이후, 종결 10시간 이내', '"일 초, 십 종"'),
        ('건설안전기술', '비계 발판 기준', '폭 40cm 이상, 틈 3cm 이하', '"사십에 삼"'),
    ],
    'elec_industrial': [
        ('전기자기학', '쿨롱 힘 방향', '같은 극성 반발, 다른 극성 흡인 — 거리 제곱 반비례', '"같반다흡"'),
        ('전력공학', '역률 개선 효과', '전력손실 감소·전압강하 감소·설비여유 증가·요금 절감', '"손압여요"'),
        ('전기기기', '동기속도', 'Ns = 120f/P', '"일이공 에프 피"'),
        ('회로이론', '직렬공진 특징', 'XL = XC, 임피던스 최소·전류 최대', '"직공 최소 최대"'),
        ('전기설비기술기준', '접지 시스템 3종', '계통접지·보호접지·피뢰시스템접지', '"계보피"'),
        ('전기기기', '변압기 병렬운전 조건', '극성·권수비·%임피던스 일치 (+3상: 상회전·각변위)', '"극권임 상각"'),
    ],
    'hazmat_industrial': [
        ('일반화학', '주기율표 1~20', '수헬리베 붕탄질산 플네나마 알규인황 염아칼칼', '리듬으로 암기'),
        ('화재예방과 소화방법', '소화 4방법', '제거·질식·냉각·억제(부촉매)', '"제질냉억"'),
        ('위험물의 성질과 취급', '류별 성질', '1산화 2가연 3자연·금수 4인화 5자기 6산화액', '"산가자인자산"'),
        ('위험물의 성질과 취급', '제4류 지정수량', '특50 알400 / 1석 200·400 / 2석 1000·2000 / 3석 2000·4000 / 4석 6000 / 동식물유 10000', '"비수용성이 절반"'),
        ('화재예방과 소화방법', '할론 명명법', '천의자리 C·백 F·십 Cl·일 Br', '"탄불염브"'),
        ('일반화학', '산화·환원', '산화 = 산소 얻음·전자 잃음, 환원 = 반대', '"산잃전, 환얻전"'),
    ],
}


def norm_q(text):
    return re.sub(r'\s+', '', text)


def load_exams(track):
    with open(f'{APP}/backend/data/study/{track}/exams.json', encoding='utf-8') as f:
        return json.load(f)


def mine_repeats(exams, limit=40):
    """동일 문항이 2회 이상 출제된 클러스터 채굴 (전기기사 방식)."""
    groups = defaultdict(list)
    for e in exams:
        for q in e['questions']:
            key = (q['subject'], norm_q(q['question'])[:80], q['answer'])
            groups[key].append((e['label'], q))
    clusters = []
    for (subj, _, ans), items in groups.items():
        labels = sorted(set(lb for lb, _ in items))
        if len(labels) < 2:
            continue
        _, q = items[0]
        if q['has_image']:
            continue
        clusters.append({
            'subject': subj,
            'topic': q['topic'],
            'count': len(labels),
            'exams': labels,
            'question': q['question'],
            'options': q['options'],
            'answer': q['answer'],
            'explanation': q['explanation'],
            'answer_text': q['options'][q['answer'] - 1],
        })
    clusters.sort(key=lambda c: -c['count'])
    return clusters[:limit]


def topic_stats(exams):
    cnt = Counter()
    for e in exams:
        for q in e['questions']:
            cnt[(q['subject'], q['topic'])] += 1
    return cnt


def build_lessons(track, meta, exams, cnt, rep_by_topic, rules, n_exams):
    lessons = []
    max_cnt = max(cnt.values()) if cnt else 1
    for subj in meta['subjects']:
        topics = sorted([(t, c) for (s, t), c in cnt.items() if s == subj],
                        key=lambda x: -x[1])
        kw_map = {t: kws for t, kws in rules.get(subj, [])}
        for topic, c in topics:
            imp = max(1, min(5, round(4 * c / max_cnt) + 1))
            kws = kw_map.get(topic, [])
            reps = rep_by_topic.get((subj, topic), [])[:3]
            sections = [{
                'title': '1. 출제 경향',
                'body': (f'{n_exams}회차 실기출 분석 결과 **{topic}** 토픽에서 '
                         f'**{c}문항** 출제 (회당 평균 {c / n_exams:.1f}문항). '
                         '과목 내 상위 빈출 토픽입니다.'
                         if c >= n_exams else
                         f'{n_exams}회차 실기출에서 **{c}문항** 출제된 토픽입니다. '
                         '핵심 키워드 위주로 정리하면 충분합니다.'),
            }]
            if kws:
                sections.append({
                    'title': '2. 핵심 키워드',
                    'body': '이 토픽 문제의 단서 키워드:\n\n'
                            + '\n'.join(f'- **{k}**' for k in kws)
                            + '\n\n문제에서 위 키워드가 보이면 이 토픽의 공식·기준을 적용하세요.',
                })
            if reps:
                body = '실제로 2회 이상 반복 출제된 문항:\n'
                for r in reps:
                    body += (f'\n**Q. {r["question"][:90]}**\n'
                             f'→ 정답: **{r["answer_text"]}** '
                             f'({r["count"]}회 출제: {", ".join(r["exams"][:4])})\n')
                sections.append({'title': f'{len(sections) + 1}. 기출 반복 포인트',
                                 'body': body})
            lessons.append({
                'subject': subj,
                'topic': topic,
                'freq': c,
                'importance': imp,
                'intro': f'{meta["name"]} {subj} 과목의 "{topic}" 토픽입니다. '
                         f'{n_exams}회차 기출에서 {c}문항 출제되어 '
                         f'{"매회 나오는 필수 토픽" if c >= n_exams else "선택과 집중 대상 토픽"}입니다.',
                'sections': sections,
                'formulas': [
                    {'name': nm, 'expr': ex, 'note': ds}
                    for nm, ex, sj, ds in FORMULAS.get(track, []) if sj == subj
                ][:3],
                'mnemonics': [
                    f'{t}: {b}' for sj, t, b, _ in MNEMONICS.get(track, [])
                    if sj == subj
                ][:2],
                'traps': [
                    '보기에서 조건(단위·기준값)을 살짝 바꾼 함정에 주의',
                    '"옳은 것 / 옳지 않은 것" 문두를 반드시 확인',
                ],
                'strategy': f'{topic}은 기출 {c}문항 분석 기준 '
                            f'{"매회 출제 — 반드시 득점" if c >= n_exams else "빈출 키워드 위주 정리"}. '
                            '반복 기출 문항부터 완벽히 하세요.',
                'basic_explain': '',
                'exam_how': [f'{r["question"][:60]}… ({r["count"]}회)'
                             for r in reps[:2]],
                'must': [f'{r["answer_text"]} ← {r["question"][:50]}…'
                         for r in reps[:2]],
                'advanced': [],
                'silgi': '',
            })
    return lessons


def build_all(track):
    meta = META[track]
    exams = load_exams(track)
    n_exams = len(exams)
    total_q = sum(e['question_count'] for e in exams)
    cnt = topic_stats(exams)
    repeats = mine_repeats(exams)
    rules = TOPIC_RULES.get(track, {})
    out = f'{APP}/backend/data/study/{track}'
    theory_dir = f'{APP}/backend/data/theory/{track}'
    os.makedirs(theory_dir, exist_ok=True)

    rep_by_topic = defaultdict(list)
    for r in repeats:
        rep_by_topic[(r['subject'], r['topic'])].append(r)

    lessons = build_lessons(track, meta, exams, cnt, rep_by_topic, rules, n_exams)
    with open(f'{out}/lessons.json', 'w', encoding='utf-8') as f:
        json.dump(lessons, f, ensure_ascii=False)

    with open(f'{out}/repeat_questions.json', 'w', encoding='utf-8') as f:
        json.dump(repeats, f, ensure_ascii=False)

    # solution_recipes
    recipes, seen = [], set()
    for les in lessons:
        if les['topic'] in seen:
            continue
        seen.add(les['topic'])
        fs = [f'{fx["name"]}: {fx["expr"]}' for fx in les['formulas']]
        recipes.append({
            'topic': les['topic'],
            'check': f'{les["topic"]} 문제인지 유형(개념/계산/적용)을 먼저 구분',
            'steps': [
                f'{les["topic"]} 문제에서 묻는 핵심(정의/값/조건) 파악',
                '관련 공식·법규·기준 수치 즉시 떠올리기',
                '보기 중 조건을 바꾼 함정 제거',
                '계산형이면 단위 확인 후 대입',
            ],
            'formulas': fs or [f'{les["topic"]} 대표 관계식·기준 수치'],
        })
    with open(f'{out}/solution_recipes.json', 'w', encoding='utf-8') as f:
        json.dump(recipes, f, ensure_ascii=False)

    # mnemonics
    mn = [{'subject': s, 'title': t, 'body': b, 'tip': tip}
          for s, t, b, tip in MNEMONICS.get(track, [])]
    with open(f'{out}/mnemonics.json', 'w', encoding='utf-8') as f:
        json.dump(mn, f, ensure_ascii=False)

    # formula_guide
    fg = {
        'title': f'{meta["name"]} 공식 마스터',
        'intro': f'{meta["name"]} 필기 최빈출 공식·기준 수치를 과목별로 정리했습니다.',
        'formulas': [{'name': nm, 'expr': ex, 'subject': sj, 'desc': ds}
                     for nm, ex, sj, ds in FORMULAS.get(track, [])],
        'basics': [],
    }
    with open(f'{out}/formula_guide.json', 'w', encoding='utf-8') as f:
        json.dump(fg, f, ensure_ascii=False)

    # videos
    q = VIDEO_QUERIES[track].replace(' ', '+')
    vids = [{
        'subject': '공통',
        'title': f'{meta["name"]} 무료강의 추천 채널',
        'channel': '유튜브',
        'url': f'https://www.youtube.com/results?search_query={q}',
        'desc': f'{meta["name"]} 수험생을 위한 무료 이론/기출풀이 강의 모음.',
    }]
    for subj in meta['subjects']:
        sq = f'{VIDEO_QUERIES[track].split()[0]}+{subj}'.replace(' ', '+')
        vids.append({
            'subject': subj,
            'title': f'{subj} 핵심이론 강의 검색',
            'channel': '유튜브',
            'url': f'https://www.youtube.com/results?search_query={sq}',
            'desc': f'{subj} 과목 무료 강의 검색 바로가기.',
        })
    with open(f'{out}/videos.json', 'w', encoding='utf-8') as f:
        json.dump(vids, f, ensure_ascii=False)

    # study_guide
    sg = {
        'title': f'{meta["name"]} 합격 공부법 — 실전 전략 가이드',
        'intro': f'{meta["name"]} 필기 {n_exams}회차 실기출({total_q}문항) 빈출 분석과 '
                 '합격자 학습 패턴을 종합한 전략 가이드입니다.',
        'exam_data_note': {
            'title': '이 앱 기출 데이터의 신뢰도',
            'body': f'본 앱은 {meta["name"]} 필기 실기출 {n_exams}회차 {total_q}문항을 '
                    '수록했습니다. 법규·기준 과목은 최신 개정 여부를 Q-net 공고로 '
                    '함께 확인하세요.',
        },
        'order': [
            {'label': f'{i + 1}순위', 'name': s,
             'reason': ('공통 기초 과목 — 먼저 끝내면 뒤 과목이 쉬워집니다'
                        if i == 0 else
                        '순수 암기 과목 — 시험 직전 배치가 유리합니다'
                        if i == len(meta['subjects']) - 1 else
                        '빈출 토픽 위주로 회독 수를 늘리는 과목입니다')}
            for i, s in enumerate(meta['subjects'])
        ],
        'subjects': [
            {'name': s,
             'major': '기출 반복 문항부터 — 회당 출제 비중 높은 토픽 우선',
             'non_major': '이론 1회독 후 바로 기출로 전환 — 기출이 곧 교과서',
             'method': '본 앱 1:1 강의노트 → 토픽별 문제풀이 → 오답노트 순환'}
            for s in meta['subjects']
        ],
        'principles': [
            {'title': '기출 반복이 전부다',
             'body': f'{n_exams}회차 기출에서 동일 문항이 그대로 반복 출제됩니다. '
                     f'본 앱 반복기출 {len(repeats)}문항은 무조건 암기하세요.'},
            {'title': '과락(40점) 회피 우선',
             'body': '평균 60점보다 무서운 게 과락입니다. 가장 약한 과목에 '
                     '학습 시간의 30%를 배정하세요.'},
            {'title': '3회독 원칙',
             'body': '1회독 이론+기출, 2회독 오답 중심, 3회독 반복기출·암기카드 '
                     '최종 점검 순으로 회독하세요.'},
        ],
        'period': {
            'title': '권장 학습 기간',
            'items': [
                {'label': '전공자·유경험자', 'body': '2~3주 (하루 2시간)'},
                {'label': '비전공 초심자', 'body': '4~6주 (하루 2~3시간)'},
            ],
        },
    }
    with open(f'{out}/study_guide.json', 'w', encoding='utf-8') as f:
        json.dump(sg, f, ensure_ascii=False)

    return meta, exams, n_exams, total_q, cnt, repeats, rules, rep_by_topic


def build_plan_and_extras(track):
    """study_plan / theory_slides / exam_info / silgi / theory md 생성."""
    (meta, exams, n_exams, total_q, cnt, repeats, rules,
     rep_by_topic) = build_all(track)
    out = f'{APP}/backend/data/study/{track}'
    theory_dir = f'{APP}/backend/data/theory/{track}'

    # study_plan (30일)
    subj_n = len(meta['subjects'])
    top_by_subj = {}
    for subj in meta['subjects']:
        ts = sorted([(t, c) for (s, t), c in cnt.items() if s == subj],
                    key=lambda x: -x[1])
        top_by_subj[subj] = [t for t, _ in ts]
    study_days = 24
    per_subj = max(1, study_days // subj_n)
    days = []
    day_no = 1
    for subj in meta['subjects']:
        tops = top_by_subj[subj]
        chunk = max(1, (len(tops) + per_subj - 1) // per_subj)
        for i in range(per_subj):
            focus = tops[i * chunk:(i + 1) * chunk]
            days.append({
                'day': day_no,
                'subject': subj,
                'title': f'{subj} {i + 1}일차',
                'tasks': ([f'1:1 강의노트: {", ".join(focus)}' if focus
                           else f'{subj} 전체 복습'] +
                          ['해당 토픽 빈출문제 풀기', '오답노트 정리',
                           f'암기카드 복습 ({subj})']),
            })
            day_no += 1
    finals = ['전과목 반복기출 1차 점검', '오답노트 전체 회독',
              '모의고사 1회분 실전 풀이', '모의고사 오답 분석',
              '암기카드·공식 최종 점검', '전과목 반복기출 최종 점검',
              '컨디션 조절 + 약점 토픽 마무리']
    start = day_no
    for i in range(day_no, 31):
        days.append({'day': i, 'subject': '종합',
                     'title': f'마무리 {i - start + 1}일차',
                     'tasks': [finals[min(i - start, len(finals) - 1)]]})
    sp = {
        'title': f'{meta["name"]} 30일 합격 플랜',
        'description': f'실기출 {total_q}문항 빈출 분석 기반 30일 커리큘럼. '
                       '하루 2~3시간 기준.',
        'strategy': meta['strategy'],
        'days': days,
    }
    with open(f'{out}/study_plan.json', 'w', encoding='utf-8') as f:
        json.dump(sp, f, ensure_ascii=False)

    # theory_slides
    decks = []
    for d in days[:study_days]:
        subj = d['subject']
        first_task = d['tasks'][0]
        topics_in_day = (first_task.split(': ', 1)[1].split(', ')
                         if ': ' in first_task else [])
        cards = [{
            'type': 'mission', 'topic': subj,
            'title': f'Day {d["day"]} 미션 — {subj}',
            'body': '\n'.join(f'✅ {t}' for t in d['tasks']),
        }]
        for tp in topics_in_day[:3]:
            kws = {t: k for t, k in rules.get(subj, [])}.get(tp, [])
            reps = rep_by_topic.get((subj, tp), [])[:1]
            body = (f'핵심 키워드: {", ".join(kws[:6])}' if kws
                    else f'{tp} 핵심 개념을 강의노트에서 확인하세요.')
            if reps:
                body += (f'\n\n기출 반복: {reps[0]["question"][:70]}… '
                         f'→ 정답 {reps[0]["answer_text"]}')
            cards.append({'type': 'concept', 'topic': tp,
                          'title': tp, 'body': body})
        decks.append({'day': d['day'], 'subject': subj,
                      'title': d['title'], 'phase': '이론+문제', 'cards': cards})
    with open(f'{out}/theory_slides.json', 'w', encoding='utf-8') as f:
        json.dump(decks, f, ensure_ascii=False)

    # exam_info_2026
    ei = {
        'updated': '2026-01',
        'sources': ['Q-net 국가자격 시험정보'],
        'schedule': [
            {'round': '2026년 1회', 'apply': '2026.01',
             'written': '2026.02~03', 'practical': '2026.04~05'},
            {'round': '2026년 2회', 'apply': '2026.04',
             'written': '2026.05~06', 'practical': '2026.07~08'},
            {'round': '2026년 3회', 'apply': '2026.07',
             'written': '2026.08~09', 'practical': '2026.10~11'},
        ],
        'qnetLinks': [
            {'name': 'Q-net 원서접수', 'url': 'https://www.q-net.or.kr'},
            {'name': '큐넷 시험일정 공고',
             'url': 'https://www.q-net.or.kr/crf005.do?id=crf00505'},
        ],
        'relatedCerts': [],
        'scheduleNotes': ['정확한 접수·시험일은 매년 12월 Q-net 공고 기준으로 확인하세요.'],
        'criteria2026': {
            'written': '과목당 40점 이상, 전과목 평균 60점 이상',
            'practical': '60점 이상',
        },
        'passRates': [],
        'passRateInsights': [
            f'{meta["name"]} 필기는 기출 반복률이 높아 기출 3회독이면 합격권입니다.',
        ],
        'passRates2025': [],
    }
    with open(f'{out}/exam_info_2026.json', 'w', encoding='utf-8') as f:
        json.dump(ei, f, ensure_ascii=False)

    # silgi
    silgi = {
        'title': meta['silgi_title'],
        'overview': meta['silgi_overview'],
        'strategy': meta['strategy'],
        'items': [],
    }
    with open(f'{out}/silgi.json', 'w', encoding='utf-8') as f:
        json.dump(silgi, f, ensure_ascii=False)

    # theory md
    for i, subj in enumerate(meta['subjects'], 1):
        ts = sorted([(t, c) for (s, t), c in cnt.items() if s == subj],
                    key=lambda x: -x[1])
        subj_total = sum(c for _, c in ts)
        md = [f'# {meta["name"]} 필기 이론서 — {subj}', '',
              f'> **데이터 기반**: comcbt.com 실기출 {n_exams}회차 분석 반영',
              f'> **과목 출제**: 총 {subj_total}문항 분석', '',
              f'## 📊 기출 빈출도 랭킹 (총 {subj_total}문항 분석)', '',
              '| 순위 | 주제 | 출제수 | 회당 평균 | 중요도 |',
              '|---|---|---|---|---|']
        mx = ts[0][1] if ts else 1
        for rank, (t, c) in enumerate(ts, 1):
            stars = '★' * max(1, min(5, round(5 * c / mx)))
            md.append(f'| {rank} | {t} | {c} | {c / n_exams:.1f} | {stars} |')
        top3 = [t for t, _ in ts[:3]]
        md += ['', f'**전략**: 상위 토픽({", ".join(top3)})만 완벽히 해도 '
                   '과락 없이 안정권입니다.', '', '---', '']
        kw_map = {t: k for t, k in rules.get(subj, [])}
        for rank, (t, c) in enumerate(ts, 1):
            md += [f'# 제{rank}장 {t}', '',
                   f'{n_exams}회차 기출에서 **{c}문항** 출제된 토픽입니다.', '']
            kws = kw_map.get(t, [])
            if kws:
                md += ['## 핵심 키워드', '']
                md += [f'- **{k}**' for k in kws]
                md.append('')
            reps = rep_by_topic.get((subj, t), [])[:4]
            if reps:
                md += ['## 기출 반복 포인트', '']
                for r in reps:
                    md += [f'**Q. {r["question"]}**', '',
                           f'→ 정답: **{r["answer_text"]}** ({r["count"]}회 출제)', '']
            fl = [fx for fx in FORMULAS.get(track, []) if fx[2] == subj]
            if rank == 1 and fl:
                md += ['## 필수 공식', '']
                for nm, ex, _, ds in fl:
                    md += [f'- **{nm}**: `{ex}` — {ds}']
                md.append('')
            md += ['---', '']
        with open(f'{theory_dir}/{i:02d}.md', 'w', encoding='utf-8') as f:
            f.write('\n'.join(md))

    n_lessons = len(json.load(open(f'{out}/lessons.json', encoding='utf-8')))
    return {'lessons': n_lessons, 'repeats': len(repeats),
            'theory_files': len(meta['subjects'])}


if __name__ == '__main__':
    tracks = sys.argv[1:] or list(META.keys())
    for tr in tracks:
        r = build_plan_and_extras(tr)
        print(f'{tr}: lessons {r["lessons"]}, repeats {r["repeats"]}, '
              f'theory md {r["theory_files"]}')
