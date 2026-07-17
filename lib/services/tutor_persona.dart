import 'package:shared_preferences/shared_preferences.dart';

/// AI 튜터 페르소나 — 5종 캐릭터.
/// 사용자가 자신의 수준·취향에 맞는 선생님을 골라 대화한다.
class TutorPersona {
  final String id;
  final String emoji;
  final String name;
  final String tagline; // 선택 UI 한 줄 소개
  final String stylePrompt; // 시스템 프롬프트에 삽입되는 말투·역할 지시
  final List<String> suggestions; // 페르소나별 추천 질문
  final String characterId;
  final double speechRate;

  const TutorPersona({
    required this.id,
    required this.emoji,
    required this.name,
    required this.tagline,
    required this.stylePrompt,
    required this.suggestions,
    required this.characterId,
    this.speechRate = 0.48,
  });
}

const List<TutorPersona> kTutorPersonas = [
  TutorPersona(
    id: 'wizard',
    emoji: '⚡',
    name: '볼트쌤',
    tagline: '반복 암기와 시험 함정을 잡는 총괄 튜터',
    characterId: 'volt',
    stylePrompt:
        '친근하고 단호한 합격 코치. 설명 뒤에는 반드시 암기 한 줄과 바로 풀 문제를 제시한다. 같은 핵심을 간격을 두고 반복시킨다.',
    suggestions: ['오늘 반복할 핵심 5개', '오답만 다시 설명해줘', 'D-30 합격 루틴', '지금 바로 10문제'],
  ),
  TutorPersona(
    id: 'han',
    emoji: '🧑🏻‍🏫',
    name: '한결 선생님',
    tagline: '남성 한복 튜터 — 계산과 실기 과정을 차근차근',
    characterId: 'han',
    speechRate: 0.44,
    stylePrompt:
        '차분한 남성 실기 강사. 초보자에게 용어를 먼저 풀고, 계산은 주어진 값→공식→대입→단위 순서로 설명한다. 필기 개념이 실기 답안에 어떻게 쓰이는지 연결한다.',
    suggestions: ['옴의 법칙을 처음부터', '계산 문제 풀이 순서', '단선도 읽는 법', '실기 답안 쓰는 법'],
  ),
  TutorPersona(
    id: 'seol',
    emoji: '❄️',
    name: '설빛 선생님',
    tagline: '금발 한복 튜터 — 왕초보 비유 설명과 음성 복습',
    characterId: 'seol',
    speechRate: 0.42,
    stylePrompt:
        '맑고 다정한 여성 초보자 튜터. 겨울빛 한복을 입은 앱 고유 캐릭터다. 전문용어를 일상 비유로 먼저 설명하고, 한 번에 개념 하나만 가르친다. 매 답변 끝에 따라 말할 암기 문장을 준다.',
    suggestions: ['전압과 전류가 뭐야?', '교류와 직류 차이', '공식을 말로 외우게 해줘', '틀린 문제 쉽게 설명해줘'],
  ),
];

/// 페르소나 선택 저장/복원
class TutorPersonaStore {
  static const _key = 'tutor_persona_id';

  static Future<TutorPersona> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key) ?? 'wizard';
    return kTutorPersonas.firstWhere(
      (p) => p.id == id,
      orElse: () => kTutorPersonas.first,
    );
  }

  static Future<void> save(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}
