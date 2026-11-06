# SCOPE — 보상형 광고 보상 지급 설계

## 목표
AdMob 보상형 광고에서 같은 검증된 이벤트가 중복 callback/retry 되어도 이용권이 한 번만 증가하고, 일일 한도를 넘지 않으며, 실패/거절된 검증은 보상이 되지 않는 설계를 검사한다.

## 모델 안
- 사용자 1명, 하루 1개 추가 이용 한도, 서로 다른 광고 reward transaction 2개.
- 두 transaction 각각 Google SSV callback이 두 번 전달될 수 있어 전달 4개를 탐색한다.
- 서명 검증이 성공한 SSV 이벤트만 신뢰된 입력 집합에 포함된다.
- 서버가 중복 판정, 한도 판정, transaction 처리 기록, 보상 원장 반영을 하나의 원자적 DB transaction으로 처리하는 설계와, 분리된 check/apply/record 경로를 비교한다.
- 재시도·중복·동시 순서 교차는 명시적으로 모델링한다.

## 가정
1. Google AdMob이 서명한 transaction_id는 고유하고 transaction callback이 재시도되어도 같은 식별자를 사용한다.
2. 서버는 서명과 허용된 ad unit/reward amount를 확인하고, transaction_id를 검증한 뒤에만 검증된 이벤트로 넘긴다.
3. user identity/custom data는 검증 서명 안에서 읽고 내부 계정/하루 quota에 매핑한다.
4. 보상은 사용자 계정/일자별 ledger에 반영한다. Local client callback만으로 서버 entitlement를 주지 않는다.
5. 한도는 예시로 하루 1개다. 수량이 바뀌어도 프로토콜 속성은 같지만 새 수량으로 재검산해야 한다.
6. DB의 dedupe key와 quota update가 같은 serializable/atomic transaction 또는 동등한 단일 조건부 update로 묶일 수 있다.
7. 이 모델은 사용자 1명/일자 1개 quota만 다룬다. 다중 사용자 격리, 자정 경계, 시간대, 지연 callback, 키 회전, 서명 검증·HTTP 구현, 결제 entitlement는 제외한다.

## 고정 안전 속성
- 각 검증된 Google transaction은 많아야 한 번만 보상 원장에 올라간다.
- 현재 보상 잔액은 원장상 지급 건수와 정확히 일치한다.
- 거절 또는 검증 실패 event는 지급되지 않는다.
- 지급량은 일일 한도를 넘지 않는다.
- 지급/거절 처리된 transaction 집합은 서로 겹치지 않는다.

## 코드 대응 기준
현재 GISACLUB에는 AdMob 연동이 없다. 이 모델은 구현 전 설계 검증이며 향후 `lib/services/rewarded_ad_service.dart`, Worker SSV handler/DB transaction과 대응시켜야 한다. 해당 코드가 생길 때 다시 W6 drift check와 구현 재현 테스트를 수행한다.


The bounded model contains two valid transaction IDs, each with two duplicate deliveries, plus one invalid/unverified event. Daily grant limit is one. The unsigned event must be dropped and cannot increase the ledger.
