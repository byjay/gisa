# 세션·학습 콘텐츠 격리 모델 범위

## 질문

로그아웃, 계정 전환, 자격증 종목 전환이 진행 중일 때 먼저 시작된 비동기 학습 콘텐츠 응답이 뒤늦게 도착해 현재 캐시를 오염시키는가?

## 상태와 가정

- 사용자 두 명(`A`, `B`), 세션 세대와 학습 캐시 세대 각각 0–3, 진행 중 읽기 하나, 콘텐츠 캐시 존재 여부 하나로 축약했다.
- 모델의 HTTP 응답은 요청을 시작한 사용자/세션·캐시 세대에 귀속된다. 로그아웃·계정 전환·종목 변경은 캐시 세대를 올리고 캐시를 비운다.
- `FixEnabled=TRUE`는 코드의 세션 세대 및 캐시 세대 확인을 모델링한다. `FALSE`는 응답/캐시 쓰기 가드를 일부러 제거한다.
- 속성 `NoCrossSessionCache`: 캐시가 차 있으면 현재 세션이 존재하고, 캐시 소유자와 현재 세션 및 캐시 세대가 일치해야 한다.
- `CacheNeverPopulated`는 정상 동작 속성이 아니라 검사 도달성 확인용으로, 캐시 생성 시 의도적으로 실패해야 한다.

## 범위 밖

실제 Cloudflare/R2 권한·배포 설정, TLS/Worker 운영환경, 기기 포렌식, 앱 메모리 덤프, 영구 학습 진도/Hive 사용자 분리, 사용자별 진도 서버 동기화, 다중 동시 요청의 전체 스케줄링, 이미지 디코더의 진행 중 프레임 수신, 결제/광고 상태는 모델링하지 않았다. TLA+ 통과는 이 유한 상태 모델의 범위에 한정된다.

## 실행

고정 TLC 1.8.0: `java -cp C:\Users\FREE\.cache\proof-skills\tla2tools.jar tlc2.TLC -config MC.cfg SessionContentBoundary.tla`

반례 스위치: 같은 명령에서 `MC.cfg`를 `MC_bug.cfg`로 바꾼다. 도달성 sanity: `MC_sanity.cfg`를 사용한다. 각 실행 로그는 `evidence/`에 보관한다.

## 결과

- 고정 모델: `NoCrossSessionCache`와 `TypeOK` 전체 도달 상태 검사 통과. 155 states generated, 111 distinct states, depth 7.
- 결함 스위치: `NoCrossSessionCache` 위반(exit 12) 확인. 완료 전 요청의 캐시 쓰기 가드를 제거하면 로그아웃 뒤 세션 없는 상태에 이전 응답이 저장된다.
- Sanity: 캐시가 절대 채워지지 않는다는 잘못된 속성이 의도대로 실패(exit 12), 데이터가 캐시에 도달하는 경로를 TLC가 검사함을 확인했다.
