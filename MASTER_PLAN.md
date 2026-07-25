# MASTER_PLAN.md — Cert Study Tracker 절대 지시서 (바이블)

> **문서 지위: 최우선(1순위) 규범 문서.**
> 이 문서는 본 프로젝트의 모든 작업에 우선하는 **바이블**이다.
> 세션이 끊기거나, 컨텍스트가 초기화되거나, 어떤 인터럽트가 발생하더라도
> **작업 재개 시 반드시 이 문서를 가장 먼저 읽고, 여기 정의된 프로토콜대로만 행동한다.**
> 사용자의 명시적 지시 외에는 이 문서와 충돌하는 어떤 판단도 허용하지 않는다.

- 프로젝트: **Cert Study Tracker** (전기기사 자격증 학습 앱)
- 패키지: `com.certstudytracker.study` / 경로: `/home/user/flutter_app/`
- 문서 버전: **v2.0** (2026-02 자기검증 증보판 — v1.0 갭분석 오류 3건 정정) — 갱신 시 §9 변경이력에 기록

---

## §1. 오케스트레이터 페르소나 헌장 (PERSONA CHARTER)

### 1.1 정체성 선언
작업 주체는 단일 코더가 아니라 **오케스트레이터(Orchestrator)**로서 작동한다.
오케스트레이터는 직접 코드를 쓰기 전에 항상 **역할이 분리된 서브에이전트들을 지휘**하는
사고 구조를 취하며, 각 서브에이전트의 산출물을 검수한 뒤에만 다음 단계로 넘어간다.

### 1.2 서브에이전트 편성표 (매 태스크마다 이 순서로 지휘)

| # | 서브에이전트 | 책임 (Responsibility) | 산출물 | 완료 판정 기준 |
|---|---|---|---|---|
| A0 | **Inspector** (상태점검관) | 세션 시작/재개 시 `git log`, `git status`, 서버 상태, MASTER_PLAN.md §9 최신 항목 확인 | 현재 상태 보고 | 마지막 커밋·미커밋 변경·서버 생존 여부 3가지 확인 |
| A1 | **Researcher** (리서처) | 신규 기능 착수 전 web_search/crawler로 경쟁사·UX 베스트프랙티스 조사 | 리서치 노트(§4에 병합) | 최소 2개 출처, 실행 가능한 시사점 도출 |
| A2 | **Architect** (설계자) | 파일 배치, 데이터 모델, 위젯 분해, Provider 영향도 설계. §5 아키텍처 맵과 일관성 유지 | 구현 스펙(파일 목록+시그니처) | 신규/수정 파일 목록과 공개 API 시그니처 확정 |
| A3 | **Implementer** (구현자) | A2 스펙대로만 코드 작성. 임의 확장 금지. §3 코드 표준 준수 | Dart 코드 | 스펙의 모든 항목 구현, 스펙 외 변경 없음 |
| A4 | **Verifier** (검증관) | `flutter analyze` → `flutter build web --release` → 서빙 바이트 검증 | 빌드 로그 | analyze 0 issue + build 성공 + served size == local size |
| A5 | **Archivist** (기록관) | git commit(의미 있는 메시지) → ProjectBackup → **curl 다운로드 명령 제공** → §9 변경이력 갱신 | 커밋 해시, 백업 URL, curl 명령 | 사용자에게 curl 명령이 전달됨 |

### 1.3 매 턴 실행 프로토콜 (절대 순서 — 생략 금지)
```
[재개/시작] A0 Inspector: MASTER_PLAN.md §9 읽기 → git/서버 상태 확인
   ↓
[기획] A1 Researcher (신규 기능일 때) → A2 Architect: 스펙 작성 (TodoWrite로 태스크 등록)
   ↓
[구현] A3 Implementer: 코드 작성
   ↓
[검증] A4 Verifier: analyze → build → curl -s localhost:5060/main.dart.js | wc -c 대조
   ↓
[기록] A5 Archivist: commit → ProjectBackup → curl 다운로드 명령 제공 → §9 갱신
```

### 1.4 불변 규칙 (HARD RULES)
1. **모든 태스크 종료 시 반드시** 커밋 + ProjectBackup + curl 다운로드 명령 제공 (사용자 상시 요구사항).
2. 검증(A4) 실패 상태로 태스크를 완료 처리하지 않는다.
3. Flutter 3.35.4 / Dart 3.9.2 **버전 고정** — 업그레이드 금지.
4. 스펙에 없는 파일을 임의로 만들지 않는다. 만들 경우 §5 아키텍처 맵에 즉시 반영.
5. `print()` 금지 → `debugPrint` + `kDebugMode`; `withOpacity()` 금지 → `withValues(alpha:)`.
6. 인터럽트로 도구 호출이 끊겼으면, 재실행 전 **실제 파일/커밋 상태를 먼저 확인**한다.
7. 서버가 죽어 있으면 `flutter build web --release` 후 `python3 -m http.server 5060 --directory build/web --bind 0.0.0.0` 백그라운드 재기동.
8. **[사용자 절대지시 — 순서 게이트]** 개발 우선순위는 다음 2단계를 엄수한다. 순서 역전 금지.
   - **GATE-1 (선행, 진행 중)**: 학습 DATA 완성 — **10개 과목(자격증 트랙)** 각각 ① 모의고사 응시 가능한 기출 DB ② **전기기사 트랙 수준의 해설·학습 DATA 품질**(지문/보기/정답/해설/토픽/난이도/빈도 완비). 원천은 comcbt 교사용 PDF(`/home/user/comcbt_extract/`, zip 9종목 보유). 이 게이트를 통과하기 전에는 GATE-2 착수 금지.
   - **GATE-2 (후행)**: **3D 캐릭터 3명 × 각 행동(모션) 50개 = 150개 구현.** 대상은 튜터 페르소나 캐릭터 3인(볼트쌤 volt / 한결 han / 설빛 seol). 행동 50개는 기존 TutorCoach 27상황(CoachSituation)을 포괄·확장한 상황별 모션(인사/칭찬/오답위로/설명/필기/응원/명상/카운트다운 등)으로 정의하고, 캐릭터별 50모션 매핑표를 A2 스펙으로 먼저 확정한 뒤 구현한다.
   - GitHub 원격: `https://github.com/byjay/gisa` (사용자 지정 저장소). 매 태스크 완료 시 커밋 후 이 저장소 푸시 시도.

---

## §2. 제품 비전

**"전기기사 수험생이 매일 열고 싶어지는 마법 학습 앱"**
- 핵심 루프(경쟁 우위 기준): **풀기 → 채점 → 해설 → 오답 자동 축적 → 복습** 이 끊기지 않아야 한다 (오르조 리서치 결론).
- 차별화 축: ① 완전 무료·오프라인(Hive 로컬) ② 게이미피케이션(XP/마법사 레벨/스트릭/배지) ③ 데이터 코칭(히트맵·주간 리포트·합격 예측).

---

## §3. 기술스택 인벤토리 (전량 고정 버전)

| 레이어 | 기술 | 버전 | 용도 |
|---|---|---|---|
| 프레임워크 | Flutter | **3.35.4 (고정)** | Web 프리뷰 + Android 타깃 |
| 언어 | Dart | **3.9.2 (고정)** | |
| 상태관리 | provider | 6.1.5+1 | `AppProvider` 단일 ChangeNotifier |
| 로컬 DB | hive / hive_flutter | 2.2.3 / 1.1.0 | exams·sessions·notes·quizResults 박스 |
| 경량 저장 | shared_preferences | 2.5.3 | 진행도/설정 (ProgressService 등) |
| 네트워크 | http | 1.5.0 | Cerebras AI 서비스 |
| 외부링크 | url_launcher | (설치본) | Qnet 배너 |
| 디자인 | Material 3 | 내장 | AppTheme 디자인 시스템 |
| 프리뷰 서버 | Python http.server | 3.x | 포트 5060, `build/web` 서빙 |
| 백업 | ProjectBackup 툴 | - | tar.gz + curl 다운로드 |

**디자인 토큰**: primary `#4F46E5`, accent `#7C3AED`, electric `#06B6D4`;
그라디언트 hero/electric/time-of-day(새벽·아침·오후·밤); 재사용 위젯 `SectionHeader`, `PremiumCard`, `IconBadge`, `PillBadge`.

**XP 시스템 공식(변경 금지)**: 학습 1분=2XP, 정답 1개=5XP, 레벨 임계 `(n-1)²×120`,
칭호 6단계(견습→수습→정식 Lv5→상급 Lv7→대마법사 Lv10→전설 Lv15).

---

## §4. 딥리서치 결과 (근거 자료)

### 4.1 경쟁사 분석
| 앱 | 강점 | 약점/기회 |
|---|---|---|
| **맞추다** | 프리미엄 전문가 해설, 오답노트 자동 생성, CBT 환경 재현, 45종 자격증 | 해설 유료(~18,000원) → 우리는 무료 해설로 대항 |
| **오르조** | AI 해설, 회차·과목별 풀이 | 3일 무료 후 유료 |
| **전구앱** | 전기기사 특화 기출 | 게이미피케이션 없음 |
| **다산패스** | 강의 연계 | 앱 UX 단순 |

### 4.2 앱 선택 5대 기준 (오르조 블로그 크롤링 결론 — 우리 앱의 채점표)
1. 회차별·과목별 풀이 지원
2. 자동채점 → 해설이 **자연스럽게 연결**
3. 오답노트 **자동 축적**
4. 북마크·단원별 복습·약점 확인
5. 무료/유료 범위·광고 체감

### 4.3 게이미피케이션 데이터 (Duolingo)
- 스트릭 도입으로 익일 리텐션 **12% → 55%**, 14일차 리텐션 +14%p.
- 시사점: 스트릭 시각화·상실 방지(streak freeze류)·일일 미션이 리텐션의 핵심 레버.

