import 'dart:convert';
import 'dart:io';

import 'package:cert_study_tracker/services/exam_track.dart';
import 'package:flutter_test/flutter_test.dart';

/// 📋 전체 문제 데이터 무결성 회귀 가드
/// 10개 종목의 exams.json / repeat_questions.json 을 직접 읽어
/// 정답 범위·보기 개수·중복 보기·빈 지문을 검사한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tracks = Directory(
    'backend/data/study',
  ).listSync().whereType<Directory>().map((d) => d.path).toList();

  test('종목 데이터 디렉터리가 10개 이상 존재한다', () {
    expect(tracks.length, greaterThanOrEqualTo(10));
  });

  test('exams.json — 정답 범위·보기 4개·중복/빈 보기 없음 (전 종목)', () {
    var total = 0;
    final errors = <String>[];
    for (final t in tracks) {
      final f = File('$t/exams.json');
      if (!f.existsSync()) continue;
      final exams = jsonDecode(f.readAsStringSync()) as List;
      for (final ex in exams.cast<Map<String, dynamic>>()) {
        for (final q
            in (ex['questions'] as List).cast<Map<String, dynamic>>()) {
          total++;
          final loc = '$t/${ex['id']}#${q['no']}';
          final opts = (q['options'] as List).map((e) => e.toString()).toList();
          final ans = q['answer'];
          if (opts.length != 4) errors.add('OPT $loc');
          if (ans is! int || ans < 1 || ans > opts.length) {
            errors.add('ANS $loc');
          }
          if (opts.toSet().length != opts.length) errors.add('DUP $loc');
          if (opts.any((o) => o.trim().isEmpty)) errors.add('EMPTY $loc');
          if ((q['question'] as String? ?? '').trim().isEmpty) {
            errors.add('NOQ $loc');
          }
        }
      }
    }
    expect(total, greaterThan(15000), reason: '기출 문제 수가 비정상적으로 적다');
    expect(errors, isEmpty, reason: errors.take(20).join('\n'));
  });

  test('repeat_questions.json — 정답 범위·중복/빈 보기 없음 (전 종목)', () {
    var total = 0;
    final errors = <String>[];
    for (final t in tracks) {
      final f = File('$t/repeat_questions.json');
      if (!f.existsSync()) continue;
      final list = jsonDecode(f.readAsStringSync()) as List;
      for (var i = 0; i < list.length; i++) {
        total++;
        final q = list[i] as Map<String, dynamic>;
        final loc = '$t#rq$i';
        final opts = (q['options'] as List).map((e) => e.toString()).toList();
        final ans = q['answer'];
        if (opts.length != 4) errors.add('OPT $loc');
        if (ans is! int || ans < 1 || ans > opts.length) errors.add('ANS $loc');
        if (opts.toSet().length != opts.length) errors.add('DUP $loc');
        if (opts.any((o) => o.trim().isEmpty)) errors.add('EMPTY $loc');
      }
    }
    expect(total, greaterThan(500));
    expect(errors, isEmpty, reason: errors.take(20).join('\n'));
  });

  test('원격 카탈로그 10개 종목의 48개 과목에 카드 원본 또는 보충 자료가 있다', () {
    final catalog =
        jsonDecode(File('backend/catalog/tracks.json').readAsStringSync())
            as Map<String, dynamic>;
    final catalogTracks = (catalog['tracks'] as List)
        .map(
          (item) => ExamTrack.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    expect(catalog['schemaVersion'], 1);
    expect(catalogTracks.length, 10);

    var checkedSubjects = 0;
    for (final track in catalogTracks) {
      final root = 'backend/data/study/${track.dir}';
      final summaries = _readJsonList('$root/subject_summary.json');
      final theorySlides = _readJsonList('$root/theory_slides.json');
      final repeats = _readJsonList('$root/repeat_questions.json');
      final lessons = _readJsonList('$root/lessons.json');
      final exams = _readJsonList('$root/exams.json');
      final silgi = _readJsonMap('$root/silgi.json');
      final silgiItems = (silgi['items'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);

      for (final subject in track.subjects) {
        checkedSubjects++;
        expect(
          summaries.any((item) => _sameSubject(item['subject'], subject)) ||
              theorySlides.any(
                (item) => _sameSubject(item['subject'], subject),
              ),
          isTrue,
          reason: '${track.name} / $subject 핵심요약 누락',
        );
        expect(
          repeats.any((item) => _sameSubject(item['subject'], subject)) ||
              exams.any((exam) {
                final questions = (exam['questions'] as List? ?? const []);
                return questions.any((rawQuestion) {
                  final question = Map<String, dynamic>.from(
                    rawQuestion as Map,
                  );
                  final options = question['options'] as List? ?? const [];
                  final answer = question['answer'];
                  return _sameSubject(question['subject'], subject) &&
                      options.length == 4 &&
                      answer is int &&
                      answer >= 1;
                });
              }),
          isTrue,
          reason: '${track.name} / $subject 반복기출 누락',
        );
        expect(
          silgiItems.any(
                (item) => _sameSubject(
                  item['link_subject'] ?? item['subject'],
                  subject,
                ),
              ) ||
              lessons.any((item) => _sameSubject(item['subject'], subject)),
          isTrue,
          reason: '${track.name} / $subject 실기카드 누락',
        );
      }
    }
    expect(checkedSubjects, 48);
  });

  test('image 필드가 있으면 실제 이미지 파일이 존재한다 (전 종목)', () {
    final missing = <String>[];
    for (final t in tracks) {
      final f = File('$t/exams.json');
      if (!f.existsSync()) continue;
      final exams = jsonDecode(f.readAsStringSync()) as List;
      for (final ex in exams.cast<Map<String, dynamic>>()) {
        for (final q
            in (ex['questions'] as List).cast<Map<String, dynamic>>()) {
          final img = q['image'] as String?;
          if (img != null && !File('$t/$img').existsSync()) {
            missing.add('$t/${ex['id']}#${q['no']} $img');
          }
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(10).join('\n'));
  });
}

List<Map<String, dynamic>> _readJsonList(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  return (jsonDecode(file.readAsStringSync()) as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);
}

Map<String, dynamic> _readJsonMap(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

bool _sameSubject(Object? value, String canonical) {
  final normalizedValue = (value?.toString() ?? '').replaceAll(
    RegExp(r'\s+'),
    '',
  );
  final normalizedCanonical = canonical.replaceAll(RegExp(r'\s+'), '');
  if (normalizedValue.isEmpty || normalizedCanonical.isEmpty) return false;
  return normalizedValue == normalizedCanonical ||
      normalizedValue.startsWith(normalizedCanonical) ||
      normalizedCanonical.startsWith(normalizedValue);
}
