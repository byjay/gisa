import 'package:flutter/material.dart';

/// 시험 종목 정의 — 앱 전체가 이 종목 단위로 데이터를 로드한다.
///
/// 각 종목은 고유 [id]와 assets 폴더 [dir]를 가지며,
/// [subjects]/[theoryFiles] 로 과목 구성과 이론 파일 경로를 정의한다.
/// StudyData 는 실행 중 선택된 종목의 [dir] 하위 JSON 을 로드한다.
class ExamTrack {
  final String id;
  final String name; // 표시 이름 (예: 전기기사)
  final String shortName; // 진입 버튼 짧은 이름
  final String tagline; // 진입 버튼 부제
  final String emoji;
  final IconData icon;
  final Color color;
  final Color accent;
  final String dir; // assets/data/<dir>/
  final List<String> subjects; // 과목 순서 고정
  final Map<String, String> theoryFiles; // 과목 → 이론 md 경로
  final int questionCount; // 기출 문항 수 (exams.json 기준)
  final int topicCount; // 1:1 강의 토픽 수 (lessons.json 기준)
  final int repeatCount; // 반복기출 암기 문항 수
  final String bankLabel; // 문제은행 수식어 (예: 10년치 기출)
  final int paperSize; // 회차당 문항 수 (모의고사 안내용)

  const ExamTrack({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tagline,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.accent,
    required this.dir,
    required this.subjects,
    required this.theoryFiles,
    required this.questionCount,
    required this.topicCount,
    required this.repeatCount,
    required this.bankLabel,
    required this.paperSize,
  });

  /// 3자리 콤마 표기 (예: 2897 → 2,897)
  String get questionCountLabel {
    final s = questionCount.toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }
}

/// 지원 종목 3종 (전기기사 / 전기공사기사 / 소방설비기사(전기))
const List<ExamTrack> kExamTracks = [
  ExamTrack(
    id: 'electrician',
    name: '전기기사',
    shortName: '전기기사',
    tagline: '전자기학·전력·기기·회로·설비 5과목',
    emoji: '⚡',
    icon: Icons.bolt_rounded,
    color: Color(0xFF4F46E5),
    accent: Color(0xFF7C3AED),
    dir: 'electrician',
    subjects: [
      '전자기학',
      '전력공학',
      '전기기기',
      '회로이론 및 제어공학',
      '전기설비기술기준',
    ],
    theoryFiles: {
      '전자기학': 'assets/theory/electrician/01.md',
      '전력공학': 'assets/theory/electrician/02.md',
      '전기기기': 'assets/theory/electrician/03.md',
      '회로이론 및 제어공학': 'assets/theory/electrician/04.md',
      '전기설비기술기준': 'assets/theory/electrician/05.md',
    },
    questionCount: 2897,
    topicCount: 46,
    repeatCount: 347,
    bankLabel: '10년치 기출',
    paperSize: 100,
  ),
  ExamTrack(
    id: 'elec_construction',
    name: '전기공사기사',
    shortName: '전기공사기사',
    tagline: '전기응용·공사재료 중심 5과목',
    emoji: '🏗️',
    icon: Icons.electrical_services_rounded,
    color: Color(0xFF0891B2),
    accent: Color(0xFF06B6D4),
    dir: 'elec_construction',
    subjects: [
      '전기응용 및 공사재료',
      '전력공학',
      '전기기기',
      '회로이론 및 제어공학',
      '전기설비기술기준',
    ],
    theoryFiles: {
      '전기응용 및 공사재료': 'assets/theory/elec_construction/01.md',
      '전력공학': 'assets/theory/elec_construction/02.md',
      '전기기기': 'assets/theory/elec_construction/03.md',
      '회로이론 및 제어공학': 'assets/theory/elec_construction/04.md',
      '전기설비기술기준': 'assets/theory/elec_construction/05.md',
    },
    questionCount: 480,
    topicCount: 42,
    repeatCount: 46,
    bankLabel: '기출 복원',
    paperSize: 40,
  ),
  ExamTrack(
    id: 'fire_electric',
    name: '소방설비기사(전기)',
    shortName: '소방설비(전기)',
    tagline: '소방원론·전기일반·법규·구조 4과목',
    emoji: '🚒',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFDC2626),
    accent: Color(0xFFF97316),
    dir: 'fire_electric',
    subjects: [
      '소방원론',
      '소방전기일반',
      '소방관계법규',
      '소방전기시설의 구조 및 원리',
    ],
    theoryFiles: {
      '소방원론': 'assets/theory/fire_electric/01.md',
      '소방전기일반': 'assets/theory/fire_electric/02.md',
      '소방관계법규': 'assets/theory/fire_electric/03.md',
      '소방전기시설의 구조 및 원리': 'assets/theory/fire_electric/04.md',
    },
    questionCount: 384,
    topicCount: 20,
    repeatCount: 24,
    bankLabel: '기출 복원',
    paperSize: 32,
  ),
];

ExamTrack trackById(String id) =>
    kExamTracks.firstWhere((t) => t.id == id, orElse: () => kExamTracks.first);