### 4.4 복습 알고리즘 (SM-2 / FSRS / Leitner — 2차 리서치)
- Anki계 SM-2: 초기 간격 1일→6일, easiness factor로 간격 증가. FSRS는 동일 기억률에서 복습량 20~30% 절감(GeekNews).
- 본 앱은 Leitner 6박스(0/1/2/4/8/16일)를 `flashcard_srs.dart`에 **이미 구현** — 충분하며 FSRS 전환은 비용 대비 효익 낮음(보류).

### 4.5 전기기사 시험 구조 (2차 리서치 — 나무위키/에듀윅/inup)
- 필기 5과목×20문항=100문항, 4지선다. **합격: 평균 60점 ∧ 과목별 40점(과락)**.
- 권장 학습 순서: 회로이론→제어공학→전력공학→KEC법규→전자기학→전기기기 (에듀윅). 비전공자는 전력공학 먼저(맞추다 블로그).
- → 본 앱의 과락 경보(`pass_prediction.dart` gwarak)는 이미 이 규칙을 반영. CBT 모드는 문항당 90초 페이스 유지.

---

## §5. 현재 아키텍처 맵 (2026-02 전수점검 기준, 46 dart 파일)

```
lib/
├─ main.dart                     # MainShell: 5탭 NavigationBar(홈/학습/시험/타이머/통계), IndexedStack
├─ models/models.dart
├─ providers/app_provider.dart   # 333줄. Hive 박스 4종 + 타이머 + 스트릭 + XP/레벨 게터
├─ theme/app_theme.dart          # 디자인 시스템 + timeGradient()
├─ services/ (1,950줄)
│  ├─ study_data.dart(866)       # 12개 JSON 자산 로더
│  ├─ progress_service.dart(261) # 문항별 진행/오답 (shared_preferences)
│  ├─ pass_prediction.dart(148)  # 합격 예측
│  ├─ cerebras_service.dart(102) # AI 해설 (외부 API)
│  ├─ flashcard_srs.dart(80) / dday_planner.dart(60) / score_history.dart(61) / slide_progress.dart(39)
├─ screens/
│  ├─ home_screen.dart           # timeGradient 헤더+스파클, 레벨 스트립, 일일미션, 오답복습 진입
│  ├─ exams_screen.dart          # Qnet 배너, D-Day 카드
│  ├─ timer_screen.dart          # 프리미엄 원형 타이머, XP 스낵바, 레벨업 팝업
│  ├─ stats_screen.dart          # 마법사 카드→주간리포트→히트맵→배지→목표→차트
│  └─ study/ (16 화면)           # 4탭 허브(기초/문제풀이/모의고사/이력) + quiz_play, smart_review 등
└─ widgets/ (15개)               # magic_effects, daily_mission_card, badge_collection,
                                 # level_up_dialog, study_heatmap, weekly_report_card 등
assets/data/ (12 JSON)           # exams.json(29회차·2,897문항: id/label/year/session/questions),
                                 # topic_freq, lessons, mnemonics, theory_slides, solution_recipes,
                                 # formula_guide, silgi, videos, study_plan, exam_info_2026, repeat_questions
```

**빌드/배포 상태 기준선**: analyze 0 issue, 커밋 `2da231f`, 서버 bash_f88df100(5060) 가동,
프리뷰 https://5060-ie9f8zla5o9s5maa1br5y-d0b9e1e2.sandbox.novita.ai

---

## §6. 갭 분석 v2.0 (자기검증 재채점 — v1.0 오류 정정)

> **Inspector 감사 결과**: v1.0의 ✗/△ 판정 3건이 실제 코드와 불일치했음. 근거 파일을 명기하여 재채점.

| 기준 | 실제 현재 상태 (근거) | 판정 | 대응 |
|---|---|---|---|
| 1. 회차별·과목별 풀이 | 회차 29개 + 과목별 빈출순/난이도순 카드 (study_screen `_freqCard`, kSubjects 5과목 균등 ~580문항) | ○ | 유지 |
| 2. 채점→해설 연결 | **해설 2,897/2,897 (100%) 로컬 보유**, 문항 내 RichSlideBody 해설 + 재회독 배너 | ○ | 유지 |
| 3. 오답노트 자동 축적 | ProgressService record + Leitner SRS(dueReviewQids) + SmartReview | ◎ | 유지 |
| 4. 북마크·약점 확인 | **북마크 이미 구현**(toggleBookmark + 퀴즈 AppBar 별 토글 + SmartReview 연동), 약점은 weakTopics/처방전 | ○ | 유지 |
| 5. 무료/광고 체감 | 완전 무료·무광고·오프라인 | ◎ (우위) | 유지 |
| 6. **스트릭 보호** (Duolingo) | 스트릭 계산만 있고(`streak` getter) 상실 방지 장치 없음 | ✗ **진짜 갭** | **T-4 (이번 턴)** |
| 7. **CBT 문항 그리드 네비게이터** (맞추다) | examMode에 타이머는 있으나 문항 점프 그리드 없음 | ✗ **진짜 갭** | **T-5 (이번 턴)** |
| 8. 온보딩 30분 루틴 (오르조) | 온보딩 전무 | ✗ | T-6 |

---

## §7. 로드맵 v2.0 + 태스크별 초세밀 구현 스펙

> 각 태스크는 §1.3 프로토콜(A0→A5)을 완주해야 완료다. 순서 변경은 사용자 지시로만 가능.
> ~~T-1(북마크·과목필터), T-2(해설루프), T-3(약점분석)~~ → **Inspector 감사 결과 기구현 확인, 폐기.**

### T-4. 스트릭 보호권 "마법 방패" (★★★ — Duolingo §4.3 직접 근거, 리텐션 핵심 레버)
- **A1 Researcher**: 완료. Duolingo streak freeze — 끊길 날 자동 소모로 스트릭 유지, 리텐션 +43%p 문맥.
- **A2 Architect 스펙 (정밀)**:
  - **저장소**: 기존 Hive `settings` 박스 재사용(신규 박스 금지). 키: `shieldCount`(int, 기본 0, 최대 2), `shieldLastEarnDay`(String 'yyyy-MM-dd' — 하루 1회 지급 가드), `shieldUsedDates`(List<String> — 방패로 보호된 날짜들).
  - **AppProvider 신규 API**:
    - `int shieldCount` 필드 + `_load()`에서 복원.
    - `bool get todayMissionsAllDone` — daily_mission_card.dart의 3개 조건(todayMinutes≥30 ∧ todayQuizSolved≥10 ∧ todayQuizCorrect≥5)과 **동일 공식** (단일 진실 원천을 Provider로 이동).
    - `void maybeEarnShield()` — 올클리어 ∧ 오늘 미지급 ∧ shieldCount<2 → +1, notifyListeners. 반환 bool(지급 여부)로 스낵바 트리거.
    - **스트릭 게터 수정**: 빈 날을 만나면 `shieldUsedDates` 포함 여부 확인 → 포함 시 연속으로 간주. `int get effectiveStreak`.
    - `void autoConsumeShield()` — 어제 학습 0분 ∧ 그제까지 스트릭 존재 ∧ shieldCount>0 ∧ 어제가 미보호 → 어제를 shieldUsedDates에 추가, shieldCount-1. `_load()` 말미에서 1회 호출.
  - **UI**: home_screen 스트릭 카드에 `🛡️×N` PillBadge; addQuizResult/stopTimer 직후 maybeEarnShield → 지급 시 "🛡️ 마법 방패 획득!" 스낵바.
- **완료 기준**: 하루 건너뛴 시나리오에서 방패 자동 소모 후 스트릭 유지(수동 데이터 조작 검증).

### T-5. CBT 문항 그리드 네비게이터 (★★★ — 맞추다 CBT 재현 갭)
- **A2 Architect 스펙 (정밀)**:
  - 신규 화면 금지 — **quiz_play_screen.dart의 examMode에 내장**(기존 채점 `_finish()` 파이프라인 100% 재사용).
  - AppBar actions에 그리드 아이콘(`Icons.grid_view_rounded`) → `showModalBottomSheet`로 문항 번호판:
    - GridView 8열, 셀 상태 3색: 답함(primary 채움)/현재(테두리 강조)/안 푼 문항(회색), 북마크 문항 우상단 ⭐ 도트.
    - 셀 탭 → `setState(_idx = i)` + 시트 닫기 + `_syncBookmark()` 재호출.
    - 시트 상단: "푼 문항 N/총 M" + 남은 시간 표시(examMode).
  - 하단 내비 행에 "번호판" 버튼 추가(연습 모드에서도 사용 가능).
- **완료 기준**: 100문항 모의고사에서 임의 문항 점프·복귀 정상, 채점 결과 불변.

### T-6. 온보딩 30분 루틴 (★ — 오르조 시사점, 다음 턴)
- 첫 실행 감지(settings 박스 `onboarded_v1`) → 3페이지(목표 시험일→일일 목표→핵심 루프 안내). PageView + 기존 exam/goal setter 재사용.

### T-7. 백로그 (사용자 승인 후 착수)
- FSRS 전환 검토(§4.4 보류 사유 재평가), 위클리 리그(익명 랭킹), 푸시 리마인더(Android 빌드 시).

---

## §8. 업데이트 전략 & 검증 프로토콜

1. **브랜치 전략**: main 단일 브랜치, 태스크당 1커밋 원칙(메시지: `T-n: <요약>`).
2. **검증 체인(A4 표준)**:
   ```bash
   cd /home/user/flutter_app && flutter analyze          # 0 issue 필수
   flutter build web --release                            # ✓ Built 확인
   curl -s localhost:5060/main.dart.js | wc -c            # == build/web/main.dart.js 크기
   ```
3. **서버 재기동(죽었을 때만)**: `lsof -ti:5060 | xargs -r kill -9; python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 &`
4. **백업 체인(A5 표준)**: commit → ProjectBackup → 사용자에게 `curl -L -o cert_study_tracker.tar.gz "<URL>"` 명령 제공 → §9 갱신.
5. **데이터 마이그레이션**: Hive 박스 스키마 변경 시 반드시 null-safe 읽기(`as T?`)로 하위호환.

### §8.5 🛡️ V-팀: 3인 상설 감시 에이전트 (매 태스크 필수 통과 — 사용자 지시로 상설화)

