import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../screens/study/tutor_chat_screen.dart';
import '../services/tutor_behavior.dart';
import 'persistent_nav.dart';
import 'tutor_avatar.dart';

/// 🎓 볼트쌤 상황 — 앱의 모든 순간을 커버하는 1:1 과외 상황 정의
enum CoachSituation {
  homeMorning, // 홈 아침
  homeAfternoon, // 홈 낮
  homeNight, // 홈 밤
  homeStreak, // 연속 학습 중
  homeComeback, // 오랜만에 복귀
  quizStart, // 문제 풀이 시작
  quizCorrect, // 정답
  quizCorrectStreak, // 연속 정답
  quizWrong, // 오답
  quizWrongRepeat, // 반복 오답
  quizHardQuestion, // 고난도 문제
  quizAlmostDone, // 막바지
  resultPass, // 모의 합격
  resultFail, // 모의 불합격
  resultPerfect, // 만점
  roadmapStart, // 로드맵 첫 진입
  roadmapProgress, // 로드맵 진행 중
  roadmapDone, // 로드맵 완주
  flashcard, // 플래시카드
  theory, // 이론 학습
  formula, // 공식 학습
  timerFocus, // 집중 타이머
  statsGood, // 통계 상승
  statsBad, // 통계 하락
  dDayFar, // 시험 멀었을 때
  dDayNear, // 시험 임박
  encourage, // 범용 응원
}

/// 볼트쌤 멘트 엔진 — 상황 × 수준(왕초보/중급/상급)별 실제 과외 선생님 대사.
/// 매 호출마다 다른 멘트가 나와 살아있는 튜터처럼 느껴지게 한다.
class TutorMents {
  static final _rand = Random();

  /// level: 0=왕초보, 1=중급, 2=상급 (정답률 기반으로 화면에서 결정)
  static String pick(CoachSituation s, {int level = 0}) {
    final list = _ments[s]![level.clamp(0, 2)];
    return list[_rand.nextInt(list.length)];
  }

  static TutorMood moodOf(CoachSituation s) {
    switch (s) {
      case CoachSituation.quizCorrect:
      case CoachSituation.quizCorrectStreak:
      case CoachSituation.resultPass:
      case CoachSituation.resultPerfect:
      case CoachSituation.roadmapDone:
      case CoachSituation.statsGood:
        return TutorMood.happy;
      case CoachSituation.quizWrong:
      case CoachSituation.quizWrongRepeat:
      case CoachSituation.resultFail:
      case CoachSituation.statsBad:
        return TutorMood.wrong;
      case CoachSituation.theory:
      case CoachSituation.formula:
      case CoachSituation.roadmapStart:
      case CoachSituation.roadmapProgress:
      case CoachSituation.quizStart:
        return TutorMood.teaching;
      case CoachSituation.quizHardQuestion:
      case CoachSituation.flashcard:
        return TutorMood.thinking;
      case CoachSituation.timerFocus:
        return TutorMood.meditate;
      case CoachSituation.quizAlmostDone:
      case CoachSituation.dDayNear:
      case CoachSituation.encourage:
      case CoachSituation.homeStreak:
        return TutorMood.cheer;
      default:
        return TutorMood.idle;
    }
  }

