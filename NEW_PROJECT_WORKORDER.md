# NEW_PROJECT_WORKORDER.md — 중·고 교과 학습앱 "EduQuest" 작업지시서 (v1.0)

> **문서 지위: 신규 프로젝트의 최우선(1순위) 규범 문서.**
> 본 문서는 기존 **Cert Study Tracker(전기기사)** 앱을 **원본 템플릿**으로 삼아,
> 중·고등학교 **수학/영어/과학/역사** 4과목 학습앱을 **동일 수준으로 한 번에** 구축하기 위한
> 완전 작업지시서다. 세션이 끊겨도 이 문서만 읽으면 어느 단계든 즉시 재개 가능해야 한다.
> 원본 앱(전기기사)은 **절대 수정하지 않는다** — 신규 프로젝트는 별도 디렉터리에 생성한다.

- 신규 프로젝트: **EduQuest — 중·고 교과 마스터** (가칭, generate_app_info로 확정)
- 신규 경로: `/home/user/flutter_app/` (새 샌드박스) — 원본 백업 tar.gz를 복원 후 개조
- 원본 템플릿: Cert Study Tracker 커밋 `8323025` (analyze 0 issue, 46 dart 파일)
- 버전 고정: Flutter **3.35.4** / Dart **3.9.2** — 업그레이드 금지

---

## §0. 원본 템플릿 확보 (신규 세션 첫 행동)

1. 원본 프로젝트의 최신 ProjectBackup tar.gz를 확보한다(사용자에게 URL 요청 또는 SB-Git repo clone).
2. `/home/user/`에 압축 해제 → `flutter_app/` 복원 → `flutter pub get` → `flutter analyze` 0 issue 확인.
3. **원본 콘텐츠 제거 전 금지사항**: lib/ 엔진 코드를 먼저 건드리지 말 것. 콘텐츠(JSON)와 도메인 용어부터 교체한다.

---

## §1. 오케스트레이터 프로토콜 (원본 MASTER_PLAN §1 승계 — 동일 적용)

서브에이전트 편성: A0 Inspector → A1 Researcher → A2 Architect → A3 Implementer → A4 Verifier → A5 Archivist.

**불변 규칙 (HARD RULES)**
1. 모든 태스크 종료 시 커밋 + ProjectBackup + curl 다운로드 명령 제공.
2. `flutter analyze` 0 issue + `flutter build web --release` 성공 없이 태스크 완료 처리 금지.
3. `print()` 금지 → `kDebugMode`+`debugPrint`; `withOpacity()` 금지 → `withValues(alpha:)`.
4. 스펙에 없는 파일 임의 생성 금지. 생성 시 §5 아키텍처 맵에 즉시 반영.
5. 서버 재기동: `flutter build web --release` 후 `python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 &`.
6. XP 공식 변경 금지: 학습 1분=2XP, 정답 1개=5XP, 레벨 임계 `(n-1)²×120`, 칭호 6단계.

---

## §2. 제품 비전

**"중·고생이 매일 열고 싶어지는 마법 학습 앱"**
- 핵심 루프(원본 검증 완료): **개념 렛슨 → 문제풀이 → 자동채점 → 해설 → 오답 자동 축적 → SRS 복습**.
- 차별화 축(원본 승계): ① 완전 무료·오프라인(Hive) ② 게이미피케이션(XP/레벨/스트릭/방패/배지/리그) ③ 데이터 코칭(히트맵·주간리포트·성취 예측).
- 신규 축: ④ **학교급·학년·과목 선택형 커리큘럼** (2022 개정 교육과정 기반, 2025~ 순차 적용).

---

## §3. 엔진 이식 맵 (원본 → 신규, 파일 단위 지시)

> 원칙: **"엔진은 무수정 이식, 콘텐츠 계층만 교체"**. 아래 표의 판정을 엄수한다.

