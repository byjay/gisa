# MASTER_PLAN.md — Cert Study Tracker 절대 지시서 (바이블)

> **문서 지위: 최우선(1순위) 규범 문서.**
> 이 문서는 본 프로젝트의 모든 작업에 우선하는 **바이블**이다.
> 세션이 끊기거나, 컨텍스트가 초기화되거나, 어떤 인터럽트가 발생하더라도
> **작업 재개 시 반드시 이 문서를 가장 먼저 읽고, 여기 정의된 프로토콜대로만 행동한다.**
> 사용자의 명시적 지시 외에는 이 문서와 충돌하는 어떤 판단도 허용하지 않는다.

- 프로젝트: **Cert Study Tracker** (전기기사 자격증 학습 앱)
- 패키지: `com.certstudytracker.study` / 경로: `/home/user/flutter_app/`
- 문서 버전: v1.0 (2026-02 재구상판) — 갱신 시 §9 변경이력에 기록

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

## §6. 갭 분석 (경쟁사 5대 기준 대비 채점표)

| 기준 (§4.2) | 현재 상태 | 판정 | 대응 태스크 |
|---|---|---|---|
| 1. 회차별·과목별 풀이 | 회차별 O (29회차), **과목별 필터 미흡** | △ | T-1 |
| 2. 자동채점→해설 자연 연결 | 채점 O, 해설은 Cerebras 의존·문항 내 즉시 해설 흐름 약함 | △ | T-2 |
| 3. 오답노트 자동 축적 | ProgressService에 오답 기록 O, SmartReview O | ○ | T-2 보강 |
| 4. **북마크**·단원별 복습·약점 확인 | **북마크 없음(치명 갭)**, 약점 분석 부분적 | ✗ | T-1, T-3 |
| 5. 무료/광고 체감 | 완전 무료·광고 없음 | ◎ (우위) | 유지 |
| +. 스트릭 보호 (Duolingo §4.3) | 스트릭 표시만 있고 상실 방지 장치 없음 | △ | T-4 |
| +. CBT 환경 재현 (맞추다) | 일반 퀴즈 UI, 실제 CBT 레이아웃 미재현 | △ | T-5 |

---

## §7. 로드맵 + 태스크별 초세밀 구현 스펙

> 각 태스크는 §1.3 프로토콜(A0→A5)을 완주해야 완료다. 순서 변경은 사용자 지시로만 가능.

### T-1. 문항 북마크 + 과목별 필터 (우선순위 ★★★ — 치명 갭)
- **A1 Researcher**: 완료(§4.2 기준 4). 추가 조사 불필요.
- **A2 Architect 스펙**:
  - 신규 `lib/services/bookmark_service.dart`: shared_preferences 키 `bookmarks_v1`(문항 id Set). API: `Future<Set<String>> load()`, `Future<void> toggle(String qid)`, `bool isBookmarked(String qid)`.
  - `quiz_play_screen.dart`: AppBar actions에 북마크 토글 IconButton(별 아이콘, 채움/비움).
  - `study_screen.dart` 문제풀이 탭: "북마크 모아풀기" 진입 카드 추가 → 북마크된 문항만으로 QuizPlayScreen 구동.
  - 과목 필터: exams.json 문항의 과목 메타(문항 순번 기반 20문항 단위 과목 매핑) → 과목 선택 칩(ChoiceChip 행).
- **A3 Implementer**: 위 스펙만 구현. UI는 PremiumCard/PillBadge 재사용.
- **A4/A5**: 표준 검증·기록.

### T-2. 해설 루프 완결 — "풀기→채점→해설→오답복습" 무단절 (★★★)
- **A2 스펙**:
  - 채점 직후 각 문항 카드에서 접이식(ExpansionTile) 해설 즉시 노출. Cerebras 해설은 캐시(`Hive box 'explanations'`)하여 재호출 방지·오프라인 재열람.
  - 결과 다이얼로그에 "오답 즉시 복습" 버튼 → SmartReviewScreen으로 틀린 문항 id 목록 직접 전달.
  - `cerebras_service.dart`: 실패 시 solution_recipes.json 기반 로컬 폴백 해설.
- **완료 기준**: 네트워크 차단 상태에서도 해설 열람 가능(캐시/폴백).

### T-3. 약점 분석 대시보드 (★★)
- **A2 스펙**: `progress_service.dart` 데이터로 과목×주제(topic_freq.json) 교차 정답률 계산 → stats_screen에 `WeaknessRadarCard` 위젯(과목별 정답률 가로 막대 + "가장 약한 주제 3개" 리스트, 탭 시 해당 주제 문제풀이 진입).

### T-4. 스트릭 보호권 (Streak Shield) (★★ — Duolingo 근거)
- **A2 스펙**: AppProvider에 `shieldCount`(Hive). 일일 미션 올클리어 시 1개 지급(최대 2). 스트릭 끊길 날 자동 소모·유지. home_screen 스트릭 표시에 방패 아이콘+개수. 소모 시 스낵바 알림.

### T-5. CBT 모의고사 모드 (★★)
- **A2 스펙**: 실제 CBT 유사 레이아웃 — 상단 남은시간(150분 카운트다운), 문항 번호 그리드 네비게이터(답함/안함/북마크 색상), 한 문항씩 표시, "검토" 플래그. 기존 quiz_play와 별도 `cbt_exam_screen.dart`. 종료 시 기존 채점·결과 파이프라인 재사용.

### T-6. 마감 후 폴리시: 온보딩 30분 루틴 (★ — 오르조 시사점)
- 첫 실행 감지(shared_preferences `onboarded_v1`) → 3페이지 온보딩(목표 시험일 선택→일일 목표→핵심 루프 안내).

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
| R23 | (이번) | **MASTER_PLAN.md 바이블 제정** — 오케스트레이터 헌장·갭분석·로드맵 | (커밋 후 기입) |

> **다음 착수 태스크: T-1 (북마크 + 과목 필터)** — 사용자 별도 지시 없으면 이 순서를 따른다.