  // [상황][수준 0/1/2][멘트들]
  static final Map<CoachSituation, List<List<String>>> _ments = {
    CoachSituation.homeMorning: [
      [
        '좋은 아침! 오늘은 딱 10분만 같이 해볼까요? 아침 뇌는 암기가 제일 잘 돼요 ☀️',
        '일어나자마자 플래시카드 5장! 어제 본 게 아직 머리에 남아있을 때 굳혀요.',
        '아침 커피 한 잔과 용어 3개, 그거면 오늘 몫은 충분해요.',
      ],
      [
        '아침 골든타임이에요! 어제 틀린 문제부터 다시 볼까요?',
        '기상 직후 복습은 기억 정착률이 2배예요. 긴급 복습부터 가요!',
        '오전엔 계산 문제가 잘 풀려요. 회로이론 어때요?',
      ],
      [
        '상위권 루틴: 아침엔 고난도 계산, 밤엔 암기. 바로 시작하죠!',
        '오늘 목표 정답률 80%. 어제의 나를 이겨봅시다.',
        '아침 모의 1회전 어때요? 실전 시험도 오전이니까요.',
      ],
    ],
    CoachSituation.homeAfternoon: [
      [
        '점심 먹고 졸리죠? 가벼운 플래시카드로 뇌를 깨워요 🃏',
        '오후엔 부담 없이! 이론 한 단원만 그림책처럼 훑어봐요.',
        '지금 5문제만 풀어도 오늘 할 일 절반은 한 거예요.',
      ],
      [
        '오후 슬럼프엔 문제 풀이가 약이에요. 10문제 스프린트 가요!',
        '틀린 문제 3개만 다시 봐요. 오답이 실력이 되는 시간이에요.',
        '오후엔 과목을 바꿔보세요. 뇌가 신선해져요.',
      ],
      [
        '집중력 유지 잘 하고 있어요. 이 페이스로 취약 토픽 정리하죠.',
        '오후 목표: 취약 과목 정답률 +5%. 바로 갑니다.',
        '실전 모드 절반 회차 어때요? 시간 감각 훈련이 필요해요.',
      ],
    ],
    CoachSituation.homeNight: [
      [
        '자기 전 암기가 제일 오래 남아요. 용어 3개만 보고 자요 🌙',
        '오늘 하루도 수고했어요! 플래시카드 5장으로 마무리해요.',
        '밤엔 새 걸 배우지 말고, 오늘 본 것만 가볍게 복습해요.',
      ],
      [
        '수면 직전 복습은 기억 고정 효과가 최고예요. 오답만 훑고 자요!',
        '오늘 배운 공식 2개, 눈 감고 떠올려보세요. 그게 진짜 복습이에요.',
        '내일 아침에 다시 만나요. 지금은 가볍게 암기법만!',
      ],
      [
        '오늘 학습 데이터 좋네요. 자기 전 취약 토픽 1개만 정리하죠.',
        '밤 10분 복습이 내일 30분을 아껴줘요. 스마트 복습 가요.',
        '수면도 전략이에요. 오답 정리하고 푹 자요!',
      ],
    ],
    CoachSituation.homeStreak: [
      [
        '연속 학습 중이에요! 습관이 생기고 있어요, 이게 제일 어려운 건데 해냈네요 🔥',
        '매일 조금씩이 최고의 공부법이에요. 오늘도 이어가요!',
        '스트릭이 쌓일수록 합격이 가까워져요. 오늘 몫 딱 10분!',
      ],
      [
        '스트릭 유지 중! 이 흐름에 오답 정리까지 하면 완벽해요.',
        '꾸준함이 실력을 이기는 법은 없어요. 실력이 되고 있으니까요!',
        '연속 학습 보너스 타임! 오늘은 한 문제 더 풀어볼까요?',
      ],
      [
        '스트릭 + 고정답률, 합격자 패턴 그 자체예요. 유지합시다.',
        '이 페이스면 시험장에서 떨 이유가 없어요. 오늘도 정진!',
        '루틴이 완성됐네요. 이제 약점 정밀 타격만 남았어요.',
      ],
    ],
    CoachSituation.homeComeback: [
      [
        '다시 와줬네요! 쉬었다 와도 괜찮아요. 오늘은 아주 가볍게 5문제만 해요 😊',
        '돌아온 게 제일 중요해요. 부담 없이 플래시카드부터!',
        '까먹은 것 같아도 걱정 마요. 다시 보면 금방 돌아와요.',
      ],
      [
        '오랜만이에요! 복습 큐에 기다리는 문제들부터 정리해요.',
        '쉬는 동안 잊은 건 긴급 복습으로 되살려요. 30분이면 충분!',
        '컴백 기념 가볍게 10문제 스프린트 어때요?',
      ],
      [
        '복귀 환영! 데이터 보니 감각 회복엔 모의 반 회차가 제격이에요.',
        '쉬기 전 실력은 그대로예요. 취약 토픽만 빠르게 점검하죠.',
        '컴백 첫날은 진단이 우선. 모의로 현재 위치 확인해요.',
      ],
    ],
    CoachSituation.quizStart: [
      [
        '틀려도 괜찮아요! 지금은 시험이 뭘 묻는지 구경하는 시간이에요.',
        '모르는 문제는 찍고 해설을 읽어요. 그게 왕초보의 정석이에요!',
        '한 문제 한 문제가 다 공부예요. 부담 없이 가요!',
      ],
      [
        '시작! 아는 문제부터 확실히, 헷갈리면 북마크하고 넘어가요.',
        '오늘은 정확도에 집중해요. 속도는 나중에 따라와요.',
        '풀면서 "왜"를 생각하면 한 문제로 세 문제 값을 해요.',
      ],
      [
        '실전처럼! 문제당 54초 페이스 의식하면서 가요.',
        '함정 선지 패턴 기억하죠? 절대·항상·모든 이 단어들 조심!',
        '고득점 비결은 검토예요. 다 풀고 2분 검토 습관!',
      ],
    ],
    CoachSituation.quizCorrect: [
      [
        '정답!! 봤죠? 할 수 있다니까요! 🎉',
        '맞았어요! 방금 그 감각 기억해둬요.',
        '오~ 정답! 왕초보 졸업이 머지않았어요!',
      ],
      ['정답! 풀이 과정도 깔끔했어요.', '좋아요! 이 유형은 이제 자신 있죠?', '정확해요! 다음 난이도로 가볼까요?'],
      ['역시! 이 정도는 이제 몸이 풀죠.', '정답. 페이스 좋아요, 시간도 단축됐어요.', '완벽한 풀이! 실전에서도 이렇게만.'],
    ],
    CoachSituation.quizCorrectStreak: [
      [
        '연속 정답!! 지금 완전 물올랐어요! 🔥',
        '와, 계속 맞히네요! 오늘 뭔가 다른데요?',
        '3연속 정답이에요! 이 기세로 쭉!',
      ],
      [
        '연속 정답 행진! 이 유형은 완전히 잡았네요.',
        '스트릭 유지 중! 집중력이 최고조예요.',
        '연달아 정답! 난이도 한 단계 올려볼까요?',
      ],
      [
        '퍼펙트 런! 이대로 만점 가나요? 👀',
        '연속 정답 — 실전이었으면 지금 합격권이에요.',
        '흠잡을 데가 없네요. 최고 난도로 가죠.',
      ],
    ],
    CoachSituation.quizWrong: [
      [
        '괜찮아요! 지금 틀린 건 시험장에서 안 틀리려고 틀리는 거예요.',
        '틀렸다 = 배울 게 하나 생겼다! 해설 같이 봐요.',
        '처음엔 다 틀려요. 저만 믿고 해설 한 번 읽어봐요!',
      ],
      [
        '아깝네요! 어디서 갈렸는지 해설에서 딱 짚어봐요.',
        '이 유형 함정이 있었죠? 다음엔 안 속아요.',
        '오답 노트에 자동 저장했어요. 내일 다시 만나요, 이 문제!',
      ],
      [
        '이 문제는 함정 설계가 좋네요. 출제 의도를 분석해봐요.',
        '실수인지 개념 구멍인지 구분해요. 해설에서 확인!',
        '상급자의 오답은 보물이에요. 완전히 분해해봅시다.',
      ],
    ],
    CoachSituation.quizWrongRepeat: [
      [
        '이 문제 또 만났네요! 이번엔 기초 이론부터 같이 봐요. 제가 있잖아요!',
        '반복 오답은 부끄러운 게 아니라 "여기가 내 약점"이라는 지도예요.',
        '이번엔 외우지 말고 이해해봐요. 아래 이론 버튼 눌러요!',
      ],
      [
        '두 번째 오답이에요. 이 토픽 이론을 5분만 정독하고 다시 풀어요.',
        '반복 오답 = 개념 구멍. 강의 시트로 뿌리 뽑읍시다.',
        '이 유형만 모아서 집중 공략할 때가 됐어요.',
      ],
      [
        '반복 오답이라니 의외네요. 개념 연결고리를 다시 점검해요.',
        '이 문제의 변형 패턴까지 함께 정리해두죠. 재발 방지!',
        '오답 원인 분석: 개념? 계산? 함정? 정확히 짚고 갑시다.',
      ],
    ],
    CoachSituation.quizHardQuestion: [
      [
        '이건 어려운 문제예요! 틀려도 전혀 이상하지 않아요. 도전 자체가 대단해요.',
        '고난도 문제예요. 천천히, 아는 것부터 지워나가요.',
        '어려우면 찍고 해설을 봐요. 그것도 훌륭한 전략이에요!',
      ],
      [
        '고난도! 이런 건 부분 점수 딴다는 마음으로 접근해요.',
        '어려운 문제일수록 기본 공식으로 돌아가요.',
        '함정 많은 문제예요. 선지 소거법으로 가요.',
      ],
      [
        '변별력 문제네요. 이걸 맞히면 상위 10%예요.',
        '고난도 — 출제자의 의도를 역으로 추적해봐요.',
        '이런 문제가 합격과 고득점을 가르죠. 집중!',
      ],
    ],
    CoachSituation.quizAlmostDone: [
      [
        '거의 다 왔어요! 마지막까지 저랑 같이 가요! 💪',
        '조금만 더! 끝나고 결과 보면 뿌듯할 거예요.',
        '마지막 문제들이에요. 편하게, 아는 만큼만!',
      ],
      [
        '막판 스퍼트! 집중력 한 번만 더 끌어올려요.',
        '거의 끝! 헷갈렸던 북마크 문제 다시 볼 준비해요.',
        '마지막까지 페이스 유지! 좋아요.',
      ],
      [
        '피니시 라인 보여요. 검토 시간 확보하며 마무리!',
        '막판 실수만 조심해요. 다 잡은 점수 놓치지 않기!',
        '마지막 문제까지 완주 — 실전 체력 완성이에요.',
      ],
    ],
    CoachSituation.resultPass: [
      [
        '합격점이에요!! 이게 진짜라니까요! 자신감 가져도 돼요! 🎉',
        '봤죠?! 아무것도 몰랐던 때를 생각해봐요. 엄청 성장했어요!',
        '합격권이에요! 이 조자로 진짜 시험도 통과합시다!',
      ],
      [
        '합격점 돌파! 이제 안정권 만들기로 목표 상향해요.',
        '좋은 점수예요! 과락 위험 과목만 다듬으면 완벽해요.',
        '합격권 진입! 오답 정리로 굳히기 들어가요.',
      ],
      [
        '여유 있는 합격점이네요. 이젠 고득점 전략으로 전환하죠.',
        '안정권이에요. 실전 변수 대비만 남았어요.',
        '이 점수면 시험장에서 긴장해도 합격이에요. 훌륭해요!',
      ],
    ],
    CoachSituation.resultFail: [
      [
        '아직 합격점은 아니지만, 시작할 때보다 확실히 늘었어요. 그게 중요해요!',
        '지금 점수는 "현재 위치"일 뿐이에요. 오답 하나씩 잡으면 올라가요!',
        '괜찮아요! 모의에서 틀린 만큼 실전에서 맞히는 거예요.',
      ],
      [
        '합격점까지 얼마 안 남았어요. 틀린 과목 위주로 일주일만 투자해요.',
        '점수보다 오답 분포를 봐요. 잡을 수 있는 문제가 보여요.',
        '이번 모의는 진단이에요. 처방은 제가 도와줄게요!',
      ],
      [
        '평소 실력보다 낮네요. 컨디션? 함정? 원인 분석부터 하죠.',
        '데이터를 보면 특정 토픽 집중 실점이에요. 정밀 타격 갑시다.',
        '이 점수는 우연이에요. 취약점 3개만 잡으면 바로 회복돼요.',
      ],
    ],
    CoachSituation.resultPerfect: [
      [
        '만점?!! 이게 가능하다니! 오늘은 자랑해도 되는 날이에요! 🏆',
        '완벽해요!! 처음 시작할 때 기억나요? 기적 같은 성장이에요!',
        '만점이에요! 이 스크린샷 저장해두세요!',
      ],
      [
        '만점! 이 유형은 완전 정복이네요. 다음 챕터로!',
        '퍼펙트! 이 감각을 실전까지 유지하는 게 과제예요.',
        '만점 축하해요! 난이도를 올려도 되겠어요.',
      ],
      [
        '만점 — 당연한 결과지만 그래도 멋지네요. 👏',
        '퍼펙트 스코어. 이젠 속도 기록에 도전해볼까요?',
        '만점! 출제자와의 수 싸움에서 완승이에요.',
      ],
    ],
    CoachSituation.roadmapStart: [
      [
        '환영해요! 아무것도 몰라도 괜찮아요. 제가 STEP 0부터 손잡고 갈게요!',
        '모두가 여기서 시작했어요. 오늘은 딱 한 칸만 체크해봐요!',
        '합격까지 가는 지도예요. 길은 제가 알아요, 걷기만 해요!',
      ],
      [
        '로드맵 시작! 기초가 있으니 STEP 2부터 가도 좋아요.',
        '단계별로 가면 절대 길을 잃지 않아요. 오늘 목표 정해볼까요?',
        '이 로드맵대로만 하면 돼요. 페이스는 제가 관리할게요.',
      ],
      [
        '로드맵 점검이군요. 현재 실력이면 STEP 4 과목 정복 단계네요.',
        '기본기는 충분해요. 취약 단계만 골라 밟고 가죠.',
        '로드맵 후반부 집중! 실전 모드가 코앞이에요.',
      ],
    ],
    CoachSituation.roadmapProgress: [
      [
        '한 단계씩 올라가고 있어요! 이 속도 딱 좋아요.',
        '체크가 늘어나는 거 보이죠? 그게 다 실력이에요!',
        '지금처럼만 해요. 서두를 필요 전혀 없어요!',
      ],
      [
        '순조로워요! 다음 단계 미리보기 해둘까요?',
        '진행률이 좋아요. 이 단계 마무리 문제 풀어봐요.',
        '중간 점검: 지금까지 배운 용어 5개 말할 수 있나요?',
      ],
      [
        '로드맵 후반전! 완주가 보여요.',
        '진도가 빨라요. 깊이도 함께 챙기며 가죠.',
        '이 페이스면 예정보다 일찍 실전 모드 진입이에요.',
      ],
    ],
    CoachSituation.roadmapDone: [
      [
        '로드맵 완주!! 아무것도 몰랐던 사람이 여기까지 왔어요! 🎓',
        '전 단계 클리어! 이제 왕초보가 아니에요. 진짜예요!',
        '완주 축하해요! 다음은 실전 모의로 실력 확인!',
      ],
      [
        '로드맵 완주! 이제 실전 사이클로 전환합시다.',
        '전 과정 수료! 남은 건 반복과 실전 감각이에요.',
        '완주 — 이제 모의고사 점수로 증명할 시간이에요.',
      ],
      [
        '완주요? 이제 제가 가르칠 게 별로 없네요. 😎',
        '로드맵 졸업! 시험일까지 고득점 루틴만 유지해요.',
        '완주 + 이 실력. 합격은 시간문제예요.',
      ],
    ],
    CoachSituation.flashcard: [
      [
        '카드 뒤집기 전에 3초만 생각해요! 그 3초가 암기의 핵심이에요.',
        '모르면 바로 뒤집어도 돼요. 여러 번 만나면 저절로 외워져요!',
        '하루 10장이면 충분해요. 부담 갖지 말아요!',
      ],
      [
        '헷갈린 카드는 솔직하게 "모름" 눌러요. 그래야 또 나와요.',
        '카드 앞면 보고 설명까지 떠올리면 완벽한 암기예요.',
        '암기 카드는 아침·저녁 2회전이 국룰이에요!',
      ],
      [
        '이미 아는 카드는 과감히 넘겨요. 시간은 약점에 써야죠.',
        '카드 내용을 다른 사람에게 설명하듯 말해봐요. 최강 암기법!',
        '연관 카드끼리 묶어서 스토리로 만들어봐요.',
      ],
    ],
    CoachSituation.theory: [
      [
        '외우려고 하지 말고 그림책처럼 훑어봐요. 2회독부터 갑자기 쉬워져요!',
        '모르는 단어가 나와도 멈추지 말아요. 표시만 해두고 쭉!',
        '이론은 문제를 위한 예고편이에요. 가볍게 봐요!',
      ],
      [
        '이론 읽으며 "이거 문제로 나오면 어떻게 나올까?" 생각해봐요.',
        '핵심 문장에 나만의 표시를 해요. 2회독 때 그것만 봐도 돼요.',
        '이론 한 단원 끝나면 바로 관련 문제 3개! 그게 정착 비결.',
      ],
      [
        '이론의 "왜"를 파고들어요. 원리를 알면 변형 문제도 무섭지 않죠.',
        '단원 간 연결고리를 그려봐요. 상급자는 구조로 기억해요.',
        '이 단원 출제 포인트 예측해보고 기출과 대조해봐요.',
      ],
    ],
    CoachSituation.formula: [
      [
        '공식은 생김새부터 친해져요. 왜 이렇게 생겼는지 스토리를 알면 안 까먹어요!',
        '공식 하나에 예제 하나! 세트로 기억해요.',
        '지금 다 못 외워도 돼요. 문제 풀다 보면 손에 붙어요.',
      ],
      [
        '공식의 각 기호가 뭘 뜻하는지 말로 설명해봐요.',
        '단위를 따라가면 공식이 저절로 검증돼요.',
        '비슷한 공식끼리 비교표를 만들면 헷갈림 끝!',
      ],
      [
        '공식 유도 과정을 한 번 따라가봐요. 그럼 평생 안 잊어요.',
        '극한 조건(0, 무한대)을 넣어보면 공식 이해도가 완성돼요.',
        '이 공식의 변형 출제 패턴 3가지, 같이 정리해볼까요?',
      ],
    ],
    CoachSituation.timerFocus: [
      [
        '집중 시작! 저도 옆에서 조용히 응원할게요. 🧘',
        '딴생각 나면 심호흡 한 번! 다시 문제로 돌아와요.',
        '25분만 집중해봐요. 끝나면 꼭 쉬고요!',
      ],
      [
        '집중 모드 ON. 폰 알림은 잠시 꺼둬요.',
        '한 세션 한 목표! 이번엔 뭘 끝낼까요?',
        '집중력은 근육이에요. 오늘도 한 세트 !',
      ],
      [
        '딥워크 타임. 최고 난도 문제와 정면승부하기 좋은 시간이에요.',
        '집중 세션 기록 갱신 가나요? 응원합니다.',
        '몰입 상태 진입! 방해 요소 완전 차단하고 갑니다.',
      ],
    ],
    CoachSituation.statsGood: [
      [
        '그래프가 올라가고 있어요! 이게 다 하나씩 해낸 결과예요! 📈',
        '지난주보다 늘었어요! 눈에 보이죠? 진짜 성장이에요.',
        '정답률 상승 중! 이 재미로 공부하는 거예요!',
      ],
      [
        '상승 곡선 유지 중! 취약 과목도 끌어올려봐요.',
        '데이터가 증명해요 — 방법이 맞다는 걸. 계속 가요!',
        '이 추세면 목표 정답률 도달이 코앞이에요.',
      ],
      [
        '전 과목 고른 상승세. 관리형 학습의 정석이에요.',
        '상위권 지표예요. 이제 편차 줄이기에 집중하죠.',
        '통계가 아름답네요. 실전 재현만 남았습니다.',
      ],
    ],
    CoachSituation.statsBad: [
      [
        '숫자에 너무 신경 쓰지 마요! 공부한 날이 있다는 게 중요해요.',
        '떨어질 때도 있어요. 오늘 5문제만 풀면 다시 올라가요!',
        '그래프는 잠깐 쉰 것뿐이에요. 실력은 그대로 있어요!',
      ],
      [
        '일시적 하락이에요. 오답 유형만 점검하면 금방 회복돼요.',
        '난도 높은 문제에 도전한 흔적이네요. 좋은 하락이에요!',
        '하락 구간 = 성장 직전 구간. 데이터가 그래요!',
      ],
      [
        '하락 원인 분석: 신규 유형? 컨디션? 데이터로 짚어봅시다.',
        '슬럼프도 관리 대상이에요. 부하 조절하며 가죠.',
        '단기 하락은 노이즈예요. 주간 추세로 판단합시다.',
      ],
    ],
    CoachSituation.dDayFar: [
      [
        '시험까지 여유 있어요! 지금은 기초를 단단히 할 최고의 시기예요.',
        '서두르지 않아도 돼요. 매일 조금씩이 결국 이겨요.',
        '지금 시작한 게 최고의 선택이에요. 남들보다 앞서 있어요!',
      ],
      [
        '준비 기간 충분! 전 과목 1회독 플랜 세워볼까요?',
        '지금은 이해 위주로, 막판엔 암기 위주로. 전략대로 가요.',
        '여유 있을 때 취약 과목부터 정면 돌파해요.',
      ],
      [
        '장기 플랜 구간이에요. 주간 목표로 쪼개서 관리하죠.',
        '지금 페이스면 시험 한 달 전 완성이에요. 이상적입니다.',
        '기초 완성 후 고난도 정복까지, 시간표가 완벽해요.',
      ],
    ],
    CoachSituation.dDayNear: [
      [
        '시험이 코앞! 새로운 건 그만, 아는 것만 확실하게 다져요!',
        '긴장돼도 괜찮아요. 지금까지 한 게 어디 안 가요!',
        '마지막엔 암기법과 요약만! 컨디션이 실력이에요.',
      ],
      [
        '디데이 임박! 오답 노트와 빈출 토픽만 회전시켜요.',
        '실전 시뮬레이션 주 2회, 나머진 오답 정리. 이게 막판 공식!',
        '시험 시간대에 맞춰 공부 시간을 옮겨봐요. 몸이 기억해요.',
      ],
      [
        '파이널 스퍼트. 실수 리스트 만들어서 시험장 가져가요.',
        '막판엔 뇌 컨디션 관리가 1순위. 수면 사수!',
        '이미 합격 실력이에요. 남은 건 그대로 재현하기.',
      ],
    ],
    CoachSituation.encourage: [
      [
        '오늘도 와줘서 고마워요! 같이 하면 무조건 돼요!',
        '어제의 나보다 한 문제만 더! 그거면 충분해요.',
        '포기만 안 하면 제가 합격까지 데려다줄게요!',
      ],
      [
        '꾸준함이 재능을 이기는 중이에요. 계속 가요!',
        '오늘 한 시간이 시험장에서 열 점이 돼요.',
        '흔들릴 땐 처음 시작한 이유를 떠올려요. 그리고 한 문제!',
      ],
      [
        '이 정도 페이스면 제가 배우고 싶을 정도예요. 😄',
        '정상이 보여요. 마지막 구간도 함께합니다.',
        '실력은 이미 충분해요. 오늘은 유지 보수의 날!',
      ],
    ],
  };
}

