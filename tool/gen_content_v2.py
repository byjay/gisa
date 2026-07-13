# -*- coding: utf-8 -*-
"""신규 트랙 formula_guide / mnemonics / lessons 실제 콘텐츠 격상."""
import json, os

BASE = os.path.join(os.path.dirname(__file__), '..', 'assets')

# ══════════ 전기공사기사 ══════════
EC_FORMULAS = [
 dict(name='광속법 조명설계', expr='F = E·A·D / (U·N)', subject='전기응용 및 공사재료',
  desc='F: 광원 1개 광속[lm], E: 조도[lx], A: 면적[m²], D: 감광보상률(=1/유지율M), U: 조명률, N: 등수. 등수 계산 최빈출.'),
 dict(name='완전확산면 휘도', expr='R = πB', subject='전기응용 및 공사재료',
  desc='광속발산도 R[rlx]와 휘도 B[cd/m²]의 관계. 완전확산면에서만 성립.'),
 dict(name='권상기 소요출력', expr='P = W·V / (6.12η) [kW]', subject='전기응용 및 공사재료',
  desc='W: 하중[ton], V: 속도[m/min], η: 효율. 양수펌프 P=9.8QH/η와 함께 암기.'),
 dict(name='패러데이 전기분해', expr='W = kIt [g]', subject='전기응용 및 공사재료',
  desc='석출량은 전기량(It)에 비례, k는 전기화학당량[g/C].'),
 dict(name='송전전력', expr='P = (V_s·V_r / X)·sinδ', subject='전력공학',
  desc='V_s, V_r: 송·수전단 전압, X: 리액턴스, δ: 상차각. 안정도 문제의 기본식.'),
 dict(name='%임피던스와 단락전류', expr='I_s = (100/%Z)·I_n', subject='전력공학',
  desc='단락전류는 %Z에 반비례. 단락용량 P_s = (100/%Z)·P_n 도 세트.'),
 dict(name='변압기 전압변동률', expr='ε = p·cosθ + q·sinθ [%]', subject='전기기기',
  desc='p: %저항강하, q: %리액턴스강하. 최대 전압변동률은 √(p²+q²).'),
 dict(name='유도전동기 슬립', expr='s = (Ns - N) / Ns', subject='전기기기',
  desc='Ns = 120f/P [rpm]. 2차 동손 P_c2 = s·P_2 (2차 입력의 s배).'),
 dict(name='RLC 직렬 공진주파수', expr='f₀ = 1 / (2π√LC)', subject='회로이론 및 제어공학',
  desc='공진 시 Z=R(최소), 전류 최대, 역률 1. 선택도 Q = ωL/R = 1/(ωCR).'),
 dict(name='저압 절연저항(KEC)', expr='FELV·500V 이하 1.0MΩ / SELV·PELV 0.5MΩ', subject='전기설비기술기준',
  desc='측정전압: 1.0MΩ은 DC 500V, 0.5MΩ은 DC 250V. 시험 최빈출 수치.'),
]
EC_MNEMONICS = [
 dict(subject='전기응용 및 공사재료', title='측광량 단위 세트', body='광속 lm / 광도 cd / 조도 lx / 휘도 cd·m⁻²(nt) / 광속발산도 rlx', tip='"속루멘·도칸델라·조럭스·휘니트" 리듬으로 암기'),
 dict(subject='전기응용 및 공사재료', title='가열 방식 구분', body='유도가열=와전류+히스테리시스(금속 표면담금질) / 유전가열=유전체손(목재건조·비닐접착·전자레인지)', tip='유도→도체, 유전→절연물'),
 dict(subject='전기응용 및 공사재료', title='축전지 공칭전압', body='납(연)축전지 2.0V/셀·방전종지 1.8V / 알칼리 1.2V/셀', tip='"연이(2.0)는 알one점two(1.2)"'),
 dict(subject='전기응용 및 공사재료', title='열전 3효과', body='제베크=온도차→기전력(열전온도계) / 펠티에=전류→열 흡수·발생(전자냉동) / 톰슨=동일금속 온도차 부분 발열·흡열', tip='제-온도계, 펠-냉장고, 톰-단일금속'),
 dict(subject='전기응용 및 공사재료', title='전선 도전율 순서', body='연동선 100% > 경동선 97% > 알루미늄 61%', tip='"연백·경구칠·알육일"'),
 dict(subject='전기응용 및 공사재료', title='금속관 두께', body='콘크리트 매설 1.2mm 이상, 기타 1.0mm 이상', tip='"매설은 일점이"'),
 dict(subject='전력공학', title='애자 구비조건', body='절연내력 大·기계강도 大·정전용량 小·온습 변화에 강할 것', tip='"용량만 작게" 함정 주의'),
 dict(subject='전력공학', title='중성점 접지 비교', body='직접접지=이상전압 小·지락전류 大·통신유도장해 大 / 소호리액터=지락전류 최소·계속운전 가능', tip='직접은 전위 안정, 소호는 전류 소멸'),
 dict(subject='전기기기', title='변압기 병렬운전 조건', body='극성·권수비(전압)·%Z 같을 것, 3상은 상회전·각변위까지 일치', tip='"극·비·임(+상·각)"'),
 dict(subject='전기기기', title='직류전동기 속도·토크', body='N = (V - Ia·Ra)/kΦ, T = kΦIa — 분권: 속도 일정 / 직권: 기동토크 大(무부하 위험)', tip='직권 벨트 운전 금지!'),
 dict(subject='회로이론 및 제어공학', title='정현파 값 관계', body='최대값 = √2×실효값, 평균값 = (2/π)×최대값, 파형률 1.11, 파고율 1.414', tip='"루트2 올리고, 2/π 내리고"'),
 dict(subject='회로이론 및 제어공학', title='Y-Δ 변환 전압·전류', body='Y: 선간전압=√3상전압 / Δ: 선전류=√3상전류. Δ→Y 임피던스 1/3배', tip='"Y는 전압에, Δ는 전류에 √3"'),
 dict(subject='전기설비기술기준', title='절연저항 기준(KEC)', body='SELV·PELV 0.5MΩ(250V) / FELV·500V이하 1.0MΩ(500V) / 500V초과 1.0MΩ(1000V)', tip='"저압은 1메가, 특별저압만 0.5"'),
 dict(subject='전기설비기술기준', title='접지도체 최소 단면적', body='구리 6mm²(큰 고장전류 16mm²), 알루미늄 16mm², 철제 50mm²', tip='"구6·알16·철50"'),
]

