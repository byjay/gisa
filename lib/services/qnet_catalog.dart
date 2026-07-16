/// 📚 종목 카탈로그 (확장성 전용 파일)
///
/// 이 파일 하나만 수정하면 새로운 자격증·고등학교/중학교 교과를 추가할 수 있다.
/// - Q-Net 국가기술자격 종목: [QnetJmCatalog] 에 jmCd(종목코드)를 등록
/// - 학교 교과(중/고): [SubjectCatalog] 에 학기 일정 프리셋을 등록
///
/// 실시간 시험일정 크롤링([QnetScheduleService])은 이 카탈로그의 jmCd 를
/// 그대로 사용하므로, 새 자격증을 붙일 때 코드 수정이 최소화된다.
library;

/// 카탈로그 항목의 대분류.
enum CatalogKind {
  /// Q-Net 국가기술/전문 자격 (실시간 시험일정 크롤링 지원)
  qnet,

  /// 고등학교 교과 (내신/수능 등 학사 일정 기반)
  highSchool,

  /// 중학교 교과 (내신/자유학기 등)
  middleSchool,
}

extension CatalogKindLabel on CatalogKind {
  String get label {
    switch (this) {
      case CatalogKind.qnet:
        return '국가자격(Q-Net)';
      case CatalogKind.highSchool:
        return '고등학교 교과';
      case CatalogKind.middleSchool:
        return '중학교 교과';
    }
  }

  String get emoji {
    switch (this) {
      case CatalogKind.qnet:
        return '🏅';
      case CatalogKind.highSchool:
        return '🎓';
      case CatalogKind.middleSchool:
        return '📗';
    }
  }
}

/// 카탈로그의 한 종목(자격증/교과).
///
/// [jmCd] 가 있으면 Q-Net 실시간 시험일정 크롤링을 사용한다.
/// [seriesCd] 는 Q-Net 회차 분리 종목에서만 필요(기본 '03' = 기사/산업기사).
class CatalogItem {
  final String id; // 앱 내부 고유 id
  final String name; // 표시 이름
  final CatalogKind kind;
  final String? jmCd; // Q-Net 종목코드 (qnet 종목만)
  final String seriesCd; // Q-Net 회차 코드 (기본 03)
  final String category; // 분야 태그
  final String emoji;
  final List<String> subjects; // 과목/단원 구성(선택)
  final bool crawlable; // 실시간 크롤링 지원 여부

  const CatalogItem({
    required this.id,
    required this.name,
    required this.kind,
    this.jmCd,
    this.seriesCd = '03',
    this.category = '',
    this.emoji = '📘',
    this.subjects = const [],
    this.crawlable = false,
  });

  bool get isQnet => kind == CatalogKind.qnet && jmCd != null;
}

/// ─────────────────────────────────────────────────────────────
/// 🏅 Q-Net 국가자격 종목 카탈로그
/// jmCd 는 Q-Net crf00503 페이지의 종목코드.
/// (전기기사 1150 은 사용자가 요청한 기준 종목)
/// ─────────────────────────────────────────────────────────────
const List<CatalogItem> kQnetCatalog = [
  CatalogItem(
    id: 'q_electrician',
    name: '전기기사',
    kind: CatalogKind.qnet,
    jmCd: '1150',
    category: '전기·전자',
    emoji: '⚡',
    subjects: ['전자기학', '전력공학', '전기기기', '회로이론 및 제어공학', '전기설비기술기준'],
    crawlable: true,
  ),
  CatalogItem(
    id: 'q_elec_industrial',
    name: '전기산업기사',
    kind: CatalogKind.qnet,
    jmCd: '2140',
    seriesCd: '05',
    category: '전기·전자',
    emoji: '🔌',
    crawlable: true,
  ),
  CatalogItem(
    id: 'q_elec_construction',
    name: '전기공사기사',
    kind: CatalogKind.qnet,
    jmCd: '1160',
    category: '전기·전자',
    emoji: '🏗️',
    crawlable: true,
  ),
  CatalogItem(
    id: 'q_fire_electric',
    name: '소방설비기사(전기분야)',
    kind: CatalogKind.qnet,
    jmCd: '1910',
    seriesCd: '03',
    category: '안전관리',
    emoji: '🚒',
    crawlable: true,
  ),
  CatalogItem(
    id: 'q_info_processing',
    name: '정보처리기사',
    kind: CatalogKind.qnet,
    jmCd: '1320',
    category: '정보통신',
    emoji: '💻',
    crawlable: true,
  ),
  CatalogItem(
    id: 'q_energy_manager',
    name: '에너지관리기사',
    kind: CatalogKind.qnet,
    jmCd: '1340',
    category: '환경·에너지',
    emoji: '🔥',
    crawlable: true,
  ),
];

