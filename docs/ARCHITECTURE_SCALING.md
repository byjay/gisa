# 확장 아키텍처 가이드 — 자격증 10종 확장 & 단일 앱 분리 판매

이 문서는 현재 앱을 (1) 인기 자격증 10종으로 확장하고, (2) 향후 과목/자격증
단위로 분리해 개별 앱으로 판매하기 위한 설계 원칙과 실행 절차를 정리한다.

---

## 1. 핵심 설계 원칙 (이미 반영됨)

### 1-1. 종목(Track) 단위 데이터 격리
- 모든 학습 데이터는 `ExamTrack` (lib/services/exam_track.dart) 단위로 로드된다.
- 각 종목은 고유 `id` + assets 폴더 `dir` 를 갖는다.
  - 문제은행: `assets/data/<dir>/exams.json`
  - 실기: `assets/data/<dir>/silgi.json`
  - 이론: `assets/theory/<dir>/NN.md`
- `StudyData.setTrack()` 로 런타임에 종목을 바꾸면 해당 폴더만 로드한다.
- **새 자격증 추가 = kExamTracks 에 항목 1개 + assets 폴더 1개.** 코드 수정 최소화.

### 1-2. 진척 데이터의 종목 스코프 (충돌 방지)
- `Question.qid = '<trackId>|<examLabel>|<subject>|<no>'`
- 종목 접두어가 있으므로 서로 다른 자격증의 같은 회차/과목/번호가
  진척(오답 횟수·SRS 박스·북마크) 데이터에서 **충돌하지 않는다.**
- 단일 앱으로 분리해도 데이터 이관이 그대로 호환된다.

### 1-3. 종목 무관(공용) 기능
아래 기능은 특정 자격증에 종속되지 않고 모든 종목에서 재사용된다.
- 계산기 허브 (단위환산 13종 + 공식 계산기) — `lib/services/unit_converter.dart`, `formula_calculators.dart`
- 집중 오답노트 — `lib/screens/study/wrong_focus_screen.dart` + `ProgressService`
- 합격 분석 리포트 (회독 트래커 + 약점 진단) — `pass_report_screen.dart`
- SRS 간격반복 복습 — `ProgressService`
- 타이머 / 통계 / 게이미피케이션(레벨·XP·스트릭)

---

## 2. 자격증 10종 확장 절차 (신규 종목 추가)

### 단계 A. 자료 리서치 & 정규화
각 자격증마다 다음을 조사해 JSON 스키마로 정규화한다.
1. 시험 과목 구성 & 과목명 (subjects)
2. 최근 기출문제 (문항: no/subject/topic/question/options/answer/explanation/difficulty/freq_score)
3. 과목별 핵심 이론 (theory/*.md)
4. (실기 있는 종목) 실기 모범답안 (silgi.json)
5. 빈출 토픽 & 반복기출

### 단계 B. assets 폴더 생성
```
assets/data/<new_track_id>/
  ├── exams.json          # 필수 — 문제은행
  ├── silgi.json          # 선택 — 실기
  ├── repeat_questions.json
  ├── mnemonics.json
  └── ...
assets/theory/<new_track_id>/
  ├── 01.md ... NN.md
```

### 단계 C. kExamTracks 에 항목 추가
`lib/services/exam_track.dart` 의 `kExamTracks` 리스트에 `ExamTrack(...)` 1개 추가.
- id, name, dir, subjects, theoryFiles, questionCount 등 채우기.
- pubspec.yaml 의 assets 경로가 폴더를 포함하는지 확인
  (`assets/data/` 처럼 상위 폴더로 등록되어 있으면 자동 포함).

### 단계 D. 검증
```
flutter analyze
flutter build web --release
```
- 종목 선택 화면(track_select_screen)에 새 종목이 자동 노출된다.

### 확장 후보 (인기 자격증 예시 10종)
전기기사 / 전기공사기사 / 소방설비기사(전기) / 소방설비기사(기계) /
전기산업기사 / 산업안전기사 / 위험물산업기사 / 정보처리기사 /
건축기사 / 토목기사 — 시장 수요에 맞춰 우선순위 조정.

---

## 3. 단일 과목/자격증 앱 분리 판매 전략

향후 특정 자격증만 담은 별도 앱으로 출시할 때:

### 3-1. 빌드 플레이버(flavor) 방식 (권장)
- 하나의 코드베이스 유지 + Android product flavor 로 앱 분리.
- flavor 별로 `DEFAULT_TRACK_ID` 를 주입해 해당 종목만 노출/고정.
- 장점: 공용 기능(계산기/오답노트/분석) 개선이 전 제품에 자동 반영.
- applicationId 를 flavor 별로 다르게 (예: `com.certstudytracker.electric`,
  `com.certstudytracker.fire`) 하여 스토어에 개별 등록.

### 3-2. 단일 종목 고정 모드 훅 (미리 마련)
- `AppProvider.selectedTrackId` 를 flavor 상수로 강제 세팅하면
  종목 전환 UI 를 숨기고 단일 자격증 앱처럼 동작 가능.
- 종목 선택/전환 화면(track_select_screen, _SubjectSwitcher)만
  flavor 플래그로 감추면 됨. 데이터 계층은 수정 불필요(이미 종목 스코프).

### 3-3. 과금/구독 (향후)
- 무료: 일부 회차 + 기본 기능
- 프리미엄(인앱결제/구독): 전 회차 + 무제한 오답노트/분석 + 광고 제거
- 종목별 앱은 낮은 단가로, 통합 앱은 번들 구독으로 포지셔닝.

---

## 4. 데이터 스키마 참조

### Question (exams.json 의 questions[])
| 필드 | 타입 | 설명 |
|---|---|---|
| no | int | 문항 번호 |
| subject | string | 과목명 (track.subjects 와 일치) |
| topic | string | 빈출 토픽 (없으면 "기타") |
| question | string | 문제 |
| options | string[] | 보기 4개 |
| answer | int | 정답 (1-based) |
| explanation | string | 해설 |
| difficulty | int | 1=하 2=중 3=상 |
| freq_score | number | 0~100 출제빈도 |
| has_image | bool | 그림문제 여부 |

### 진척(questionProgress box) — qid 키
`{ wrong, correct, last, box, nextDue, bookmarked, subject, topic, reasons{원인:횟수}, lastReason }`

---

## 5. 체크리스트 (새 자격증 온보딩)
- [ ] 과목 구성 확정 (subjects)
- [ ] exams.json 정규화 (최소 최근 5회차)
- [ ] theory/NN.md 작성
- [ ] (해당 시) silgi.json
- [ ] kExamTracks 항목 추가
- [ ] pubspec assets 경로 확인
- [ ] flutter analyze / build web 통과
- [ ] 종목 선택 화면 노출 확인