# ══════════ 소방설비기사(전기) ══════════
FE_FORMULAS = [
 dict(name='스테판-볼츠만 법칙', expr='E = σT⁴', subject='소방원론',
  desc='복사에너지는 절대온도 4제곱에 비례. 최성기 열전달·플래시오버 메커니즘의 근거.'),
 dict(name='연기 이동속도', expr='수평 0.5~1 m/s, 수직 2~3 m/s', subject='소방원론',
  desc='계단실 수직 이동이 보행속도(1.3m/s)보다 빨라 고층 피난 위험 요인.'),
 dict(name='동기속도', expr='Ns = 120f / P [rpm]', subject='소방전기일반',
  desc='소방펌프용 유도전동기 계산 기초. 슬립 s=(Ns-N)/Ns.'),
 dict(name='콘덴서·코일 에너지', expr='W_C = ½CV², W_L = ½LI²', subject='소방전기일반',
  desc='비상전원·축전지 회로 계산에 활용되는 기본 에너지 공식 쌍.'),
 dict(name='직렬 공진', expr='f₀ = 1/(2π√LC), 공진 시 Z=R·역률1', subject='소방전기일반',
  desc='RLC 직렬 공진: 임피던스 최소·전류 최대·전압 전류 동상.'),
 dict(name='배율기·분류기', expr='배율기 m=1+Rm/Rv (직렬) / 분류기 m=1+Ra/Rs (병렬)', subject='소방전기일반',
  desc='"배직분병" — 전압계 확장은 직렬 배율기, 전류계 확장은 병렬 분류기.'),
 dict(name='임시 저장·취급 기간', expr='지정수량 이상 임시 = 90일 이내 (소방서장 승인)', subject='소방관계법규',
  desc='최빈출 숫자. 지정수량 미만은 시·도 조례.'),
 dict(name='선임·신고 기한', expr='소방안전관리자: 선임 30일, 신고 14일', subject='소방관계법규',
  desc='사유 발생일부터 30일 이내 선임, 선임일부터 14일 이내 신고.'),
 dict(name='자탐 경계구역', expr='면적 ≤ 600m², 한 변 ≤ 50m (내부 전체 보이면 1,000m²)', subject='소방전기시설의 구조 및 원리',
  desc='제연구역(1,000m²·직경 60m)과 숫자 혼동 주의.'),
 dict(name='축전지 용량', expr='C = (1/L)·K·I [Ah]', subject='소방전기시설의 구조 및 원리',
  desc='L: 보수율(0.8), K: 용량환산시간계수, I: 방전전류. 유도등 20분/60분 기준과 연계.'),
]
FE_MNEMONICS = [
 dict(subject='소방원론', title='화재 급수·색상', body='A일반(백) B유류(황) C전기(청) D금속(무) K주방', tip='"에이일반 비유류 씨전기 디금속"'),
 dict(subject='소방원론', title='연소 3요소+1', body='가연물·산소·점화원(+연쇄반응=4요소). 연쇄 차단=억제소화(할론·분말)', tip='"가산점, 연쇄까지 4"'),
 dict(subject='소방원론', title='인화점<연소점<발화점', body='인화점(점화원 O 최저) < 연소점(+5~10℃, 지속연소) < 발화점(점화원 X 자연발화)', tip='"인→연→발 오름차순"'),
 dict(subject='소방원론', title='분말약제 4종 세트', body='1종 NaHCO₃(백·BC) / 2종 KHCO₃(담자·BC) / 3종 인산암모늄(담홍·ABC) / 4종 KHCO₃+요소(회·BC)', tip='"삼종만 ABC, 색은 백자홍회"'),
 dict(subject='소방원론', title='목조 vs 내화 화재', body='목조=고온 단기(1,100~1,300℃) / 내화=저온 장기(800~1,000℃)', tip='"나무는 화끈 짧게, 콘크리트는 은근 길게"'),
 dict(subject='소방원론', title='주요구조부 제외', body='제외: 사잇기둥·최하층바닥·작은보·차양·옥외계단', tip='"사최작차옥"'),
 dict(subject='소방전기일반', title='플레밍 법칙', body='오른손=발전기(운동→기전력) / 왼손=전동기(전류→힘). 엄지F/검지B/중지I', tip='"오발왼전"'),
 dict(subject='소방전기일반', title='자기소호 가능 소자', body='SCR 불가(유지전류 이하로만 오프) / GTO·IGBT·TR 가능 / TRIAC 양방향', tip='"SCR은 못 끈다"'),
 dict(subject='소방전기일반', title='불대수 흡수법칙', body='A+AB=A / A+ĀB=A+B / A(A+B)=A', tip='"자기가 있으면 흡수"'),
 dict(subject='소방전기일반', title='측정 계기 매칭', body='절연저항=메거 / 저저항=켈빈더블 / 중저항=휘트스톤 / 전해액·접지=콜라우시', tip='"절메·저켈·중휘·접콜"'),
 dict(subject='소방관계법규', title='관계인·소방대상물', body='관계인=소유·관리·점유자 / 선박은 "매어둔 것"만 소방대상물', tip='"소관점 + 매어둔 배만"'),
 dict(subject='소방관계법규', title='숫자 3종 세트', body='임시취급 90일 / 선임 30일 / 신고 14일', tip='"구공·삼공·일사"'),
 dict(subject='소방관계법규', title='지정권자 구분', body='화재예방강화지구·소방력 확충계획=시·도지사 / 예방조치명령=소방관서장', tip='"지구는 도지사, 명령은 관서장"'),
 dict(subject='소방관계법규', title='제4류 지정수량', body='특수인화물 50L → 1석유(비수)200/수400 → 알코올400 → 2석유 1,000/2,000 → 3석유 2,000/4,000 → 4석유 6,000 → 동식물유 10,000', tip='"50-200-400-천-2천…" 커지는 흐름'),
 dict(subject='소방전기시설의 구조 및 원리', title='감지기 3형식', body='차동식=상승률 / 정온식=일정온도(주방, 최고온도+20℃) / 보상식=겸용', tip='"차이나면 차동, 정해지면 정온"'),
 dict(subject='소방전기시설의 구조 및 원리', title='음량 기준 3종', body='자탐 지구음향 90dB / 단독경보형 85dB / 가스누설 70dB (1m 거리)', tip='"자구단팔오가칠공"'),
 dict(subject='소방전기시설의 구조 및 원리', title='설치 높이 세트', body='발신기·비상콘센트 0.8~1.5m / 피난구유도등 1.5m 이상 / 통로유도등 1m 이하', tip='"손 닿는 건 0.8~1.5"'),
 dict(subject='소방전기시설의 구조 및 원리', title='수평거리 25m 클럽', body='발신기·지구음향장치·비상방송 확성기·비상콘센트(일반) 모두 25m', tip='"경보 계열은 다 25"'),
 dict(subject='소방전기시설의 구조 및 원리', title='유도등 비상전원', body='기본 20분 / 11층 이상 층·지하상가·지하역사 등 60분', tip='"이십 기본, 육십 특수"'),
 dict(subject='소방전기시설의 구조 및 원리', title='무선통신보조설비', body='누설동축 끝=무반사 종단저항 / 임피던스 50Ω / 4m 이내 고정', tip='"끝은 무반사, 오십옴"'),
]