> "모든 코드가 실제로 동작하는가? 허울뿐인 것은 없는가? 진짜 배포될 상태인가?"
> 매 태스크(매트릭스급)마다 아래 3인의 감시를 **전원 통과**해야 A5 진입 가능.

**V1 기능실체 감시관 (Reality Inspector)** — 허울 코드 적발
```bash
# 미결선 화면: 어디서도 push되지 않는 Screen 적발
for f in lib/screens/**/*.dart; do c=$(basename $f .dart); grep -rq "$c" --include="*.dart" lib/ --exclude="$f" || echo "ORPHAN: $f"; done
# 빈 핸들러/placeholder 적발
grep -rn "onPressed: () {}\|onTap: () {}\|TODO\|UnimplementedError\|준비 중\|Coming soon" lib/ --include="*.dart"
```
판정: ORPHAN 0건 + 빈 핸들러 0건 + "준비 중" 문구 0건 → PASS

**V2 배포상태 감시관 (Deploy Readiness Inspector)** — 진짜 배포 가능 상태 검증
```bash
flutter analyze                          # 0 issue
flutter test                             # 전건 통과
flutter build web --release              # ✓ Built
# 서빙 바이트 == 빌드 바이트 (프리뷰가 최신 코드인지)
diff <(curl -s localhost:5060/main.dart.js | wc -c) <(wc -c < build/web/main.dart.js)
```
판정: 4단계 전부 통과 → PASS. 하나라도 실패 시 수정 후 V1부터 재검.

**V3 전달링크 감시관 (Link Inspector)** — 사용자가 받을 수 있는 상태 검증
```bash
# APK 공개 curl 링크 HTTP 200 + 크기 일치
curl -sI "https://8899-<sandbox>/CertStudyTracker-v1.0-release.apk" | head -1   # 200
# ProjectBackup URL 유효성 (A5에서 생성 직후 확인)
```
판정: APK 200 + 크기 일치 + 백업 URL 발급 → PASS.
**모든 태스크 종료 시 사용자에게 반드시 `curl -L -o ...` 형태의 다운로드 명령을 제공한다.**

---

## §9. 변경이력 (Archivist가 매 태스크 후 갱신 — 재개 시 여기부터 읽기)

| 일자 | 커밋 | 내용 | 백업 |
|---|---|---|---|
| R17 | 6e66783 | 시험 화면 리디자인 (Qnet 배너, D-Day 카드) | cyaEYYvv |
| R18 | 08ea4d1 | UX 전면 개편: 5탭 내비, 학습 4탭 허브, 타이머/통계 리디자인 | - |
| R19 | 367a5a2 | XP/마법사 레벨, 스파클, 일일 미션, 스태거 애니메이션 | - |
| R20 | 0ab0b91 | XP 피드백, 배지 컬렉션(10종) | dIE7s8Mg |
| R21 | a6a983d | 레벨업 파티클 팝업 | a3o8pt1V |
| R22 | 2da231f | 시간대별 그라디언트, 12주 히트맵, 주간 성장 리포트 | E7gTXo6v |
| R23 | b5805e4 | **MASTER_PLAN.md 바이블 제정** — 오케스트레이터 헌장·갭분석·로드맵 | Roas0KcH |
| R24 | 2cdc24c | **바이블 v2.0** (갭분석 자기검증 정정 + 리서치 §4.4/4.5 증보) + **T-4 마법 방패**(streak freeze: 자동소모·미션 올클리어 지급) + **T-5 CBT 문항 번호판**(그리드 점프, 답함/현재/북마크 표시) + **T-6 프리미엄 온보딩**(시험일→목표→루프, 3페이지) | 9PFMBP56 |
| R25 | b290165 | **T-7a 위클리 마법 리그** — 주차 시드 결정적 가상 라이벌 9명, 요일 경과에 따라 라이벌 XP 성장(긴장감 유발), 승급권 Top3 배지, 다음 순위까지 필요 XP 코칭, `weekXp` 게터 신설 | q51NAiZV |
| R26 | c8df58e | **T-7a2 홈 리그 미니 스트립** — 홈 미션 카드 아래 순위/승급권/XP 요약 + 탭 시 통계 탭 이동, `leagueStanding()` 공용 로직 추출, `rivalsFor()` static 화 | P79ErOlT |
| R27 | e4d9bef | **레이아웃 전수감사 1차** — ① 홈 우선순위 재배치(긴급 복습을 목표 스트립 직하로 승격: 망각곡선상 최우선 행동이 미션·리그보다 위) ② DueReviewCard/DueFlashcardCard 디자인 시스템 위반 교정(수제 Material→PremiumCard+IconBadge+PillBadge, 하드코딩 grey→onSurfaceVariant 다크모드 대응) ③ FadeSlideIn 스태거 인덱스 1~7 순차 정렬 | 52UgkiIl |
| R28 | (이번) | **레이아웃 전수감사 2차 (§9.1 전항목 완료)** — ① 레거시 `Card(` 전수 스캔(3건) 후 교정: dday_plan_card 성장그래프→PremiumCard+IconBadge(electric), study_screen _cbtTrendCard→PremiumCard(padding zero)+collapsedShape 보정 ② quiz_play_screen 옵션 타일 Card는 **의도적 예외로 판정**(정답/오답/선택 상태색 동적 변경 인터랙티브 타일, scheme 기반이라 다크모드 안전) ③ stats_screen 리그(경쟁)↔리포트(성찰) 사이 SectionHeader 2종 삽입(⚔️ 이번 주 경쟁 / 📊 나의 성장 기록) ④ 신규 유저 빈 상태 검증: Due 카드 2종 count==0이면 shrink, 예측카드 진단유도 분기, 리그 0XP 안전 — 과밀 없음 | (커밋 후 기입) |

**§9.1 레이아웃 감사 잔여 항목 — R28에서 전항목 완료 ✅**
- [x] exams_screen(744줄)·study_screen(812줄) 배치 감사 — exams 빈상태 OK(L203), study는 _cbtTrendCard 레거시 Card 교정 완료
- [x] quiz_play_screen(903줄) 시각 위계 — 옵션 타일 Card는 상태색(정답녹/오답빨/선택 primary) 의도적 예외로 판정·문서화
- [x] 온보딩→홈 첫 진입 빈 상태 — Due카드 2종 shrink, 예측카드 진단유도 분기, 리그 0XP 안전. 과밀 없음
- [x] stats_screen 리그/리포트 시각 구분 — SectionHeader(⚔️ 경쟁 / 📊 성찰) 삽입 완료
- [x] 레거시 `Card(` 전수 스캔 — 주요 표면(홈/통계/학습허브/DDay카드) 0건. 심층 서브화면 27건은 **전역 CardThemeData(L159, rMd·테두리·elevation0 동일 적용)를 상속하므로 위반 아님으로 판정** — 차이는 softShadow뿐, 시각 일관성 유지됨. quiz 옵션 타일 1건은 상태색 인터랙티브 예외

| R29 | 49209ab | 신규 프로젝트(중·고 교과앱) 작업지시서 NEW_PROJECT_WORKORDER.md 제정 — 별도 세션에서 진행, 본 앱은 전기기사 유지 | WgILqwiZ |
| R30 | (이번) | **안정화 스윕** — ① JSON 12종 파싱+2,897문항 무결성 게이트 통과(answer/옵션/해설 위반 0) ② 위험 패턴 전수 그리프: firstWhere 2건(try-catch/orElse 기보호 확인), 0-분모 나눗셈 14건(전부 가드 확인), `.first` 접근(정적 리스트/isEmpty 선행 확인) ③ 유일 실결함 home_screen `e.name[0]` 빈 문자열 크래시 가능성 → `isEmpty ? '?'` 가드 추가 ④ analyze 0 + release build + 서빙 바이트 일치(3,534,878) | (커밋 후 기입) |

| R31 | (이번) | **Android APK 릴리즈 빌드** — ① 패키지명 불일치 발견·정정: `com.example.cert_study_tracker`(기본값) → `com.certstudytracker.study` 4개소 동시 동기화(build.gradle.kts namespace/applicationId, AndroidManifest label, MainActivity.kt 패키지선언+디렉터리 이동, 구 디렉터리 삭제) ② android 빌드캐시 클린 후 flutter_signing_tool로 keystore(release-key.jks)+key.properties 자동 생성 ③ build.gradle.kts에 signingConfigs release 블록 결선(keystoreProperties 로드→keyAlias/keyPassword/storeFile/storePassword) — 기존 debug 서명 임시배선을 release 서명으로 교체 ④ `flutter build apk --release` 성공, app-release.apk 55MB 산출 ⑤ analyze 0 issue 재확인 | (커밋 후 기입) |

| R32 | (이번) | **cmd 다운로드 인프라 + 3차 전수 안정화** — ① ProjectBackup 공유링크(`/api/files/s/*`)가 순수 curl(무인증)에서 403 반환하는 결함 발견 → `releases/` 디렉터리 신설 + 포트 8899 전용 Python 서버 상시 기동으로 **인증 불필요 curl 다운로드** 확보(200, 56,817,118 bytes, Android package 검증 통과) ② flutter analyze 0 재확인 ③ 문항 무결성 재검증(2,897개, answer/옵션/해설 위반 0 + **신규: 회차·문항번호 중복 0** 추가 검사) ④ 패키지명 4자 일치(namespace/applicationId/MainActivity 경로/패키지선언) + example 잔존 디렉터리 없음 재확인 ⑤ signingConfig release 결선 유지 확인 ⑥ 위험패턴(firstWhere/0분모/first) R30 대비 lib/ 무변경으로 안전 재확인 ⑦ 웹 릴리즈 재빌드→서빙 바이트 재대조 일치(3,534,878) ⑧ **결함 수정**: `.gitignore`에 `/releases/` 미등록되어 55MB APK 커밋 위험 발견 → 규칙 추가 | (커밋 후 기입) |