/// ─────────────────────────────────────────────────────────────
/// 🎓 학교 교과 카탈로그 (확장 예시)
/// 학교 교과는 Q-Net 크롤링 대상이 아니므로 crawlable=false.
/// 내신/수능 일정은 사용자가 직접 등록하거나 프리셋을 확장한다.
/// ─────────────────────────────────────────────────────────────
const List<CatalogItem> kSchoolCatalog = [
  CatalogItem(
    id: 's_high_math',
    name: '고등 수학',
    kind: CatalogKind.highSchool,
    category: '고등 교과',
    emoji: '📐',
    subjects: ['수학Ⅰ', '수학Ⅱ', '미적분', '확률과 통계', '기하'],
  ),
  CatalogItem(
    id: 's_high_english',
    name: '고등 영어',
    kind: CatalogKind.highSchool,
    category: '고등 교과',
    emoji: '🔤',
    subjects: ['영어Ⅰ', '영어Ⅱ', '영어 독해와 작문', '영어 회화'],
  ),
  CatalogItem(
    id: 's_high_korean',
    name: '고등 국어',
    kind: CatalogKind.highSchool,
    category: '고등 교과',
    emoji: '📖',
    subjects: ['화법과 작문', '독서', '언어와 매체', '문학'],
  ),
  CatalogItem(
    id: 's_mid_math',
    name: '중등 수학',
    kind: CatalogKind.middleSchool,
    category: '중등 교과',
    emoji: '➗',
    subjects: ['수와 연산', '문자와 식', '함수', '기하', '확률과 통계'],
  ),
  CatalogItem(
    id: 's_mid_science',
    name: '중등 과학',
    kind: CatalogKind.middleSchool,
    category: '중등 교과',
    emoji: '🔬',
    subjects: ['물리', '화학', '생명과학', '지구과학'],
  ),
  CatalogItem(
    id: 's_mid_social',
    name: '중등 사회',
    kind: CatalogKind.middleSchool,
    category: '중등 교과',
    emoji: '🌍',
    subjects: ['지리', '일반사회', '역사', '도덕'],
  ),
];

/// 전체 카탈로그 (자격증 + 학교 교과).
List<CatalogItem> get kFullCatalog => [...kQnetCatalog, ...kSchoolCatalog];

/// id 로 카탈로그 항목 조회. 없으면 전기기사(기본) 반환.
CatalogItem catalogItemById(String id) => kFullCatalog.firstWhere(
      (e) => e.id == id,
      orElse: () => kQnetCatalog.first,
    );

/// jmCd 로 Q-Net 카탈로그 항목 조회. 없으면 null.
CatalogItem? catalogItemByJmCd(String jmCd) {
  for (final item in kQnetCatalog) {
    if (item.jmCd == jmCd) return item;
  }
  return null;
}

/// 종류별 그룹 조회 (탭/섹션 UI 구성용).
List<CatalogItem> catalogByKind(CatalogKind kind) =>
    kFullCatalog.where((e) => e.kind == kind).toList();