/// 🎓 동적 튜터 배너 — 정적 메시지 대신 상황(CoachSituation)별로
/// 선택된 선생님의 행동패턴 뱅크/멘트 엔진에서 매번 다른 멘트를 고른다.
/// [overrideMessage]가 있으면(데이터 기반 설명 등) 그 내용을 우선 표시.
class DynamicTutorBanner extends StatefulWidget {
  final CoachSituation situation;
  final String? overrideMessage;
  final double avatarSize;
  final VoidCallback? onTap;

  const DynamicTutorBanner({
    super.key,
    required this.situation,
    this.overrideMessage,
    this.avatarSize = 72,
    this.onTap,
  });

  @override
  State<DynamicTutorBanner> createState() => _DynamicTutorBannerState();
}

class _DynamicTutorBannerState extends State<DynamicTutorBanner> {
  String? _message;
  String? _messageTutorId;

  @override
  void didUpdateWidget(DynamicTutorBanner old) {
    super.didUpdateWidget(old);
    if (old.situation != widget.situation ||
        old.overrideMessage != widget.overrideMessage) {
      _message = null; // 상황이 바뀌면 새 멘트 선택
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorId = context.select<AppProvider, String>(
      (app) => app.selectedTutorId,
    );
    if (_message == null || _messageTutorId != tutorId) {
      _message = widget.overrideMessage ??
          TutorBehaviorBank.pick(tutorId, widget.situation) ??
          TutorMents.pick(widget.situation);
      _messageTutorId = tutorId;
    }
    return TutorBanner(
      mood: TutorMents.moodOf(widget.situation),
      message: _message!,
      avatarSize: widget.avatarSize,
      onTap: widget.onTap,
    );
  }
}

/// 🎓 전신 볼트쌤 코치 카드 — 어떤 화면에든 배치하는 1:1 과외 위젯.
/// 전신(잘림 없음) + 상황별 멘트 + 탭하면 볼트쌤 채팅으로 연결.
class TutorCoach extends StatefulWidget {
  final CoachSituation situation;
  final int level; // 0=왕초보 1=중급 2=상급
  final String? overrideMessage;
  final double height;
  final bool linkToChat;