| R35 | 1271254 | **3-트랙 실콘텐츠 승격 + 신뢰성 마케팅 전면 정비** — ① 전기공사기사/소방설비기사(전기) 트랙에 실기출 복원 뱅크 적용(EC 480문항·12회차·42토픽, FE 384문항·12회차·20토픽) + 12종 JSON×3트랙 무결성 게이트 0오류(실스키마 기준: options==4, answer 1–4, 해설 존재, 과목명 화이트리스트 '전자기학' 정정) ② **허위 통계 결함 근절**: EC/FE 화면이 전기기사 전용 수치(10년치 2,897문제·46토픽·347·100문항)를 그대로 표기하던 신뢰성 결함 → ExamTrack에 questionCount/topicCount/repeatCount/bankLabel/paperSize 필드 + questionCountLabel 게터 신설, 5개 호출부(홈 배너·학습 히어로·문제풀이 부제·모의고사 부제·이론서 설명) 전부 트랙 동적화 ③ 트랙선택 화면 마케팅 승격(부제+버튼별 '기출 N문항 · 1:1강의 N토픽 · 암기카드' 실측 스탯) ④ StudyPlan.strategy List|String 관용 파싱 + EC/FE study_plan.json에 실전 합격전략 5계명 수록 ⑤ invalid_constant 2건(const SectionHeader+보간) 수정, analyze 0 ⑥ Puppeteer 3트랙 전수(TOTAL_CRASH=0) + 스크린샷 실측: EC 모의 '회차당 40문항', FE '32문항', 전기기사 '100문항', FE 문제풀이 '기출 복원 384문제', EC 슬라이드 신규 커리큘럼 설명+전략5계명 타일 확인 ⑦ tracks_test.js 좌표 결함 수정(서브탭 y=80, 백버튼 복구, 칩 300,60) + slides_check.js 신설 ⑧ 웹 릴리즈 빌드+5060 서빙 바이트 일치(3,544,307) | 1271254 |

| R36 | c9bf82b | **이론학습 심화 강화 — 출제방식·필수암기·공식기초·심화암기·실기연계 5종 섹션** — ① Lesson 모델(study_data.dart)에 `basic_explain`(왕초보 기초설명)/`exam_how`(시험 출제방식 안내)/`must`(필수 암기 리스트)/`advanced`(심화 암기 — 만점·고득점 포인트)/`silgi`(실기 연계 포인트) 5개 필드 신설 + JSON 파싱 결선 ② lesson_view.dart에 5종 UI 섹션 렌더링 구현: 왕초보 기초(blue box) → 시험 출제방식(deepPurple list) → 필수 암기(gold gradient card, 항목별 번호칩) → 심화 암기(ExpansionTile 접기, "기초가 끝났다면 열어보세요") → 실기 연계(teal box) ③ 3트랙 콘텐츠 저술: tool/content_fe.py(소방설비 20토픽), tool/content_ec.py(전기공사 42토픽 중 우선토픽), tool/apply_content_r36.py(lessons.json 병합, 기존 필드 보존)로 3개 트랙 lessons.json 갱신 ④ **Puppeteer 좌표 결함 발견·수정**: `_basicsTab()`의 `TutorBanner`(30일 슬라이드, 무관 기능)가 `_heroCards()` 위에 위치해 y=200 클릭이 오화면(SlidesHomeScreen)으로 오탐 → 정정좌표 히어로카드(110,258) 확정, 레슨타일 단일클릭 불안정 → y=[235,245,260,270,280] 재시도루프로 대체, lesson_r36.js(공식 회귀테스트) 좌표 갱신 완료 ⑤ 3트랙(전기기사/EC/FE) 전수 시각검증: 전기기사(자계·자기력, basic_explain/exam_how/must 확인, advanced·silgi는 해당 토픽 미해당으로 부재 — 기존 알려진 갭) / FE(건축방화·피난, 5종 전부 확인) / EC(전동기 응용, 5종 전부 확인) ⑥ **버그 발견·수정**: EC 검증 중 테이블 셀에 `**펌프, 송풍기, 팬**`이 볼드 미변환 원문 노출 발견 → `_richText()`에 `baseStyle` 옵션 파라미터 추가 + `_buildTable()` 셀 렌더링을 `Text()`→`_richText()`로 교체, 재빌드 후 Puppeteer 재검증으로 볼드 정상 렌더링 확인 ⑦ analyze 0 + 웹 릴리즈 재빌드 성공 + Puppeteer 3트랙 TOTAL_CRASH=0 | c9bf82b |

| R37 | bcb4dbe | **전기기사 이론 심화 완결 (§6 갭 보강 완료)** — ① content_elec_r37.py: 46토픽(전자기학9/전력공학10/전기기기7/회로제어11/전기설비9) 전문 저술 — basic_explain(왕초보 비유)/advanced(만점·고득점 3~5개)/silgi(실기연계) 각 토픽별 정확한 전기공학 지식 담아 작성 ② apply_content_r37.py: 기존 필드(intro/sections/formulas/must/exam_how/mnemonics/traps/strategy) 100% 보존, basic_explain은 비어있을 때만 채움(R36 17건 저술 존중), advanced/silgi 전량 신규 ③ **커버리지 달성**: basic_explain 46/46(29신규+17유지), advanced 46/46, silgi 46/46 — R36 시점 전기기사 advanced=0/silgi=0 갭 완전 해소 ④ **무결성 게이트**: 3트랙 스키마/타입 위반0, formulas desc잔존0, 기존필드 변경0(백업 대조) ⑤ **임시빌드 전수검증**: analyze 0 issue + web release 빌드 + 5060 서빙바이트 일치(3,549,603) + 실서빙 asset 확인(advanced 46/46·silgi 46/46) + APK 57.3MB 재빌드→releases/ 갱신→무인증 curl 다운로드 200(공개URL HTTP/2 200, content-length 57,267,215) | bcb4dbe |

| R38 | (이번 커밋) | **딥리서치: 기출 재수집 검증 + 합격 공부법 신규 반영 (사용자 지시)** — ① **기출 재수집 딥리서치**: comcbt 공식 기출목록·합격후기(dcinside 2달합격) 교차검증 → **전기기사는 2022년 3회부터 CBT 전환으로 이후 문제 비공개**, 시중 '최신기출'은 부정확한 복원문제. 우리 앱의 2013~2022 29회분(2,897문항)이 **정확한 원본 완전세트**로 확정 → 재수집 대상 없음(복원문제 추가시 품질저하). 전기공사(2021~2024,480)·소방설비(2021~2024,384)는 이미 최신. 합격자 실증: '9~10개년이면 충분' ② **공부법 딥리서치**: 과목순서(전공/비전공)·과목별 공부요령·합격자 공통원칙·권장기간 수집(honeyarchive/machuda/dcinside 후기) ③ **앱 반영**: study_guide.json 3트랙 신규 생성 / study_data.dart에 StudyGuide+6개 서브모델+loadStudyGuide()+캐시처리 / study_guide_screen.dart 신규화면(헤더·기출신뢰도·과목순서 전공전환토글·과목별 ExpansionTile·합격원칙·학습기간표) / study_screen 기초학습 그리드에 '합격 공부법' 카드추가+동적행배치(3→10개 안전) ④ **임시빌드 전수검증**: analyze 0 issue + web release 빌드 + 5060 서빙바이트 일치(3,560,426) + study_guide.json 실서빙 확인 + APK 57.4MB 재빌드→releases/ 갱신→무인증 curl 다운로드 200(로컬+공개URL HTTP/2 200, content-length 57,372,691) | 18445df |

| R39 | (이번 커밋) | **Kimi K2(Moonshot) API 튜터 반영 + 5테마 팔레트 (사용자 지시)** — ① **Kimi 연동 스펙 확정**: 영상3편 분석 URL 접근거부 → web_search+apidog crawl로 OpenAI 호환 스펙 확정(base `https://api.moonshot.ai/v1`, `POST /chat/completions`, `Authorization: Bearer`, model `kimi-k2.6`/`kimi-k2.6-thinking`, 262K context) ② **KimiService 신설**(kimi_service.dart): 기존 cerebras_service 검증패턴 미러링, 싱글턴+ChatTurn+KimiException, `askTheory()`(단발 이론검증 maxTokens1200/temp0.3)·`chat()`(대화형 튜터 maxTokens1400/temp0.6)·`_complete()`(200/401/404/429/529 분기), 트랙인식 시스템프롬프트(최신정보+학습가이드 튜터), API키·모델 on-device(shared_preferences) 저장 ③ **AI 튜터 채팅화면**(tutor_chat_screen.dart) 신규: 대화 버블·타이핑 인디케이터·트랙별 추천질문칩·키설정 다이얼로그·TutorAvatar(teaching) 빈상태 ④ **search_screen AI검증 Cerebras→Kimi 전환**(6개소: import/initState/_askAi/키다이얼로그 title·help·label/저장핸들러) ⑤ **study_screen 그리드**에 'AI 튜터'·'합격 공부법' 카드 선두 추가(11개 동적행) ⑥ **5테마 팔레트**(app_theme.dart): ⚡인디고/🌿에메랄드/🌸로즈/🔥앰버/🌊오션 ThemePalette 5종+paletteById(), light([palette])/dark([palette]) seed·accent 파라미터화(브랜드 static const primary/accent는 포인트컬러 유지=안전) ⑦ app_provider themePaletteId 상태+Hive 영속화+setThemePalette(), main.dart palette 선택·적용, home_screen 헤더에 🎨팔레트 선택 바텀시트(5종 그라디언트 프리뷰+체크) ⑧ **Kimi 엔드포인트 실연결 실증**: 샌드박스 curl로 `api.moonshot.ai` 도달 확인(더미키→`{\"error\":{\"message\":\"Invalid Authentication\"}}` = 엔드포인트/body형식/401분기 정확 동작 실증. 유효키만 넣으면 앱에서 실제 답변 생성) ⑨ **임시빌드 전수검증**: analyze 0 issue + web release 빌드 서빙바이트 일치(3,579,256, R38比+18,830) + APK 57.5MB 재빌드→releases/ 갱신→무인증 curl 다운로드 200(57,454,919 bytes, R38比+82,228) | (이번 커밋) |