# ── lessons.json 플레이스홀더 공식 → 실제 공식 교체 ──
TOPIC_FORMULA = {
 '조명설계·광원': ('광속법', 'F = E·A·D/(U·N)', '조도 E, 면적 A, 감광보상률 D, 조명률 U, 등수 N'),
 '전열·전기화학': ('패러데이 법칙', 'W = kIt', '석출량은 전기량에 비례, k: 전기화학당량'),
 '전동기 응용': ('권상기 출력', 'P = WV/(6.12η) [kW]', 'W[ton], V[m/min], η: 효율'),
 '전선·케이블 재료': ('도전율 순서', '연동 100% > 경동 97% > Al 61%', '표준연동선 기준 상대 도전율'),
 '배관·배선재료': ('금속관 두께', '매설 1.2mm / 기타 1.0mm 이상', 'KEC 금속관공사 기준'),
 '연소이론·화재': ('위험도', 'H = (U-L)/L', 'U: 연소상한, L: 연소하한 — 하한이 낮을수록 위험'),
 '열전달·연소생성물': ('스테판-볼츠만', 'E = σT⁴', '복사에너지는 절대온도 4제곱 비례'),
 '소화이론·약제': ('할론 명명법', 'Halon abcd = C·F·Cl·Br 개수', '1301=CF₃Br, 1211=CF₂ClBr'),
 '건축방화·피난': ('피난 원칙', 'fool-proof + fail-safe', '본능적 사용 + 이중화'),
 '위험물 성상': ('위험물 6분류', '1산고·2가고·3금수·4인액·5자기·6산액', '류별 성질 첫글자 암기'),
 '직류·교류회로': ('공진주파수', 'f₀ = 1/(2π√LC)', '직렬 공진 시 Z=R, 역률 1'),
 '전자기·정전기': ('축적 에너지', 'W = ½CV² = ½LI²', '콘덴서·코일 에너지 쌍'),
 '반도체·다이오드': ('흡수법칙', 'A + AB = A', '불대수 간소화 기본'),
 '전동기·발전기': ('동기속도', 'Ns = 120f/P', '60Hz 4극 = 1,800rpm'),
 '계측·측정': ('배율기·분류기', 'm = 1+Rm/Rv / m = 1+Ra/Rs', '배직분병'),
 '소방기본법': ('관계인', '소유자·관리자·점유자', '"소관점"'),
 '화재예방법': ('선임·신고', '선임 30일 / 신고 14일', '소방안전관리자 기한'),
 '소방시설법': ('무창층', '개구부 합계 ≤ 바닥면적 1/30', '지름 50cm 원·높이 1.2m 이내'),
 '위험물안전관리법': ('임시 취급', '90일 이내 (소방서장 승인)', '지정수량 이상 임시 저장'),
 '다중이용업소법': ('안전시설등', '소화·경보·피난설비+비상구+영상음향차단', '옥외소화전은 제외'),
 '자동화재탐지설비': ('경계구역', '≤600m², 한 변 ≤50m', '내부 전체 보이면 1,000m²'),
 '경보설비·비상방송': ('음량 기준', '지구음향 90dB@1m', '확성기 3W(실내 1W), 수평 25m'),
 '유도등·비상조명': ('비상전원', '20분 (특수 60분)', '11층 이상·지하상가 등 60분'),
 '비상전원·축전지': ('축전지 용량', 'C = (1/L)·K·I', 'L: 보수율 0.8'),
 '제연·연동제어': ('제연구역', '≤1,000m², 직경 60m 원 내', '자탐 600m²와 혼동 주의'),
}

