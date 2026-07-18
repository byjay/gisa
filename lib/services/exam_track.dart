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

/// 지원 종목 10종 — 전기기사 / 전기공사기사 / 소방설비(전기) / 소방설비(기계)
/// / 정보처리기사 / 산업안전기사 / 건축기사 / 건설안전기사
/// / 전기산업기사 / 위험물산업기사
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
    questionCount: 840,
    topicCount: 42,
    repeatCount: 46,
    bankLabel: '7년치 기출',
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
    questionCount: 1444,
    topicCount: 21,
    repeatCount: 24,
    bankLabel: '7년치 실기출 19회차',
    paperSize: 80,
  ),
  ExamTrack(
    id: 'fire_mechanical',
    name: '소방설비기사(기계)',
    shortName: '소방설비(기계)',
    tagline: '소방원론·유체역학·법규·기계구조 4과목',
    emoji: '🛠️',
    icon: Icons.plumbing_rounded,
    color: Color(0xFFB91C1C),
    accent: Color(0xFFEF4444),
    dir: 'fire_mechanical',
    subjects: [
      '소방원론',
      '소방유체역학',
      '소방관계법규',
      '소방기계시설의 구조 및 원리',
    ],
    theoryFiles: {
      '소방원론': 'assets/theory/fire_mechanical/01.md',
      '소방유체역학': 'assets/theory/fire_mechanical/02.md',
      '소방관계법규': 'assets/theory/fire_mechanical/03.md',
      '소방기계시설의 구조 및 원리': 'assets/theory/fire_mechanical/04.md',
    },
    questionCount: 1496,
    topicCount: 21,
    repeatCount: 40,
    bankLabel: '7년치 실기출 19회차',
    paperSize: 80,
  ),
  ExamTrack(
    id: 'info_processing',
    name: '정보처리기사',
    shortName: '정보처리기사',
    tagline: 'NCS 개편 이후(2020~) 실기출 5과목',
    emoji: '💻',
    icon: Icons.terminal_rounded,
    color: Color(0xFF2563EB),
    accent: Color(0xFF38BDF8),
    dir: 'info_processing',
    subjects: [
      '소프트웨어 설계',
      '소프트웨어 개발',
      '데이터베이스 구축',
      '프로그래밍 언어 활용',
      '정보시스템 구축관리',
    ],
    theoryFiles: {
      '소프트웨어 설계': 'assets/theory/info_processing/01.md',
      '소프트웨어 개발': 'assets/theory/info_processing/02.md',
      '데이터베이스 구축': 'assets/theory/info_processing/03.md',
      '프로그래밍 언어 활용': 'assets/theory/info_processing/04.md',
      '정보시스템 구축관리': 'assets/theory/info_processing/05.md',
    },
    questionCount: 789,
    topicCount: 20,
    repeatCount: 9,
    bankLabel: 'NCS 개편 후 8회차',
    paperSize: 100,
  ),
  ExamTrack(
    id: 'industrial_safety',
    name: '산업안전기사',
    shortName: '산업안전기사',
    tagline: '안전관리·인간공학·기계·전기·화학·건설 6과목',
    emoji: '🦺',
    icon: Icons.health_and_safety_rounded,
    color: Color(0xFF16A34A),
    accent: Color(0xFF4ADE80),
    dir: 'industrial_safety',
    subjects: [
      '안전관리론',
      '인간공학 및 시스템안전공학',
      '기계위험방지기술',
      '전기위험방지기술',
      '화학설비위험방지기술',
      '건설안전기술',
    ],
    theoryFiles: {
      '안전관리론': 'assets/theory/industrial_safety/01.md',
      '인간공학 및 시스템안전공학': 'assets/theory/industrial_safety/02.md',
      '기계위험방지기술': 'assets/theory/industrial_safety/03.md',
      '전기위험방지기술': 'assets/theory/industrial_safety/04.md',
      '화학설비위험방지기술': 'assets/theory/industrial_safety/05.md',
      '건설안전기술': 'assets/theory/industrial_safety/06.md',
    },
    questionCount: 2252,
    topicCount: 28,
    repeatCount: 40,
    bankLabel: '7년치 실기출 19회차',
    paperSize: 120,
  ),
  ExamTrack(
    id: 'architecture',
    name: '건축기사',
    shortName: '건축기사',
    tagline: '계획·시공·구조·설비·법규 5과목',
    emoji: '🏛️',
    icon: Icons.apartment_rounded,
    color: Color(0xFF9333EA),
    accent: Color(0xFFC084FC),
    dir: 'architecture',
    subjects: [
      '건축계획',
      '건축시공',
      '건축구조',
      '건축설비',
      '건축법규',
    ],
    theoryFiles: {
      '건축계획': 'assets/theory/architecture/01.md',
      '건축시공': 'assets/theory/architecture/02.md',
      '건축구조': 'assets/theory/architecture/03.md',
      '건축설비': 'assets/theory/architecture/04.md',
      '건축법규': 'assets/theory/architecture/05.md',
    },
    questionCount: 1872,
    topicCount: 21,
    repeatCount: 40,
    bankLabel: '7년치 실기출 19회차',
    paperSize: 100,
  ),
  ExamTrack(
    id: 'construction_safety',
    name: '건설안전기사',
    shortName: '건설안전기사',
    tagline: '안전관리·심리·인간공학·시공·재료·안전기술 6과목',
    emoji: '🚧',
    icon: Icons.engineering_rounded,
    color: Color(0xFFCA8A04),
    accent: Color(0xFFFACC15),
    dir: 'construction_safety',
    subjects: [
      '산업안전관리론',
      '산업심리 및 교육',
      '인간공학 및 시스템안전공학',
      '건설시공학',
      '건설재료학',
      '건설안전기술',
    ],
    theoryFiles: {
      '산업안전관리론': 'assets/theory/construction_safety/01.md',
      '산업심리 및 교육': 'assets/theory/construction_safety/02.md',
      '인간공학 및 시스템안전공학': 'assets/theory/construction_safety/03.md',
      '건설시공학': 'assets/theory/construction_safety/04.md',
      '건설재료학': 'assets/theory/construction_safety/05.md',
      '건설안전기술': 'assets/theory/construction_safety/06.md',
    },
    questionCount: 2145,
    topicCount: 24,
    repeatCount: 40,
    bankLabel: '7년치 실기출 18회차',
    paperSize: 120,
  ),
  ExamTrack(
    id: 'elec_industrial',
    name: '전기산업기사',
    shortName: '전기산업기사',
    tagline: '자기학·전력·기기·회로·설비 5과목',
    emoji: '🔌',
    icon: Icons.power_rounded,
    color: Color(0xFF0D9488),
    accent: Color(0xFF2DD4BF),
    dir: 'elec_industrial',
    subjects: [
      '전기자기학',
      '전력공학',
      '전기기기',
      '회로이론',
      '전기설비기술기준',
    ],
    theoryFiles: {
      '전기자기학': 'assets/theory/elec_industrial/01.md',
      '전력공학': 'assets/theory/elec_industrial/02.md',
      '전기기기': 'assets/theory/elec_industrial/03.md',
      '회로이론': 'assets/theory/elec_industrial/04.md',
      '전기설비기술기준': 'assets/theory/elec_industrial/05.md',
    },
    questionCount: 1673,
    topicCount: 19,
    repeatCount: 31,
    bankLabel: '7년치 실기출 19회차',
    paperSize: 100,
  ),
  ExamTrack(
    id: 'hazmat_industrial',
    name: '위험물산업기사',
    shortName: '위험물산업기사',
    tagline: '일반화학·소화방법·위험물성질 3과목',
    emoji: '🧪',
    icon: Icons.science_rounded,
    color: Color(0xFFE11D48),
    accent: Color(0xFFFB7185),
    dir: 'hazmat_industrial',
    subjects: [
      '일반화학',
      '화재예방과 소화방법',
      '위험물의 성질과 취급',
    ],
    theoryFiles: {
      '일반화학': 'assets/theory/hazmat_industrial/01.md',
      '화재예방과 소화방법': 'assets/theory/hazmat_industrial/02.md',
      '위험물의 성질과 취급': 'assets/theory/hazmat_industrial/03.md',
    },
    questionCount: 1125,
    topicCount: 11,
    repeatCount: 40,
    bankLabel: '7년치 실기출 19회차',
    paperSize: 60,
  ),
];

ExamTrack trackById(String id) =>
    kExamTracks.firstWhere((t) => t.id == id, orElse: () => kExamTracks.first);