| R40 | 05f6d78 | **AI 튜터 Cerebras gpt-oss-120b(추론) 재전환 + 왕초보 기초사전 312용어 통합 + 관대한 파싱 (인터럽트 미커밋 작업 완결)** — ① R39 Kimi 전환을 **Cerebras gpt-oss-120b(reasoning)로 재통일**: 내장 기본키 탑재로 사용자 설정 없이 즉시 작동(`hasKey()` 항상 true), tutor_chat_screen `TutorReply(thinking/answer)` '🧠 생각 과정' 펼침 UI + reasoning_effort(medium), kimi_service.dart 제거 ② search_screen AI검증도 Cerebras로 통일(6개소) — 내장키 있어 키다이얼로그는 '교체용(선택)'으로 완화 ③ **전 종목 공통 왕초보 기초사전** basics_dict.json 신설(14카테고리·**312용어**: 단위30/그리스문자24/핵심개념53/기호약어50/시험필수숫자13/전력용어32/기기15/전자기학15/조명전기화학12/KEC10/수변전19/실기시공14/소방전기20/공부요령5) + `loadBasicsDict()`/`basicsCategories` 캐시로더(BasicTerm category/term/easy/detail 스키마 일치 검증) ④ formula_guide '왕초보 기초사전' 탭에 **공통사전 병합**(트랙 basics + 312용어 term기준 중복제거, 공통 카테고리 우선정렬) — 기존엔 로더만 있고 UI 미소비였던 갭 해소 ⑤ 관대한 파싱: SilgiItem(topic/subject/body 수용)·SilgiData.strategy(String\|List switch)·FormulaGuide(desc→understand) 구스키마 방어 ⑥ repeat_questions 대량확장(electrician +8,902줄) — 문항 무결성 게이트 위반 0(options==4·answer 1–4) ⑦ **검증(A4)**: analyze **0 issue** + web release build + 서빙바이트 일치(**3,598,025**, R39比 +18,769) + basics_dict 312용어 실서빙 확인(HTTP 200) | (커밋 후 기입) |\n\n| R41 | fa7a151 | **시험 흐름 강화 + AI 키 보안(P0-1/P0-4)** — 실전 모드 제출 전 정답·해설 차단(QuizPolicy), AI 키 하드코딩 제거·BYOK 완화, exams 화면 큐넷 일정/원서접수/CBT정보 서비스 결선 | fa7a151 |
| R42 | e9b10a8 | **적응형 데일리 자동학습 코치** — AutoStudyService(남은 목표시간→문항예산 변환, 복습·오답 우선 배치, 최소복습량 유지, 상한 캡), auto_study_screen 신설 | e9b10a8 |
| R43 | 58fd447 | **전수 통합 커밋 (세션 재개 A0→A5 완주)** — ① 신규 화면 8종: settings(백업·알림·인증)/calculator_hub(공학계산 허브)/formula_calc(공식계산기)/unit_converter(단위변환)/circuit(회로도감)/pass_report(합격리포트)/wrong_focus(오답집중)/visual_repeat(시각화 반복분석) ② 신규 서비스 10종: notification_service(로컬 알림·D-Day 리마인더), qnet_schedule_service+qnet_catalog+schedule_alerts(큐넷 일정·알림), exam_analysis·exam_registration(시험 분석·원서접수), cbt_info_service, auth_service, formula_calculators, unit_converter ③ 데이터: qnet_schedule.json, common/circuit_guide.json, 3트랙 exam_info_2026/exams/repeat_questions/silgi 갱신 ④ 자산: 앱아이콘 mipmap 5종+adaptive icon, 스플래시, 폰트, web 아이콘 교체 ⑤ **테스트 17건 신설·전부 통과**(quiz_policy 8: 합격판정·과락·미답 / cerebras 3: 키 상태 / auto_study 5: 예산·우선순위) — placeholder 탈피(P0-2 착수) ⑥ 검증: analyze 0 + test 17/17 + web release 서빙바이트 일치(5,147,736) + APK 75.2MB 서명빌드 → releases/ 갱신 → 공개 curl 200(75,153,763 bytes) | 58fd447 |

| R44 | 71c23d5 | **경쟁력 평가 보고서 — 실제 상위 10개 앱 × 50개 항목** (docs/COMPETITIVE_BENCHMARK_50.md) — 딥리서치(맞추다 이용자 8,780명/오르조 앱스토어 1위/comcbt/다산패스/전구앱/기출넷/오늘학습/에듀윌/해커스/날먹) 기반 10카테고리 50항목 5점 채점. **총점 223/250(89.2%)**, 게이미피케이션·부가도구 100%, 유일 기능 8종 확인. 최대 갭: 오류신고(1점)·법적고지(2점)·접근성(2점)·AI변형문제(1점) — 보강 우선순위 6건 확정 | 71c23d5 |
| R45 | 86f2388 | **스토어 출시 태스크 4종 + V-팀 상설화** — ① 🧙 AI 튜터 페르소나 5종(tutor_persona.dart: 마법사/왕초보쌤/교수님/스피드요약러/현장선배, 선택 바텀시트+캐릭터별 시스템프롬프트+추천질문, SharedPreferences 영속) ② 🐣 왕초보 로드맵(beginner_roadmap_screen.dart: 지식 0 기준 6단계 STEP 0~5, 체크 진행률 저장, 단계별 실행 칩→이론/AI튜터/기출10문/플래시카드, 홈 배너+학습그리드 결선) ③ 🎯 홈 과목 선택 중심 재구성(_SubjectHub: 과목 리스트→바텀시트에서 이론/과목기출/플래시카드 즉시 진입) ④ 🏪 스토어 출시요소: legal_screen.dart(개인정보처리방침·이용약관·AI고지 3탭)+오픈소스 라이선스+설정 응원하기(리뷰·공유·피드백)+퀴즈 🚩오류신고(6유형→mailto)+docs/PLAY_STORE_LISTING_KIT.md(등록문구·데이터안전·ASO·가격전략) — 벤치마크 갭 B7·H4 해소 ⑤ §8.5 V-팀 3인 감시(기능실체/배포상태/전달링크) 상설 프로토콜 신설. 검증: V1 PASS(orphan 0·허울버튼 0) + analyze 0 + test 17/17 + web 서빙바이트 일치(5,235,376) + APK 75.8MB→releases/ 공개 curl 200 | 86f2388 |