| 원본 파일 | 판정 | 지시 |
|---|---|---|
| `main.dart` (5탭 셸) | ✅ 그대로 | 앱명/타이틀 문자열만 교체 |
| `theme/app_theme.dart` | ✅ 그대로 | 디자인 토큰 유지(primary #4F46E5, accent #7C3AED, electric #06B6D4). 과목 4색만 추가: 수학 #4F46E5 / 영어 #059669 / 과학 #0EA5E9 / 역사 #D97706 |
| `providers/app_provider.dart` | 🔧 소폭 수정 | Hive 박스 4종·타이머·스트릭·방패·XP 게터 유지. **신규**: `schoolLevel`(중/고), `grade`(1~3), `selectedSubjects`(List) — settings 박스 저장 |
| `services/flashcard_srs.dart` (Leitner 6박스) | ✅ 무수정 | qid 체계만 신규 스키마(§4)에 맞춤 |
| `services/progress_service.dart` | ✅ 무수정 | |
| `services/pass_prediction.dart` | 🔧 용어 교체 | "합격 예측"→"목표 달성 예측", 과락 개념→"취약 과목 경보"(40% 미만 정답률) |
| `services/score_history.dart` / `dday_planner.dart` / `slide_progress.dart` | ✅ 무수정 | |
| `services/study_data.dart` | 🔧 핵심 수정 | `kSubjects` 하드코딩 제거 → `curriculum.json` 트리 로더 신설(§4). Question/Lesson 클래스는 **필드 무변경** 재사용 |
| `services/cerebras_service.dart` (AI 해설) | ✅ 무수정 | 프롬프트의 "전기기사"만 "중·고 교과"로 |
| `screens/study/quiz_play_screen.dart` (903줄, CBT 번호판·북마크·채점) | ✅ 무수정 | 문항 스키마 동일하므로 즉시 작동 |
| `screens/study/smart_review_screen.dart` / `flashcard_screen.dart` | ✅ 무수정 | |
| `screens/study/study_screen.dart` (4탭 허브) | 🔧 재구성 | 진입 구조를 "과목 그리드 → 단원 트리 → 렛슨+퀴즈"로(§6-T2) |
| `screens/home_screen.dart` | 🔧 재배치 | 카드 순서: 긴급복습(SRS)→일일미션→과목별 진도 링→리그 스트립(§6-T4) |
| `screens/exams_screen.dart` | 🔧 전환 | Qnet 배너 제거 → "학교 시험(중간/기말) 범위 설정" D-Day 카드로 |
| `screens/timer_screen.dart` / `stats_screen.dart` | ✅ 그대로 | 과목 라벨 소스만 curriculum 트리로 |
| `screens/onboarding_screen.dart` | 🔧 확장 | 3페이지→4페이지: **①학교급·학년 선택 ②과목 선택(복수) ③시험일 ④루프 안내** |
| `widgets/` 15종 (magic_effects, daily_mission_card, badge_collection, level_up_dialog, study_heatmap, weekly_report_card, weekly_league_card 등) | ✅ 전부 무수정 | 디자인 시스템(PremiumCard/SectionHeader/IconBadge/PillBadge) 그대로 |
| `assets/data/*.json` (전기기사 12종) | ❌ 삭제 | §4 신규 콘텐츠로 전면 교체 |
| `assets/tutor/pose_*.png` | ✅ 유지 | 튜터 아바타 재사용 |
| MASTER_PLAN.md | 🔧 개정 | 본 지시서를 신규 바이블 v1.0으로 승격 |

---

## §4. 데이터 스키마 (원본 100% 호환 — 필드명 변경 절대 금지)

### 4.1 curriculum.json (신규 — 트리의 단일 진실 원천)
```json
{
  "levels": [
    {
      "id": "middle", "label": "중학교",
      "grades": [
        {
          "grade": 1, "label": "중1",
          "subjects": [
            {
              "id": "math_m1", "name": "수학", "color": "#4F46E5", "icon": "calculate",
              "units": [
                {"unit": "수와 연산", "topics": ["소인수분해", "정수와 유리수", "..."]},
                {"unit": "문자와 식", "topics": ["..."]}
              ],
              "data_file": "assets/data/subjects/math_m1.json"
            }
          ]
        }
      ]
    },
    {"id": "high", "label": "고등학교", "grades": ["공통수학1·2, 통합과학1·2, 공통영어1·2, 한국사1·2 ..."]}
  ]
}
```

### 4.2 과목 데이터 파일 (subjects/*.json — 원본 exams.json+lessons.json 통합형)
```json
{
  "subject": "수학", "level": "middle", "grade": 1,
  "lessons": [ Lesson 스키마 그대로: subject/topic/freq/importance/intro/sections/formulas/mnemonics/strategy/traps ],
  "question_sets": [
    {
      "id": "math_m1_u1", "label": "중1 수학 · 수와 연산", "unit": "수와 연산",
      "questions": [ Question 스키마 그대로: no/subject/topic/question/options(4지선다)/answer(1-based)/has_image/explanation/difficulty/freq_score ]
    }
  ]
}
```

**호환 규칙**: `Question.qid = '$examLabel|$subject|$no'` 체계 유지 → `examLabel`에 `question_sets[].label`을 주입하면 오답노트·북마크·SRS가 무수정 작동한다.

### 4.3 콘텐츠 볼륨 목표 (원본 수준 = 2,897문항 급)
| 과목 | 중학교(학년별) | 고등학교 | 최소 문항 | 렛슨 |
|---|---|---|---|---|
| 수학 | 중1·2·3 × 5영역 | 공통수학1·2 | 600 | 30 |
| 영어 | 중1·2·3 (어휘/문법/독해) | 공통영어1·2 | 600 | 24 |
| 과학 | 과학1·2·3 (물·화·생·지) | 통합과학1·2 | 600 | 30 |
| 역사 | 역사①(세계사)·역사②(한국사) | 한국사1·2 | 500 | 26 |
| **합계** | | | **≥2,300** | **≥110** |

문항 품질 기준(원본 승계): 4지선다, 해설은 `✅ 정답 N번:` 시작 + `📘 개념:` 블록 포함, difficulty 1~3 배분(하30/중50/상20%), 모든 문항 explanation 100% 필수.

---

## §5. 멀티(병렬) 자료 수집 매트릭스 — A1 Researcher 동시 실행 지시

> **핵심 지시: 아래 리서치 배치를 한 턴에 동시(멀티) 호출한다.**
> web_search는 독립 호출이므로 **한 응답 블록에 4~6개씩 병렬 발사** → 결과를 과목별 리서치 노트로 병합.

### 배치 R1 — 교육과정 골격 (4건 동시)
| # | 쿼리 |
|---|---|
| R1-1 | `2022 개정 교육과정 중학교 수학 1 2 3학년 단원 목차 성취기준` |
| R1-2 | `2022 개정 교육과정 공통수학1 공통수학2 단원 목차 다항식 도형의 방정식` |
| R1-3 | `2022 개정 교육과정 중학교 영어 성취기준 문법 요소 어휘 수준` |
| R1-4 | `2022 개정 교육과정 공통영어1 공통영어2 내용 체계` |

### 배치 R2 — 과학·역사 골격 (4건 동시)
| # | 쿼리 |
|---|---|
| R2-1 | `2022 개정 중학교 과학1 과학2 과학3 단원 목차 물리 화학 생명 지구` |
| R2-2 | `2022 개정 통합과학1 통합과학2 단원 목차 과학의 기초 물질과 규칙성` |
| R2-3 | `2022 개정 중학교 역사1 세계사 역사2 한국사 단원 목차 13영역` |
| R2-4 | `2022 개정 고등학교 한국사1 전근대 한국사2 근현대 단원 목차` |

### 배치 R3 — 기출·평가 유형 (4건 동시)
| # | 쿼리 |
|---|---|
| R3-1 | `중학교 수학 중간고사 기출 유형 빈출 문제 단원별` |
| R3-2 | `고1 공통수학 내신 빈출 유형 오답률 높은 문제` |
| R3-3 | `중학교 과학 시험 단골 문제 개념 오개념` |
| R3-4 | `한국사 내신 수능 빈출 주제 순서 연표 암기법` |

### 배치 R4 — 학습법·경쟁앱 (4건 동시)
| # | 쿼리 |
|---|---|
| R4-1 | `중고등 학습앱 콴다 매쓰플랫 클래스카드 기능 비교` |
| R4-2 | `영단어 암기앱 SRS 간격반복 중학 필수 영단어 1200` |
| R4-3 | `과학 개념 학습 앱 오개념 교정 UX` |
| R4-4 | `역사 연표 암기 앱 스토리텔링 학습법` |

**수집 후 처리 지시**: 각 배치 결과를 `docs/research/R{n}_notes.md`로 저장 → 커리큘럼 트리(curriculum.json)를 먼저 확정 → 과목 데이터 파일을 **과목 단위로 병렬 생성**(한 턴에 수학+과학 / 다음 턴 영어+역사 식으로 2과목씩 Write 병렬).

**콘텐츠 생성 지시(중요)**: 문항·렛슨 본문은 리서치로 확인된 교육과정 단원·성취기준에 근거해 **직접 저작**한다(교과서 원문 복제 금지 — 저작권). 원본 앱의 lessons.json 문체(intro→sections→formulas→mnemonics→strategy→traps)를 그대로 따른다.

---

## §6. 태스크 로드맵 (각 태스크 = A0→A5 완주 + 커밋 + 백업)

### T1. 부트스트랩 (1턴)
- 원본 tar.gz 복원 → generate_app_info(신규 앱명/패키지) → 전기기사 JSON 12종 삭제 → curriculum.json 뼈대 생성 → analyze 0 issue 유지 상태로 커밋.
- **완료 기준**: 빈 커리큘럼으로도 앱이 크래시 없이 기동(빈 상태 UI는 원본 shrink 패턴 재사용).

### T2. 커리큘럼 내비게이션 (1턴)
- study_screen 재구성: 탭1 `과목`(4색 그리드 카드: 이름/아이콘/진도율 링) → 과목 탭 시 단원 트리(ExpansionTile, 원본 collapsedShape 보정 패턴) → 소단원 행에 [렛슨 보기 | 문제풀이 | 플래시카드] 3버튼.
- 탭2 `문제풀이`(단원 랜덤/빈출/난이도), 탭3 `모의고사`(학년 범위 30문항 자동 조합 + CBT 번호판), 탭4 `이력`(원본 무수정).
- onboarding 4페이지 확장 + AppProvider에 schoolLevel/grade/selectedSubjects.
- **완료 기준**: 중/고 전환 시 과목 그리드·단원 트리가 curriculum.json만으로 렌더.

### T3. 콘텐츠 대량 생산 — 병렬 2과목×2턴 (§5 매트릭스 가동)
- T3a: 배치 R1+R3 발사 → **수학(중1~고1) + 과학(중1~통합과학)** 데이터 파일 생성 (~1,200문항, 렛슨 60).
- T3b: 배치 R2+R4 발사 → **영어 + 역사** 데이터 파일 생성 (~1,100문항, 렛슨 50).
- 각 턴: 생성 즉시 quiz_play로 스모크 테스트(임의 20문항 풀이·채점·해설 표시).
- **완료 기준**: §4.3 볼륨 달성, explanation 100%, JSON 파싱 오류 0.

### T4. 홈·시험·통계 도메인 전환 (1턴)
- 홈: 긴급복습→미션→**과목별 진도 링 4개**→리그. 시험탭: 중간/기말 D-Day+범위(단원 멀티셀렉트)→범위 기반 모의고사 연결. 용어 전수 교체(합격→목표달성, 과락→취약과목).
- **완료 기준**: 전기기사 문자열 grep 결과 0건.

### T5. 검증·릴리즈 (1턴)
- analyze 0 → build web → 서빙 바이트 대조 → 신규 앱아이콘 생성(image_generation)·통합 → APK(flutter_signing_tool, 패키지명 일치 검증 선행) → 최종 ProjectBackup.

---

## §7. 검증 체인 (원본 §8 승계)
```bash
cd /home/user/flutter_app && flutter analyze              # 0 issue 필수
flutter build web --release                                # ✓ Built
lsof -ti:5060 | xargs -r kill -9; python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 &
curl -s localhost:5060/main.dart.js | wc -c                # == build/web/main.dart.js 크기
python3 - <<'EOF'                                          # 콘텐츠 무결성 게이트
import json,glob
for f in glob.glob('assets/data/subjects/*.json'):
    d=json.load(open(f)); qs=[q for s in d['question_sets'] for q in s['questions']]
    assert all(q.get('explanation') for q in qs), f
    assert all(len(q['options'])==4 and 1<=q['answer']<=4 for q in qs), f
    print(f, len(qs), 'OK')
EOF
```

## §8. 변경이력 (Archivist 갱신 — 재개 시 여기부터 읽기)
| 일자 | 커밋 | 내용 | 백업 |
|---|---|---|---|
| - | - | (T1부터 기록) | - |
