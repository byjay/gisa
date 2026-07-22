import 'dart:convert';
import 'dart:io';

import 'package:cert_study_tracker/services/exam_track.dart';
import 'package:cert_study_tracker/services/study_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// 📋 전체 문제 데이터 무결성 회귀 가드
/// 10개 종목의 exams.json / repeat_questions.json 을 직접 읽어
/// 정답 범위·보기 개수·중복 보기·빈 지문을 검사한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tracks = Directory(
    'assets/data',
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

  test('10개 종목 48개 전 과목의 요약·반복기출·실기 카드가 모두 열린다', () async {
    var checkedSubjects = 0;
    for (final track in kExamTracks) {
      StudyData.instance.setTrack(track);
      final summaries = await StudyData.instance.loadSubjectSummaries();
      final repeats = await StudyData.instance.loadRepeats();
      final silgi = await StudyData.instance.loadSilgi();

      for (final subject in track.subjects) {
        checkedSubjects++;
        expect(
          summaries.any((deck) => deck.subject.startsWith(subject)),
          isTrue,
          reason: '${track.name} / $subject 핵심요약 누락',
        );
        expect(
          repeats.any((item) => item.subject == subject),
          isTrue,
          reason: '${track.name} / $subject 반복기출 누락',
        );
        expect(
          silgi?.items.any((item) => item.linkSubject.startsWith(subject)),
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