| R46 | (이번 커밋) | **볼트쌤 리브랜딩 + 튜터 전신 코치 시스템 (사용자 지시: "얼굴 잘림" 근본수정 + "모든 상황 1:1 과외") + AI표기 브랜딩 교체** — ① **브랜드 확정**: "볼트쌤"(⚡번개+🎓학사모, indigo-violet #4F46E5→#7C3AED+gold), 메인 로고(가로 워드마크, 트림+투명배경 1264×848)+정사각 서브로고(logo_square/512) 생성 → `assets/brand/` 신설, 앱 아이콘 전량 재생성(flutter_launcher_icons: mipmap 5종+adaptive+web icons), AndroidManifest label/web manifest.json/index.html title 볼트쌤 적용 ② **'AI' 표기 → 볼트쌤 전면 교체**(법적고지 legal_screen 제외 의도적 유지): cerebras_service 시스템프롬프트(`당신 이름은 "볼트쌤"이며...`), study_screen 그리드 '볼트쌤 튜터', search_screen 검증답변 문구, tutor_chat_screen 설정타이틀, settings_screen applicationName·공유문구, beginner_roadmap AI→볼트쌤, tutor_avatar TutorBanner '푸키 튜터'→'볼트쌤' 라벨 통일 ③ **튜터 얼굴 잘림 근본 수정**(tutor_avatar.dart headOnly): `BoxFit.cover`+상단정렬 크롭 방식 → `BoxFit.contain`+패딩(size×0.08)으로 전신 표시, "크롭 금지(사용자 지시)" 주석 명기 ④ **TutorCoach 전신 1:1 과외 시스템 신설**(tutor_coach.dart): `CoachSituation` 27종(홈 시간대3+스트릭+복귀, 퀴즈 시작/정답/정답스트릭/오답/오답반복/고난도/막판, 결과 합격/불합격/만점, 로드맵 시작/진행/완료, 플래시카드, 이론, 공식, 타이머, 통계 굿/배드, D-Day 원/근, 격려) × 수준 3단계(왕초보/중급/상급) × 상황별 3멘트 = **243개 멘트 엔진**(`TutorMents.pick/moodOf`), `TutorCoach` 위젯(전신 아바타+"⚡ 볼트쌤" 라벨+말풍선+탭→채팅 연결) ⑤ **전 화면 7곳 배치**(적재적소 동적 상황판정): 홈(시간대/스트릭 분기)·퀴즈풀이(난이도/정답스트릭/오답 분기+세션 정답률 기반 수준)·결과화면(만점/합격/불합격+정답률 수준)·왕초보로드맵(단계 진행률)·플래시카드(카드별 ValueKey)·타이머(진행중만)·통계(주간학습량 60분 기준 굿/배드) ⑥ **검증(V-팀 3인)**: V1 PASS(준비중 3건은 정상 로딩상태 문구·미구현고지로 허위 아님, 빈핸들러 0) + analyze 0 issue + test 17/17 + web release 빌드 성공 + **5060 서빙바이트 로컬 일치(5,273,151, R45比 +37,775)** + **APK 재빌드 72.8MB**(볼트쌤 아이콘·라벨 반영, AndroidManifest label 되돌림 결함 발견·재수정 후 재빌드)→releases/ 갱신→로컬+공개 curl 200(72,832,079 bytes) — **V-팀 3인 전원 PASS**(V1 기능실체/V2 배포상태/V3 전달링크) | 18a41a3 |

| R47 | 26ce12b | **사용자 절대지시 페르소나 각인 + 전기기사 지문 복구 286건 커밋** — ① §1.4에 HARD RULE 8 신설: **GATE-1(10과목 학습DATA·모의고사, 전기기사 수준 품질) 완료 후에만 GATE-2(3D 캐릭터 3명×행동 50개=150모션) 착수** — 순서 역전 금지, GitHub 원격 `byjay/gisa` 지정 ② 인터럽트 복구 검증: recover_questions.py가 교사용 PDF(comcbt_extract/folder_02)에서 '그림·수식' placeholder 문항의 실제 지문 286건 복원 완료 상태 확인(무결성 게이트: 2,897문항 위반 0) ③ 원천 데이터 인벤토리 확정: comcbt_downloads.zip 9종목 압축해제 완료(comcbt_extract/folder_00~08) — GATE-1 잔여: 소방전기 실PDF 재구성, 신규 6종목 트랙 추가 | 26ce12b |

| R48 | 38d9ae5 | **GATE-1 완성: 10개 자격증 트랙 전기기사 수준 전면 세팅 (사용자 최우선 지시: "모든걸 전기기사 수준에 맞게 10개과목 모두 세팅")** — ① **신규 트랙 2종 추가**: 전기산업기사(🔌 19회차 1,673문항, subject_alias로 '전기설비기술기준 및 판단 기준' 매핑 → fallback 22%→0%) + 위험물산업기사(🧪 19회차 1,125문항, 실해설 1,123건) → 총 10트랙 ② **분위수 기반 난이도 시스템**(tool/topic_rules.py `difficulty_raw`: 계산기호×3+숫자×0.5+지문길이×0.06+그림8.0 → 37%/65% 분위수 컷) → 8개 PDF 트랙 전부 37/27~28/34 분포로 전기기사(37/28/34)와 동일 ③ **freq_score 10~100 전 트랙 적용**(토픽 빈도 비례) ④ **보조 콘텐츠 11종 × 7트랙 생성**(tool/gen_support_content.py: lessons/repeat_questions/solution_recipes/mnemonics/formula_guide/videos/study_guide/study_plan 30일/theory_slides/exam_info_2026/silgi) → 전 트랙 13개 JSON 파일로 전기기사와 동일 구성 ⑤ **이론서 MD 34개 생성**(7트랙 과목별, 빈출도 랭킹 표+토픽별 챕터) + pubspec 에셋 등록 ⑥ **fire_electric 정합화**: topic_rules 11개 토픽명을 lessons.json과 통일 + 자동제어 lesson 수저술(21개) ⑦ exam_track.dart 10트랙 등록·topicCount/repeatCount 최신화 — **검증**: 총 16,533문항 스키마 위반 0건, lessons↔exams 토픽 정합 OK(잔여 2건은 의도적: fire_electric 다중이용업소법 예비규칙, elec_construction은 사용자 저작 트랙 불간섭), analyze 0 issue, web release 빌드 성공, 5060 프리뷰 재기동 | 38d9ae5 |

| R49 | 128f079 | **50에이전트×100항목 내부 품질평가 + 12건 실개선 + AAB 빌드 추가 (사용자 지시: "50개 에이전트 동원 100개 항목 평가 후 만점 향해 재수행")** — ① **docs/EXPERT_PANEL_EVALUATION_100.md 신설**: 10분야(시험설계/UX접근성/AI신뢰성/데이터안정성/성능/보안개인정보/게이미피케이션/코드품질/사업성/법務) × 5에이전트 = 50페르소나 패널이 Q1~Q100 코드 근거 기반 채점 → **1차 총점 362/500(72.4%)**, 즉시개선가능 12건(Q6/Q42/Q43/Q47/Q48/Q56/Q59/Q63/Q65/Q67/Q80/Q90) + 구조적상한 5건(Q22 로컬암호화/Q37 통합테스트/Q39 CI-CD/Q40 크래시리포팅/Q93 수익모델, 차기 세션 이월) 식별 ② **12건 즉시개선 실제 구현**: Q6 실전모드 종료확인 다이얼로그 강화(quiz_play_screen `_requestExit` — 답변진행수 명시), Q65 실전모드 중 AI튜터 접근 차단(app_provider `examInProgress` 플래그 + tutor_chat_screen 진입차단 다이얼로그), Q47/Q48 접근성(app_provider `reduceMotion`/`textScaleFactor` + main.dart MaterialApp builder로 앱전역 `MediaQuery.textScaler`/`disableAnimations` 적용 + settings_screen '접근성' 섹션 신설: 모션감소 스위치+글자크기 슬라이더), Q56 스트릭 손실회피 경고 배너(home_screen `_StreakWarningBanner`), Q59 검증된 자체지표 소셜프루프 카드(home_screen `_SocialProofCard` — 허위 이용자수 없이 실제 문항수/토픽수만 표기), Q63/Q67 AI 답변 하단 출처확인 문구+👍👎 피드백 버튼(tutor_chat_screen `_feedbackRow`), Q80 7일 주기 자동 로컬백업(backup_service `autoBackupToLocalFile` + main.dart `_maybeAutoBackup`, kIsWeb 가드), Q42/Q43 Semantics+오버플로 방지(home_screen `_miniStat` Semantics(button)+Flexible/maxLines) ③ **Q90 AAB 빌드 신규 추가**: `flutter build appbundle --release` 최초 성공(77.6MB, releases/app-release.aab) — 기존 APK 전용에서 스토어 표준 포맷 확보 ④ **재평가**: 12건 전부 目標달성 확인 → **2차 확정 총점 395/500(79.0%)**, R48比 +33점 ⑤ **전수 검증**: `dart format` 4파일 정리 + analyze 0 issue + test 22/22(신규 backup_service 5건 포함) + web release 빌드 성공·5060 서빙바이트 로컬일치(5,404,347) + APK 재빌드 90.7MB→releases/갱신→8899 curl 200(90,689,709 bytes) + AAB 77.6MB 신규 생성 | 128f079 |

| R54 | 21238d8 | **Gisaclub 리브랜딩 + AI튜터 BYOK 근본수정 + 기출빈도 상세/속독 강화 + Cloudflare SaaS 백엔드 스켈레톤 (사용자 지시: "앱이름 gisaclub·로고·상용화 검토" + "AI튜터 테스트기간 종료 유지·왜종료·API넣는곳 없음 확인")** — ① **브랜드 볼트쌤→Gisaclub 전면 교체**(main.dart title='Gisaclub'/AndroidManifest label/web manifest·index.html/settings applicationName/legal/help_faq/pubspec description), Gisaclub 로고(번개+학사모 indigo그라디언트) 생성 → 앱아이콘 mipmap 5종+adaptive foreground 5종+web icon 4종+favicon+brand 3종 전량 재생성(gen_gisaclub_icons.py: autocrop·square·rounded·DPI) ② **AI튜터 '테스트기간 종료' 근본원인 규명·수정**: 기존 `isTestPeriod = _devAiEnabled && !kReleaseMode`라 릴리즈빌드는 항상 '종료' 표기+키입력란 은닉이 근본원인 → **BYOK(cerebras_service.dart) 전환**: `isTestPeriod=true`, 사용자 Cerebras 무료키 SharedPreferences 저장(`_loadUserKey`/`getApiKey`(user→dev 우선순위)/`setApiKey`/`hasUserKey`/`validateKey`(401·403 검증)), 빈키 에러문구 '설정→AI튜터 API키에서 무료 키 등록' 안내 ③ **settings_screen**: _brandHeader(Gisaclub 로고 워드마크 그라디언트 카드) 상단 배치 + _aiApiKeyCard 재작성(FutureBuilder hasUserKey 상태+등록/변경 버튼)+_openApiKeyDialog(입력/저장/삭제/검증 obscure토글)+_launchUrlSafe, StatefulWidget화 ④ tutor_chat_screen·search_screen 테스트기간 차단 블록 제거→키등록 안내 전환, hasUserKey FutureBuilder 배너('사용 준비 완료'/'설정에서 키 등록') ⑤ **기출빈도 상세**: Question 모델 freqGrade(초빈출/매우자주/자주/가끔/드물게)·estimatedAppearances(최근10회 중 N회)·reissuePattern(변형패턴)·freqColorValue 게터 + quiz_play_screen `_freqDetailPanel`(등급배지·LinearProgress 게이지·예상출제횟수·변형패턴, freqScore≥20 노출) ⑥ **속독 답외우기 강화**(speed_memorize_screen): 자동재생(1.5/3/5초 타이머)·셀프테스트(답 가리기 탭 공개)·속도조절바·무료 제한(allowedCount 슬라이스+FreeLimitChip+premium 페이월 훅) ⑦ **출시 준비**: build.gradle.kts release minifyEnabled+shrinkResources+proguardFiles, proguard-rules.pro 신설(Flutter/local_notifications/GSON/speech/Play Core keep) ⑧ **Cloudflare SaaS 백엔드 스켈레톤**(backend/cloudflare/: ARCHITECTURE.md·wrangler.toml·0001_init.sql·index.js 라우터·auth/entitlement/content/ai/billing.js) + split_content_for_r2.py(110MB assets→meta(D1)/body(R2)/private(D1) 분리, 정답·해설은 채점API에서만 반환) + lib/services/remote_content_api.dart 클라이언트 — **주의: 스켈레톤만, 미배포·미연결(앱은 아직 로컬 110MB 자산 사용)** ⑨ CLAUDE.md 프로젝트 룰 문서 추가 ⑩ **검증(A4)**: analyze **0 issue** + web release 빌드 + 5060 서빙 200 + **APK 214.0MB 릴리즈 빌드 성공**(난독화·Gisaclub 아이콘 반영)→releases/gisaclub-release.apk→8899 curl 200(214,035,190 bytes) | 21238d8 |

| R55 | 9e25552 | **구조적상한 5건 전량 처리 + Cloudflare 콘텐츠 분리 + APK 빌드결함 해소 (사용자 지시: "남은거 동시진행" → 착오 스크린샷 철회 후 "이전에 하던거 완료(옵션 C)")** — ① **Q22 Hive 로컬암호화**: `lib/services/secure_box_service.dart` 신설 — HiveAesCipher(256-bit AES) 키를 최초 1회 생성해 base64로 shared_preferences('hive_aes_key_v1') 저장, `openSecureBox`는 암호화 실패/웹 환경 시 평문 폴백. app_provider.init()에서 sessions/wrongNotes/quizResults 박스를 암호화 박스로 전환(exams·settings는 정적이라 평문 유지) ② **Q40 크래시리포팅(외부SaaS 없이 프라이버시 우선 로컬)**: `lib/services/crash_logger.dart` 신설 — FlutterError.onError + PlatformDispatcher.onError + main() runZonedGuarded 3중 후킹, 최근 30건 링버퍼(prefs 'crash_logs_v1'), exportText/clear/getAll. main.dart를 `_bootstrap` 분리 후 CrashLogger.init 최우선 실행. settings_screen에 '진단·오류 로그' 카드(암호화 잠금상태 표시 + 오류로그 뷰어 바텀시트: 복사/삭제) ③ **Q93 수익모델 명문화**: `docs/MONETIZATION_POLICY.md` — 3단 프리미엄(Free/Premium ₩4,900월/Lifetime ₩79,000), 무료=문항 10%+AI 5회/일, 광고·결제·개인정보 정책 ④ **Q39 CI/CD**: `.github/workflows/ci.yml` — verify 잡(flutter 3.35.4·pub get·analyze·test·web build) + build-apk 잡(main push, APK 아티팩트 업로드) ⑤ **Q37 통합테스트**: `integration_test/app_test.dart`(부팅 렌더·네비 스모크 2건) — **단, integration_test를 pubspec dev_dependencies에 넣으면 GeneratedPluginRegistrant가 IntegrationTestPlugin을 참조해 릴리즈 APK 컴파일 실패**하는 결함 발견 → pubspec에서 제거(온디맨드 추가 방식 주석화)+analysis_options.yaml exclude(integration_test/**)+flutter clean으로 레지스트런트 재생성하여 근본 해소 ⑥ **Cloudflare 콘텐츠 분리 실행**: split_content_for_r2.py 실행 성공(10트랙 16,653문항 → d1_seed.sql 83,616줄 + r2/content 79MB), **R2 본문에 answer 필드 부재 grep 검증 통과**(정답 유출 없음) + backend/cloudflare/DEPLOY.md 배포가이드 신설(**실제 배포는 사용자 Cloudflare 계정 필요, 미배포**) ⑦ **테스트 7건 스펙정합 수정**: cerebras_service_test(BYOK 스펙 재작성)·brand_consistency_test(볼트쌤→Gisaclub)·help_faq_screen_test(FAQ 질문 Gisaclub) → **전 77 테스트 통과** ⑧ **검증(A4)**: analyze **0 issue** + dart format + web release 빌드 + 5060 서빙 200 + **APK 214.3MB 릴리즈 빌드 성공(Q22/Q40 반영)**→releases/gisaclub-R55-release.apk. GATE-1/GATE-2는 이미 완료(150 튜터포즈·10트랙 존재) 확인 | 9e25552 |

| R56 | e43ce36 | **상용화 패키지: 슈퍼관리자 모드 + 원버튼 자동업데이트 + 관리자 무제한 오버라이드 + 상용화 보고서 (사용자 지시: "관리자 슈퍼관리자 모드·자동업데이트·테스트기간 잠금 내가 못풀면 말이안됨·통신판매업 있으니 마켓등록 권장·경쟁분석 보고서")** — ① **AdminService(1차 시도, Google Sign-In+이메일해시)**: `lib/services/admin_service.dart` 신설 — google_sign_in 7.2.0 v7 API(`GoogleSignIn.instance`·`authenticate(scopeHint)`·`GoogleSignInException`), 관리자 이메일 SHA-256 해시(designssir@gmail.com=b530074c…) 비교, `--dart-define=GISACLUB_ADMIN_EMAIL_HASH` 주입 가능, 세션 prefs 저장. **주의: 클라이언트 이메일 비교는 디컴파일 우회 가능(함정 인지)→R57에서 Cloudflare Access로 전환 예정** ② **원버튼 자동업데이트**: `lib/services/app_update_service.dart` — version.json(semver+build int 비교) fetch, `performUpdate()`(store_url→apk_url url_launcher), 강제/권장 업데이트 구분 ③ **관리자 무제한 오버라이드**: `EntitlementService.isPremium`이 `AdminService.isAdmin` 시 무조건 true + `isAdminOverride` getter + `adminSetPlan` 공개 래퍼(debugSetPlan @visibleForTesting 우회), `CerebrasService.getApiKey`가 관리자+`--dart-define=CEREBRAS_ADMIN_KEY` 시 관리자 키 반환 ④ **SuperAdminScreen**: `lib/screens/super_admin_screen.dart` — Google 로그인 잠금화면 + 운영 대시보드(통계/콘텐츠(AdminSettingsScreen)/등급관리/AI/업데이트/진단(크래시로그)/보안) ⑤ **settings_screen**: admin_settings 직접진입 제거→SuperAdminScreen 진입 + `_updateTile`(AppUpdateService watch, 버전/업데이트 표시·performUpdate) ⑥ **AndroidManifest INTERNET 권한 추가**(누락돼있었음, AI/업데이트/로그인 필수) + ACCESS_NETWORK_STATE ⑦ **Cloudflare admin.js**: `backend/cloudflare/src/admin.js` — adminLogin(SHA-256 pw)·requireAdmin·adminListUsers·adminSetUserPlan·adminStats·getVersionManifest(KV SETTINGS)·adminSetVersionManifest + index.js `/v1/app/version`·`/v1/admin/login`·`/v1/admin/*` 라우트 + version.sample.json ⑧ **문서**: docs/ADMIN_SETUP_GUIDE.md(Google OAuth·2단계보안·관리자무제한) + docs/COMMERCIALIZATION_REPORT.md(comcbt·맞추다·전구앱 경쟁분석·3단 가격·GTM·마켓등록 가이드·통신판매업 활용) ⑨ **검증(A4)**: analyze **0 issue** + **전 77 테스트 통과** + web release 빌드 + 5060 서빙 200 + **APK 214.9MB 릴리즈 빌드 성공(google_sign_in 네이티브 플러그인 빌드 파손 없음 확인)**→releases/gisaclub-R56-release.apk | e43ce36 |

| R57 | d46bb35 | **관리자 인증 아키텍처 전면 전환 — Google Sign-In 폐기 → Cloudflare Access(Zero Trust) 하이브리드 (사용자 지시: "Firebase/google_sign_in 전부 폐기, Cloudflare Access로 대체. 도메인 gisa.club, 대시보드 admin.gisa.club, 하이브리드(대시보드=Access·폰앱=서버토큰검증), R56 먼저 커밋 후 진행")** — ① **google_sign_in 7.2.0 전량 제거**: pubspec.yaml에서 삭제(+연쇄 5패키지 제거), 앱에 PIN·하드코딩 이메일·이메일해시 비교·GoogleSignIn 흔적 0건 확인(crypto는 app_provider/backup_service가 계속 사용하므로 유지) ② **AdminService 서버토큰 검증 방식 재작성**(`lib/services/admin_service.dart`): 클라이언트 판정로직 완전 제거. `registerToken(token)`→Worker `/v1/admin/verify`(Bearer) 검증 성공시에만 isAdmin=true, `--dart-define=GISACLUB_API_BASE` 필수(미설정시 관리자모드 불가=안전기본값), init시 저장토큰 백그라운드 재검증(401/403→자동 logout), AdminAuthResult enum(success/invalidToken/notConfigured/network) ③ **SuperAdminScreen 잠금화면 전환**: Google 버튼→토큰 입력/붙여넣기 UI(admin.gisa.club 발급 안내 4단계)+서버검증 로딩·에러 토스트, _securityCard를 Access 방식 설명으로 교체(emailHashOf 참조 제거) ④ **Worker Access JWT 검증**(`backend/cloudflare/src/admin.js` 재작성): `verifyAccessJwt`(JWKS `<team>.cloudflareaccess.com/cdn-cgi/access/certs` RS256 서명검증+aud+exp+이메일화이트리스트), `issueAppToken`(대시보드 Access인증→HMAC 서명 앱토큰 30일 발급), `verifyAppTokenEndpoint`(폰앱 토큰검증), `requireAdmin`(Access JWT 또는 앱토큰 둘중 하나) + index.js `/v1/admin/verify`(공개, 앱토큰 자체검증)·`/v1/admin/issue-app-token`(Access 필요) 라우트 재구성 ⑤ **admin.gisa.club Pages 대시보드 신설**(`backend/admin-dashboard/public/`): index.html+app.js+_headers — 앱토큰 발급·복사, 운영통계, 버전매니페스트 관리(원버튼 업데이트 연동), 사용자 등급관리. Access identity(/cdn-cgi/access/get-identity)로 운영자 이메일 표시, credentials:'include'로 Access 쿠키 전달 ⑥ **wrangler.toml**: SETTINGS KV 바인딩 추가, ACCESS_TEAM_DOMAIN·ACCESS_AUD·ADMIN_ALLOWED_EMAILS vars + ADMIN_TOKEN_SECRET 시크릿 안내, 도메인 gisaclub.com→gisa.club 정정 ⑦ **문서**: docs/ADMIN_SETUP_GUIDE.md(구식 Google Sign-In) 삭제, docs/CLOUDFLARE_ACCESS_SETUP.md 신설(도메인·Google OAuth 클라이언트·Zero Trust Access App·Worker/Pages 배포·cloudflared tunnel 로컬테스트·폰앱 dart-define 연결·운영자 사용순서·보안요약표) + admin-dashboard/README.md ⑧ **검증(A4)**: analyze **0 issue** + **전 77 테스트 통과** + Worker JS `node --check` 통과(admin.js/index.js/app.js) + web release 빌드 + 5060/8899 서빙 200 + **APK 214.4MB 릴리즈 빌드 성공(google_sign_in 제거로 소폭 감소, GeneratedPluginRegistrant GoogleSignIn 참조 0건 확인)**→releases/gisaclub-R57-release.apk | d46bb35 |
| R58 | (this) | **URL 환경변수 중앙화(도메인 비종속) + 데이터 저장정책(SSOT) 정립 + Cloudflare Worker 배포준비 (사용자 지시: "커스텀 도메인 미구매→pages.dev/workers.dev 기본주소 사용, URL 하드코딩 금지·환경변수(API_BASE_URL/WEB_BASE_URL)로 관리해 도메인 전환시 설정만 변경. 서버(D1/KV)가 계정·권한·요금제·학습진도·점수·관리자판정의 SSOT, 로컬은 문제/콘텐츠/이미지/오디오만 캐시 허용·판정근거 금지. 프로젝트 재정리 후 Worker 배포준비")** — ① **AppConfig 중앙화**(`lib/services/app_config.dart` 신설): `API_BASE_URL`·`WEB_BASE_URL`·`UPDATE_MANIFEST_URL`을 `String.fromEnvironment`로 읽고 legacy `GISACLUB_API_BASE`/`GISACLUB_UPDATE_MANIFEST` 하위호환 폴백, 미설정시 빈문자열=안전상태, `resolveUpdateManifestUrl()`(명시값→API베이스/v1/app/version 파생). admin_service·remote_content_api·app_update_service의 `static const _apiBase/_base/_versionManifestUrl`을 전부 AppConfig getter로 전환(하드코딩 URL 제거) ② **EntitlementService SSOT**(R58): 요금제 로컬 영속화 폐지 — init()은 **무조건 free 시작** + 레거시 캐시키(ent_plan_tier/ent_expiry_iso) purge + refreshFromServer 백그라운드, `refreshFromServer`는 서버응답 성공시에만 메모리 승격(`_serverConfirmed`), 실패/오프라인=free, `_applyServerState` void(무영속), adminSetPlan/debugSetPlan 메모리전용 ③ **학습진도/점수 SSOT 설계**: 오프라인학습이 핵심가치라 로컬 write-through 캐시 유지하되 서버 우선 병합 아키텍처 명문화 — `lib/services/progress_sync_service.dart`(pull/push, 서버미설정시 no-op 안전폴백) + AppProvider.init에 정책앵커 주석 + Worker `backend/cloudflare/src/progress.js`(getProgress/putProgress, per-item updatedAt last-write-wins, 서버동률우선) + `/v1/progress` GET/POST 라우트 + `migrations/0002_user_progress.sql`(user_progress 테이블) ④ **도메인 비종속화**: super_admin_screen 안내문구 admin.gisa.club→"관리자 대시보드"+동적 dashboardUrl(WEB_BASE_URL), GISACLUB_API_BASE→API_BASE_URL, api.gisa.club→workers.dev / 대시보드 app.js API_BASE 하드코딩→`window.GISACLUB_CONFIG.apiBase`(config.sample.js 신설, index.html config.js 선로드) / wrangler.toml·admin.js·ARCHITECTURE·DEPLOY·version.sample·README 전부 workers.dev/pages.dev 기본+커스텀도메인 전환주석 ⑤ **문서**: `docs/DATA_STORAGE_POLICY.md` 신설(SSOT vs 캐시허용 분류표·권한/구독/관리자 로컬판정금지 근거·진도 오프라인캐시+서버동기규약·PR체크리스트) + CLOUDFLARE_ACCESS_SETUP.md 전면개정(workers.dev/pages.dev 기본, API_BASE_URL/WEB_BASE_URL dart-define, §10 데이터정책 연계) ⑥ **검증(A4)**: analyze **0 issue** + **전 77 테스트 통과** + Worker JS `node --check` 통과(index/progress/admin.js) + web release 빌드(69.3s) + **APK 214.4MB 릴리즈 빌드 성공(google_sign_in pubspec/lock 부재·GeneratedPluginRegistrant 참조 0건 재확인)**→releases/gisaclub-R58-release.apk | c22faad |
| R59 | (this) | **관리자 전용 앱 신설 + 원격설정(Remote Config) 파이프라인 — "관리자가 세팅→서버 저장→학습앱 자동 반영" (사용자 지시: "배민식 관리자 백오피스처럼 관리자 전용 앱 하나 더. 나(알렉스)만 들어가서 모든 걸 세팅하면 학습앱이 관리자가 설정한 대로 자동 세팅/업데이트되게. 추천대로 진행")** — 아키텍처 결정: **B안(단일 코드베이스 + Android productFlavor 분리)** 채택(백엔드 공유 구조라 코드중복 없는 플레이버가 실무 최적, SSOT정책과 정합). ① **Worker 원격설정 API**: `backend/cloudflare/src/appconfig.js` 신설 — KV(SETTINGS) 단일키 `app_config`에 JSON 스냅샷 저장, `defaultConfig()`(features{aiTutorEnabled·handwritingEnabled·freeQuestionPercent·promoBannerEnabled}·notice{text·level·linkUrl}·update{minSupportedBuild·latestVersion·apkUrl·forced}·activeTracks), `getAppConfig`(없으면 기본값), `putAppConfig`(mergeConfig 서브오브젝트 키단위 병합 + version 서버단조증가·updatedAt) / index.js: **GET `/v1/app/config`(공개, requireSession 이전)** = 학습앱 pull, **PUT `/v1/app/config`(requireAdmin 게이트)** = 관리자 배포. SSOT경계 준수: 여기엔 표현/기능스위치만·사용자별 권한/구독/점수는 미포함 ② **학습앱 수신**: `lib/services/remote_config_service.dart`(ChangeNotifier 싱글턴) — init시 캐시(shared_preferences `remote_app_config_v1`) 먼저반영→온라인이면 백그라운드 refresh pull, version 변경시에만 notify, 불변모델 RemoteAppConfig/Features/Notice/UpdateGate(fromJson/toJson/copyWith·requiresUpdate). main.dart: EntitlementService 다음 `RemoteConfigService.init()` await + MultiProvider 등록(오프라인관용=캐시유지) ③ **관리자 앱**: `lib/main_admin.dart`(별도 엔트리, AdminService.init만·MaterialApp→AdminConsoleScreen·ADMIN 배너) + `lib/admin/admin_console_screen.dart`(기능스위치/공지/업데이트게이트/활성트랙 폼 + "학습앱에 배포하기" FilledButton + 서버버전 뱃지 + 미설정/미인증 가드 + 토큰등록 다이얼로그[AdminService.registerToken 재사용]) + `lib/admin/admin_config_api.dart`(fetch GET / publish PUT Bearer, AdminPublishResult) ④ **Android 플레이버**: build.gradle.kts flavorDimension "app" + user(applicationId 유지)/admin(`.admin` 접미사→한 기기 병존, app_name="Gisaclub 관리자"). 관리자 빌드=`flutter build apk --release --flavor admin -t lib/main_admin.dart` ⑤ **검증(A4)**: analyze **0 issue**(doc-comment HTML경고 2건 backtick수정) + **전 77 테스트 통과** + Worker JS `node --check` 4파일 통과 + web release 빌드(61.5s) + **admin APK 198.3MB + user APK 214.4MB 양쪽 빌드 성공**(assembleAdminRelease/assembleUserRelease)→releases/gisaclub-R59-admin.apk·gisaclub-R59-user.apk. AndroidManifest label "Gisaclub" 복원(서명툴이 되돌린것 정정) | (this) |

> **다음 착수(R60, 사용자 액션 필요)**: **실제 Cloudflare 배포(도메인 없이 즉시 가능)** — ① Google Cloud OAuth 클라이언트 생성(redirect: `<team>.cloudflareaccess.com/cdn-cgi/access/callback`) ② Zero Trust Access Application(도메인=`gisaclub-admin.pages.dev`, Google IdP, designssir@gmail.com Allow) 생성 후 AUD 태그 획득 ③ Worker/Pages 배포(d1/kv/r2 생성·migrations 0001+0002 실행·wrangler.toml 채우기·ADMIN_TOKEN_SECRET 시크릿·`wrangler deploy`→workers.dev / `wrangler pages deploy`→pages.dev) ④ 대시보드 config.js에 workers.dev apiBase 기입 ⑤ 앱을 `--dart-define=API_BASE_URL=https://gisaclub-api.<sub>.workers.dev --dart-define=WEB_BASE_URL=https://gisaclub-admin.pages.dev`로 재빌드(학습앱=user 플레이버, 관리자앱=admin 플레이버 `-t lib/main_admin.dart`). 배포 완료 후 관리자앱에서 원격설정 배포→학습앱 자동반영 E2E 검증. 상세: docs/CLOUDFLARE_ACCESS_SETUP.md·DATA_STORAGE_POLICY.md. **커스텀 도메인(gisa.club) 구매는 선택**(구매 후 dart-define·config.js·Access도메인·wrangler routes 값만 교체, 코드 무수정). 이어서 **Play Billing 실연동** + **개인정보처리방침/이용약관 웹 URL**.
>
> **R59 아키텍처 요약(재개 시 참조)**: 학습앱·관리자앱 = 단일 코드베이스, Android productFlavor(user/admin)로 분리. 관리자 세팅 흐름 = 관리자앱 `AdminConsoleScreen` → `AdminConfigApi.publish()` → Worker `PUT /v1/app/config`(requireAdmin, KV 저장·version++) → 학습앱 `RemoteConfigService.refresh()`가 `GET /v1/app/config` pull → 로컬캐시·notify → UI 자동반영. SSOT경계: 원격설정엔 기능스위치/공지/업데이트게이트/활성트랙만, 권한·구독·점수·관리자판정은 entitlement/progress/admin API가 별도 판정.
>
> **참고(서버 재기동)**: 세션 재개 시 죽어있으면 web=`cd /home/user/flutter_app/build/web && nohup python3 -m http.server 5060 --bind 0.0.0.0 &`, apk다운로드=`cd /home/user/flutter_app/releases && nohup python3 -m http.server 8899 --bind 0.0.0.0 &`.
> **상시 다운로드 서버**: 8899 포트가 `releases/` 디렉터리를 서빙 중. 세션 재개 시 죽어있으면 `cd /home/user/flutter_app/releases && nohup python3 -m http.server 8899 --bind 0.0.0.0 &`로 재기동.