  const TutorCoach({
    super.key,
    required this.situation,
    this.level = 0,
    this.overrideMessage,
    this.height = 118,
    this.linkToChat = true,
  });

  @override
  State<TutorCoach> createState() => _TutorCoachState();
}

class _TutorCoachState extends State<TutorCoach> {
  String? _message;
  String? _messageTutorId;

  /// 선택된 캐릭터의 100+ 행동패턴 뱅크를 우선 사용하고,
  /// 등록되지 않은 조합이면 공용 멘트(TutorMents)로 대체한다.
  String _pickMessage(String tutorId) {
    return widget.overrideMessage ??
        TutorBehaviorBank.pick(tutorId, widget.situation) ??
        TutorMents.pick(widget.situation, level: widget.level);
  }

  @override
  void didUpdateWidget(TutorCoach old) {
    super.didUpdateWidget(old);
    if (old.situation != widget.situation ||
        old.overrideMessage != widget.overrideMessage) {
      _message = null; // 다음 build에서 새 멘트 선택
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mood = TutorMents.moodOf(widget.situation);
    final tutorId = context.select<AppProvider, String>(
      (app) => app.selectedTutorId,
    );
    final tutor = tutorProfileById(tutorId);
    // 캐릭터가 바뀌거나 아직 멘트가 없으면 해당 캐릭터의 행동패턴에서 선택
    if (_message == null || _messageTutorId != tutorId) {
      _message = _pickMessage(tutorId);
      _messageTutorId = tutorId;
    }

    // 선생님별 시그니처 컬러로 말풍선·배지·테두리를 차별화 —
    // 누가 말하고 있는지 한눈에 구분된다.
    final tColor = tutor.color;
    return GestureDetector(
      onTap: widget.linkToChat
          ? () =>
                pushWithNav(context, const TutorChatScreen(), currentSection: 1)
          : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tColor.withValues(alpha: 0.14),
              cs.secondaryContainer.withValues(alpha: 0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 전신 튜터 — 볼트쌤은 상황별 포즈 애니메이션, 잘림 없음
            TutorAvatar(mood: mood, size: widget.height),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${tutor.emoji} ${tutor.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: tColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tutor.styleTag,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: tColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (widget.linkToChat)
                        Text(
                          '탭하여 질문 →',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border.all(
                        color: tColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
