# GISACLUB 앱 원격 서비스 잠금 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원격 서비스가 꺼졌거나 상태 확인이 만료된 설치 앱은 모든 사용자 기능과 업데이트를 막고, 운영자만 복구 화면을 연다.

**Architecture:** 전역 ChangeNotifier가 상태를 조회·poll하고 모든 `MaterialApp` 화면을 잠금 화면으로 덮는다. 원격 `service_disabled` 응답은 같은 상태 관리자에 즉시 반영되며 원격 요청 세대와 `StudyData` 메모리 캐시를 무효화한다. 기존 관리자 토큰으로 유지보수 화면에서 관리 화면을 열 수 있다.

**Tech Stack:** Flutter/Dart, Provider, `http`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-28-remote-service-control.md`

## Global Constraints

- 상태 응답 필드와 경로는 backend plan 계약과 일치해야 한다.
- polling 주기 15초, 마지막 성공 확인 유효 시간 45초.
- 상태 미확인/네트워크 만료는 fail-closed; 운영자 제어 화면은 유지한다.
- 유지보수 중에도 관리자 재인증/상태 복구가 가능해야 한다.
- 운영 Cloudflare 계정/배포는 변경하지 않는다.

## Review Focus

- 앱 부팅/첫 온보딩 중 off 상태가 앱 기능을 노출하지 않는지 — root gate widget test.
- 실행 중 상태 off 응답이 모든 화면을 덮는지 — notifier/widget test.
- 마지막 상태가 45초를 넘기면 offline 기능이 열리지 않는지 — fake-clock unit test.
- off 전 시작한 delayed HTTP response가 cache에 들어오지 않는지 — generation race test.
- 관리자 복구 화면에서만 제어 API가 호출되고 일반 기능이 열리지 않는지 — admin routing test.

---

### Task 1: 상태 모델·통신 서비스

**Files:**
- Create: `lib/services/service_control_service.dart`
- Modify: `lib/services/remote_content_api.dart`
- Modify: `lib/services/app_update_service.dart`
- Test: `test/service_control_service_test.dart`
- Test: `test/remote_content_api_security_test.dart`
- Test: `test/app_update_service_test.dart`

**Interfaces:**
- enum `ServiceAvailability { checking, enabled, disabled, unavailable }`.
- `ServiceControlService.instance.initialize()`, `refresh()`, `reportDisabled(message)`, `isEnabled`, `isAdminOverrideAvailable`.
- Worker contract from backend plan.

- [ ] **Step 1: 정상·차단·만료·복구·지연 응답 tests 작성**
- [ ] **Step 2: focused Flutter tests로 RED 확인** — `flutter test --no-pub test/service_control_service_test.dart test/remote_content_api_security_test.dart`.
- [ ] **Step 3: 상태 관리자/polling·응답 세대 구현**
- [ ] **Step 3a: 차단/상태 미확인 시 버전 조회와 performUpdate를 거부**
- [ ] **Step 4: focused Flutter tests GREEN 확인**.

### Task 2: 앱 전체 잠금 및 운영자 복구 UI

**Files:**
- Create: `lib/screens/service_maintenance_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/screens/super_admin_screen.dart`
- Test: `test/service_maintenance_gate_test.dart`

**Interfaces:** Task 1 state model; backend administrator control route.

- [ ] **Step 1: global gate와 admin control 화면 tests 작성**
- [ ] **Step 2: focused widget test RED 확인** — `flutter test --no-pub test/service_maintenance_gate_test.dart`.
- [ ] **Step 3: MaterialApp global gate, 유지보수·재시도·운영자 화면, 서비스 토글 UI 구현**
- [ ] **Step 4: focused widget test GREEN 및 기존 Flutter suite 실행** — `flutter test --no-pub`.
- [ ] **Step 5: analyzer/format/diff 검사** — `flutter analyze --no-pub`; `dart format --output=none --set-exit-if-changed lib test`; `git diff --check`.
