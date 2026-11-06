import 'package:flutter/material.dart';

/// Runtime track metadata is supplied by the authenticated catalog API.
/// Only visual treatment stays in the GUI bundle.
class ExamTrack {
  static const pending = ExamTrack(
    id: '_pending',
    name: '',
    shortName: '',
    tagline: '',
    emoji: '',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF4F46E5),
    accent: Color(0xFF7C3AED),
    dir: '',
    subjects: [],
    theoryFiles: {},
    questionCount: 0,
    topicCount: 0,
    repeatCount: 0,
    bankLabel: '',
    paperSize: 0,
  );

  final String id;
  final String name;
  final String shortName;
  final String tagline;
  final String emoji;
  final IconData icon;
  final Color color;
  final Color accent;
  final String dir;
  final List<String> subjects;
  final Map<String, String> theoryFiles;
  final int questionCount;
  final int topicCount;
  final int repeatCount;
  final String bankLabel;
  final int paperSize;

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

  factory ExamTrack.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final visual = _visuals[id] ?? _defaultVisual;
    return ExamTrack(
      id: id,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      tagline: json['tagline'] as String,
      emoji: json['emoji'] as String,
      icon: visual.icon,
      color: visual.color,
      accent: visual.accent,
      dir: id,
      subjects: ((json['subjects'] as List?) ?? const [])
          .map((value) => value as String)
          .toList(growable: false),
      theoryFiles: Map<String, String>.from(
        (json['theoryFiles'] as Map?) ?? const {},
      ),
      questionCount: _int(json['questionCount']),
      topicCount: _int(json['topicCount']),
      repeatCount: _int(json['repeatCount']),
      bankLabel: json['bankLabel'] as String,
      paperSize: _int(json['paperSize']),
    );
  }

  String get questionCountLabel {
    final value = questionCount.toString();
    return value.length > 3
        ? '${value.substring(0, value.length - 3)},${value.substring(value.length - 3)}'
        : value;
  }

  static int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
}

class _TrackVisual {
  const _TrackVisual(this.icon, this.color, this.accent);
  final IconData icon;
  final Color color;
  final Color accent;
}

const _defaultVisual = _TrackVisual(
  Icons.menu_book_rounded,
  Color(0xFF4F46E5),
  Color(0xFF7C3AED),
);

const Map<String, _TrackVisual> _visuals = {
  'electrician': _TrackVisual(
    Icons.bolt_rounded,
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
  ),
  'elec_construction': _TrackVisual(
    Icons.electrical_services_rounded,
    Color(0xFF0891B2),
    Color(0xFF06B6D4),
  ),
  'fire_electric': _TrackVisual(
    Icons.local_fire_department_rounded,
    Color(0xFFDC2626),
    Color(0xFFF97316),
  ),
  'fire_mechanical': _TrackVisual(
    Icons.plumbing_rounded,
    Color(0xFFB91C1C),
    Color(0xFFEF4444),
  ),
  'info_processing': _TrackVisual(
    Icons.terminal_rounded,
    Color(0xFF2563EB),
    Color(0xFF38BDF8),
  ),
  'industrial_safety': _TrackVisual(
    Icons.health_and_safety_rounded,
    Color(0xFF16A34A),
    Color(0xFF4ADE80),
  ),
  'architecture': _TrackVisual(
    Icons.apartment_rounded,
    Color(0xFF9333EA),
    Color(0xFFC084FC),
  ),
  'construction_safety': _TrackVisual(
    Icons.engineering_rounded,
    Color(0xFFCA8A04),
    Color(0xFFFACC15),
  ),
  'elec_industrial': _TrackVisual(
    Icons.power_rounded,
    Color(0xFF0D9488),
    Color(0xFF2DD4BF),
  ),
  'hazmat_industrial': _TrackVisual(
    Icons.science_rounded,
    Color(0xFFE11D48),
    Color(0xFFFB7185),
  ),
};

/// Populated from the authenticated API before any study screen is shown.
List<ExamTrack> kExamTracks = const [];

void setExamTrackCatalog(List<ExamTrack> tracks) {
  final ids = <String>{};
  for (final track in tracks) {
    if (!RegExp(r'^[a-z0-9_]{1,48}$').hasMatch(track.id) ||
        !ids.add(track.id)) {
      throw const FormatException('서버 자격증 카탈로그에 잘못된 ID가 있습니다.');
    }
  }
  if (tracks.isEmpty) {
    throw const FormatException('서버 자격증 카탈로그가 비어 있습니다.');
  }
  kExamTracks = List<ExamTrack>.unmodifiable(tracks);
}

ExamTrack trackById(String id) => kExamTracks.firstWhere(
  (track) => track.id == id,
  orElse: () => throw StateError('서버 카탈로그에 없는 자격증 종목입니다: $id'),
);
