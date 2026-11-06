# 모델 ↔ 코드 대응

| 모델 동작/상태 | 실제 코드 | 대응 근거 |
|---|---|---|
| `StartRead`: 요청의 세션 세대를 기록 | `lib/services/remote_content_api.dart:23-32,46-48` | 세션 토큰 변경마다 `_sessionGeneration`을 올리고 `_get` 시작 시 값을 저장한다. |
| `ReceiveRead`: await 뒤 세션 변경 응답을 버림 | `lib/services/remote_content_api.dart:46-52` | HTTP 응답 뒤 세대가 다르면 `session_changed` 예외를 던진다. POST도 `:55-68`에서 같은 검사를 한다. |
| `Logout`: 토큰 무효화와 캐시 제거 | `lib/services/auth_service.dart:288-298` | 사용자/토큰을 먼저 비우고 API 토큰과 세션 콘텐츠 캐시를 제거한 뒤 로컬 자격 증명을 삭제한다. |
| `LoginB`: 계정이 달라질 때 캐시 초기화 후 새 토큰 적용 | `lib/services/auth_service.dart:241-248` | user ID/provider가 달라지면 캐시를 초기화하고 새 세션 토큰을 주입한다. 동기 코드 구간에는 `await`가 없다. |
| `ChangeTrack`: 종목 변경이 캐시 세대를 올림 | `lib/services/study_data.dart:1003-1017` | 종목 ID가 바뀌면 전체 캐시 초기화 함수가 세대를 올린다. |
| `CacheRead`: 이전 세대의 응답은 반환/캐시하지 않음 | `lib/services/study_data.dart:1552-1565` 및 각 로더의 세대 검사 | 응답 뒤 generation이 다르면 캐시 저장 없이 실패/빈 기본값을 돌려준다. |
| CBT/Q-Net 서버 데이터도 세션 변경 시 결과 폐기 | `lib/services/cbt_info_service.dart:40-72`, `lib/services/qnet_schedule_service.dart:105-155` | API 세대 스냅샷을 검사하며 캐시 제거 함수가 메모리 캐시와 번들 캐시를 지운다. |

## 코드 재현

`test/remote_content_api_security_test.dart`의 두 테스트가 각각 토큰 변경 뒤 지연 응답 거부와 캐시 세대 변경 뒤 지연 이론 응답 폐기를 재현한다. 테스트는 응답 본문이 오염 상태를 포함하는지, 새 로드가 새 응답을 가져오는지 확인한다.

## 제한 및 후속 확인

이 모델은 위 단일 비동기 읽기 경계만 검사한다. 이미지 프레임의 진행 중 수신, 영구 진도 데이터의 계정별 저장, 실제 운영 토큰 발급/갱신/만료의 E2E는 보증하지 않는다. APK에서 학습 데이터 파일이 빠져 있어도 인가된 사용자가 수신한 콘텐츠를 기기에서 복사하지 못하게 하는 DRM 보장은 아니다.