def upgrade_lessons(track):
    p = os.path.join(BASE, 'data', track, 'lessons.json')
    lessons = json.load(open(p))
    hit = 0
    for l in lessons:
        t = l.get('topic', '')
        if t in TOPIC_FORMULA:
            name, expr, desc = TOPIC_FORMULA[t]
            l['formulas'] = [dict(name=name, expr=expr, desc=desc)]
            hit += 1
    json.dump(lessons, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{track}/lessons.json 공식 교체 {hit}건')

def write_json(track, fn, data):
    p = os.path.join(BASE, 'data', track, fn)
    json.dump(data, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{track}/{fn} 갱신')

write_json('elec_construction', 'formula_guide.json', dict(
    title='전기공사기사 공식 마스터',
    intro='전기공사기사 필기 최빈출 공식을 과목별로 정리했습니다. 공통 과목(전력·기기·회로·설비)은 전기기사와 출제 범위가 같습니다.',
    formulas=EC_FORMULAS,
    basics=[dict(term='단위 확인', desc='계산 문제는 항상 단위(ton, m/min, kW)를 먼저 맞춘다.'),
            dict(term='6.12 계열', desc='권상 6.12 / 펌프 9.8 / 송풍 102 — 분모 상수 3형제를 세트로 암기.')],
))
write_json('fire_electric', 'formula_guide.json', dict(
    title='소방설비기사(전기) 공식 마스터',
    intro='소방설비기사(전기) 필기 최빈출 공식·기준 수치를 과목별로 정리했습니다. 법규·시설 과목은 숫자 암기가 곧 점수입니다.',
    formulas=FE_FORMULAS,
    basics=[dict(term='숫자 암기 우선', desc='법규·시설은 기한(30·14·90일), 거리(25m), 음량(90dB), 시간(20/60분) 등 숫자가 답이다.'),
            dict(term='유사 숫자 대비', desc='자탐 600m²·50m vs 제연 1,000m²·60m처럼 비슷한 숫자를 짝으로 비교 암기.')],
))
write_json('elec_construction', 'mnemonics.json', EC_MNEMONICS)
write_json('fire_electric', 'mnemonics.json', FE_MNEMONICS)
upgrade_lessons('elec_construction')
upgrade_lessons('fire_electric')
print('done')
